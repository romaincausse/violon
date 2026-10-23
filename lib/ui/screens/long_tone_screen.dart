import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/even_bow.dart';
import '../../core/exercises/long_tone_game.dart';
import '../../core/follow/performance_features.dart';
import '../../core/music/pitch_utils.dart';
import '../widgets/keep_screen_awake.dart';
import '../widgets/tuning_colors.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Tiens la note (jeu G2) : une note, juste, le plus longtemps possible -- et
/// le son de chaque archet, egal du debut a la fin (K7).
///
/// **Pas une corde a vide** dans le jeu de justesse : c'est elle qui donne
/// l'accord, elle serait juste par definition. Les notes proposees sont
/// celles du morceau, doigts poses.
///
/// **Sur les cordes a vide** ([openStrings]), seul le son compte : c'est
/// l'echauffement de la seance du jour, une minute avant la gamme, comme en
/// cours.
class LongToneScreen extends StatefulWidget {
  const LongToneScreen({
    required this.notes,
    required this.pitchSourceFactory,
    this.a4 = PitchUtils.defaultA4,
    this.bestMs = 0,
    this.onBest,
    this.evenBowBestMs = 0,
    this.onEvenBowBest,
    this.openStrings = false,
    this.budget,
    super.key,
  });

  final List<int> notes;
  final PitchSourceFactory pitchSourceFactory;
  final double a4;
  final int bestMs;
  final ValueChanged<int>? onBest;

  /// Le record du plus long archet egal, et qui le recoit quand il monte.
  final int evenBowBestMs;
  final ValueChanged<int>? onEvenBowBest;

  /// Les quatre cordes a vide, et le son seul : la hauteur ne se juge pas.
  final bool openStrings;

  /// Le temps de jeu propose, ou `null` pour jouer tant qu'il veut. Il se
  /// compte micro ouvert : une pause ne l'entame pas.
  final Duration? budget;

  static const Key commencerKey = Key('tenue-commencer');
  static const Key tempsKey = Key('tenue-temps');
  static const Key ecartKey = Key('tenue-ecart');
  static const Key recordKey = Key('tenue-record');
  static const Key archetKey = Key('tenue-archet');
  static const Key archetRecordKey = Key('tenue-archet-record');
  static const Key resteKey = Key('tenue-reste');
  static Key noteKey(int midi) => Key('tenue-note-$midi');

  /// Les cordes a vide : sol, re, la, mi.
  static const List<int> cordes = <int>[55, 62, 69, 76];

  /// Ce que dit le dernier archet, en une phrase.
  static String bowSentence(BowStroke b) {
    final String duree = '${(b.durationMs / 1000).toStringAsFixed(1)} s';
    return switch (b.verdict) {
      BowVerdict.even => 'Archet de $duree, son egal',
      BowVerdict.fades =>
        'Archet de $duree : le son s eteint a la fin, garde le poids '
            'jusqu au bout',
      BowVerdict.swells =>
        'Archet de $duree : le son grossit en route, le meme poids du '
            'debut a la fin',
      BowVerdict.uneven =>
        'Archet de $duree : le son bouge, la meme vitesse d archet tout '
            'du long',
    };
  }

  @override
  State<LongToneScreen> createState() => _LongToneScreenState();
}

class _LongToneScreenState extends State<LongToneScreen> {
  late final List<int> _choix = widget.openStrings
      ? LongToneScreen.cordes
      : <int>[
          for (final int m in widget.notes)
            if (!LongToneScreen.cordes.contains(m)) m,
        ].take(6).toList();

  late int _cible = _choix.isEmpty ? 71 : _choix.first;
  late LongToneGame _jeu = _nouveau();
  late int _record = widget.bestMs;
  late EvenBow _archet = EvenBow(bestMs: widget.evenBowBestMs);
  late int _recordArchet = widget.evenBowBestMs;

  PitchSource? _micro;
  StreamSubscription<SmoothedPitch>? _hauteurs;
  StreamSubscription<FeatureFrame>? _trames;
  Timer? _tic;
  bool _ecoute = false;

  /// Micro ouvert, en millisecondes : ce qui entame [LongToneScreen.budget].
  int _joueMs = 0;

  /// L'instant du micro de la derniere hauteur, et quand elle est arrivee :
  /// de quoi dater le silence sur la meme horloge.
  int _dernierMs = 0;
  DateTime _arrivee = DateTime.now();

  LongToneGame _nouveau() => LongToneGame(targetMidi: _cible, bestMs: _record);

  int get _maintenantMs =>
      _dernierMs + DateTime.now().difference(_arrivee).inMilliseconds;

