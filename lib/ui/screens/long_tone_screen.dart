import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/long_tone_game.dart';
import '../../core/music/pitch_utils.dart';
import '../widgets/keep_screen_awake.dart';
import '../widgets/tuning_colors.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Tiens la note (jeu G2) : une note, juste, le plus longtemps possible.
///
/// **Pas une corde a vide** : c'est elle qui donne l'accord, elle serait
/// juste par definition. Les notes proposees sont celles du morceau, doigts
/// poses.
class LongToneScreen extends StatefulWidget {
  const LongToneScreen({
    required this.notes,
    required this.pitchSourceFactory,
    this.a4 = PitchUtils.defaultA4,
    this.bestMs = 0,
    this.onBest,
    super.key,
  });

  final List<int> notes;
  final PitchSourceFactory pitchSourceFactory;
  final double a4;
  final int bestMs;
  final ValueChanged<int>? onBest;

  static const Key commencerKey = Key('tenue-commencer');
  static const Key tempsKey = Key('tenue-temps');
  static const Key ecartKey = Key('tenue-ecart');
  static const Key recordKey = Key('tenue-record');
  static Key noteKey(int midi) => Key('tenue-note-$midi');

  @override
  State<LongToneScreen> createState() => _LongToneScreenState();
}

class _LongToneScreenState extends State<LongToneScreen> {
  /// Les cordes a vide : sol, re, la, mi.
  static const Set<int> _cordes = <int>{55, 62, 69, 76};

  late final List<int> _choix = <int>[
    for (final int m in widget.notes)
      if (!_cordes.contains(m)) m,
  ].take(6).toList();

  late int _cible = _choix.isEmpty ? 71 : _choix.first;
  late LongToneGame _jeu = _nouveau();
  late int _record = widget.bestMs;

  PitchSource? _micro;
  StreamSubscription<SmoothedPitch>? _hauteurs;
  Timer? _tic;
  bool _ecoute = false;

  /// L'instant du micro de la derniere hauteur, et quand elle est arrivee :
  /// de quoi dater le silence sur la meme horloge.
  int _dernierMs = 0;
  DateTime _arrivee = DateTime.now();

  LongToneGame _nouveau() => LongToneGame(targetMidi: _cible, bestMs: _record);

  int get _maintenantMs =>
      _dernierMs + DateTime.now().difference(_arrivee).inMilliseconds;

  Future<void> _basculer() async {
    if (_ecoute) {
      await _arreter();
      return;
    }
    setState(() {
      _ecoute = true;
      _jeu = _nouveau();
    });
    try {
      final PitchSource micro = await widget.pitchSourceFactory();
      if (!mounted || !_ecoute) {
        await micro.dispose();
        return;
      }
      _micro = micro;
      _hauteurs = micro.smoothedPitches.listen(_onHauteur);
      await micro.start();
    } on MicPermissionDenied {
      setState(() => _ecoute = false);
      return;
    }
    // Une veille d'affichage : elle date le silence et redessine le temps
    // tenu. Elle ne declenche aucun son.
    _tic = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) {
        return;
      }
      if (DateTime.now().difference(_arrivee).inMilliseconds > 150) {
        _jeu.rest(_maintenantMs);
      }
      _noter();
      setState(() {});
    });
  }

  void _onHauteur(SmoothedPitch h) {
    _dernierMs = h.timestampMs;
    _arrivee = DateTime.now();
    _jeu.hear(
      PitchUtils.frequencyToMidi(h.frequencyHz, a4: widget.a4),
      h.timestampMs,
    );
    _noter();
  }

  void _noter() {
    if (_jeu.bestMs > _record) {
      _record = _jeu.bestMs;
      widget.onBest?.call(_record);
    }
  }

  Future<void> _arreter() async {
    _tic?.cancel();
    _tic = null;
    final PitchSource? m = _micro;
    _micro = null;
    unawaited(_hauteurs?.cancel());
    _hauteurs = null;
    _jeu.rest(_maintenantMs + 1000);
    _noter();
    if (mounted) {
      setState(() => _ecoute = false);
    }
    await m?.dispose();
  }

  @override
  void dispose() {
    _tic?.cancel();
    unawaited(_hauteurs?.cancel());
    unawaited(_micro?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? c = _ecoute ? _jeu.lastCents : null;
    final double tenu = _ecoute ? _jeu.currentMs(_maintenantMs) / 1000 : 0;
    final bool juste = c != null && c.abs() <= _jeu.toleranceCents;
    return KeepScreenAwake(
      actif: _ecoute,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tiens la note')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: <Widget>[
                    for (final int m in _choix)
                      ChoiceChip(
                        key: LongToneScreen.noteKey(m),
                        label: Text(PitchUtils.noteName(m)),
                        selected: _cible == m,
                        onSelected: _ecoute
                            ? null
                            : (_) => setState(() {
                                  _cible = m;
                                  _jeu = _nouveau();
                                }),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  PitchUtils.noteName(_cible),
                  style: theme.textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                Text(
                  c == null
                      ? (_ecoute ? 'Joue-la' : 'Juste a 10 cents pres')
                      : '${c >= 0 ? '+' : ''}${c.round()} cents',
                  key: LongToneScreen.ecartKey,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: c == null
                        ? null
                        : juste
                            ? TuningColors.inTune
                            : (c < 0 ? TuningColors.low : TuningColors.high),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  '${tenu.toStringAsFixed(1)} s',
                  key: LongToneScreen.tempsKey,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                Text(
                  _record == 0
                      ? 'Pas encore de record'
                      : 'Record : ${(_record / 1000).toStringAsFixed(1)} s',
                  key: LongToneScreen.recordKey,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton.icon(
                  key: LongToneScreen.commencerKey,
                  onPressed: () => unawaited(_basculer()),
                  icon: Icon(_ecoute ? Icons.stop : Icons.mic),
                  label: Text(_ecoute ? 'Arreter' : 'Commencer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