  bool get _fini {
    final Duration? b = widget.budget;
    return b != null && _joueMs >= b.inMilliseconds;
  }

  Future<void> _basculer() async {
    if (_ecoute) {
      await _arreter();
      return;
    }
    if (_fini) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _ecoute = true;
      _jeu = _nouveau();
      _archet = EvenBow(bestMs: _recordArchet);
    });
    try {
      final PitchSource micro = await widget.pitchSourceFactory();
      if (!mounted || !_ecoute) {
        await micro.dispose();
        return;
      }
      _micro = micro;
      _hauteurs = micro.smoothedPitches.listen(_onHauteur);
      _trames = micro.features.listen(_onTrame);
      await micro.start();
    } on MicPermissionDenied {
      setState(() => _ecoute = false);
      return;
    }
    // Une veille d'affichage : elle date le silence, compte le temps joue et
    // redessine. Elle ne declenche aucun son.
    _tic = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) {
        return;
      }
      if (DateTime.now().difference(_arrivee).inMilliseconds > 150) {
        _jeu.rest(_maintenantMs);
      }
      _joueMs += 100;
      _noter();
      if (_fini) {
        unawaited(_arreter());
        return;
      }
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

  /// L'energie de l'archet : le son file ne regarde qu'elle.
  void _onTrame(FeatureFrame f) {
    _archet.hear(f);
    _noter();
  }

  void _noter() {
    if (_jeu.bestMs > _record) {
      _record = _jeu.bestMs;
      widget.onBest?.call(_record);
    }
    if (_archet.bestMs > _recordArchet) {
      _recordArchet = _archet.bestMs;
      widget.onEvenBowBest?.call(_recordArchet);
    }
  }

  Future<void> _arreter() async {
    _tic?.cancel();
    _tic = null;
    final PitchSource? m = _micro;
    _micro = null;
    unawaited(_hauteurs?.cancel());
    _hauteurs = null;
    unawaited(_trames?.cancel());
    _trames = null;
    _jeu.rest(_maintenantMs + 1000);
    _archet.rest();
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
    unawaited(_trames?.cancel());
    unawaited(_micro?.dispose());
    super.dispose();
  }

  String get _bouton {
    if (_ecoute) {
      return 'Arreter';
    }
    if (_fini) {
      return 'Passer a la gamme';
    }
    return 'Commencer';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? c = _ecoute ? _jeu.lastCents : null;
    final bool juste = c != null && c.abs() <= _jeu.toleranceCents;
    final double tenu = widget.openStrings
        ? (_ecoute ? _archet.currentMs / 1000 : 0)
        : (_ecoute ? _jeu.currentMs(_maintenantMs) / 1000 : 0);
    final BowStroke? dernier = _archet.last;
    final Duration? budget = widget.budget;
    return KeepScreenAwake(
      actif: _ecoute,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.openStrings ? 'Cordes a vide' : 'Tiens la note'),
        ),
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
                if (budget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _fini
                          ? 'La minute est faite.'
                          : 'Encore ${((budget.inMilliseconds - _joueMs) / 1000).ceil()} s',
                      key: LongToneScreen.resteKey,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Spacer(),
                Text(
                  PitchUtils.noteName(_cible),
                  style: theme.textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                if (!widget.openStrings)
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
                  )
                else
                  Text(
                    'Un archet entier, lent, le son egal',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),
                Text(
                  '${tenu.toStringAsFixed(1)} s',
                  key: LongToneScreen.tempsKey,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                if (!widget.openStrings)
                  Text(
                    _record == 0
                        ? 'Pas encore de record'
                        : 'Record : ${(_record / 1000).toStringAsFixed(1)} s',
                    key: LongToneScreen.recordKey,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                Text(
                  dernier == null
                      ? 'Le son de chaque archet se juge a la fin de l archet.'
                      : LongToneScreen.bowSentence(dernier),
                  key: LongToneScreen.archetKey,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: dernier?.verdict == BowVerdict.even
                        ? TuningColors.inTune
                        : null,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  _recordArchet == 0
                      ? 'Pas encore d archet egal'
                      : 'Archet egal le plus long : '
                          '${(_recordArchet / 1000).toStringAsFixed(1)} s',
                  key: LongToneScreen.archetRecordKey,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton.icon(
                  key: LongToneScreen.commencerKey,
                  onPressed: () => unawaited(_basculer()),
                  icon: Icon(
                    _ecoute
                        ? Icons.stop
                        : _fini
                            ? Icons.arrow_forward
                            : Icons.mic,
                  ),
                  label: Text(_bouton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
