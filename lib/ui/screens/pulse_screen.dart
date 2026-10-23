import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/pulse_game.dart';
import '../../core/follow/performance_features.dart';
import '../../core/play/audio_engine.dart';
import '../../core/play/metronome_clock.dart';
import '../widgets/keep_screen_awake.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Le tempo cache (jeu G3) : quatre clics, puis le silence, et il continue
/// seul huit temps.
///
/// **Les clics sonnent avant, le micro ecoute apres** (ADR-008) : il s'ouvre
/// sur le dernier clic, et les attaques des premieres millisecondes sont
/// ignorees, le temps que ce clic s'eteigne.
class PulseScreen extends StatefulWidget {
  const PulseScreen({
    required this.bpm,
    required this.engine,
    required this.pitchSourceFactory,
    this.best = 0,
    this.onBest,
    super.key,
  });

  final int bpm;
  final AudioEngine engine;
  final PitchSourceFactory pitchSourceFactory;
  final int best;
  final ValueChanged<int>? onBest;

  static const Key jouerKey = Key('pulsation-jouer');
  static const Key messageKey = Key('pulsation-message');
  static const Key tempoKey = Key('pulsation-tempo');
  static const Key compteKey = Key('pulsation-compte');

  static const Duration marge = Duration(milliseconds: 300);

  /// Ce qui suit l'ouverture du micro et peut encore etre le dernier clic.
  static const int ignorerMs = 150;

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

enum _Etat { pret, clics, joue }

class _PulseScreenState extends State<PulseScreen> {
  late int _bpm = widget.bpm.clamp(40, 160);
  late PulseGame _jeu = PulseGame(bpm: _bpm, best: widget.best);
  _Etat _etat = _Etat.pret;
  String _message = 'Ecoute quatre clics, puis continue seul huit temps, '
      'sur une corde a vide si tu veux.';
  final List<int> _attaques = <int>[];
  Timer? _ouverture;
  Timer? _veille;
  DateTime? _derniere;

  PitchSource? _micro;
  StreamSubscription<FeatureFrame>? _trames;

  Duration get _temps => Duration(microseconds: 60000000 ~/ _bpm);

  Future<void> _jouer() async {
    await _fermer();
    _jeu = PulseGame(bpm: _bpm, best: _jeu.best);
    setState(() {
      _etat = _Etat.clics;
      _message = 'Ecoute...';
      _attaques.clear();
    });
    final Duration maintenant = await widget.engine.now();
    if (!mounted || _etat != _Etat.clics) {
      return;
    }
    for (int k = 0; k < 4; k++) {
      await widget.engine.scheduleClickAt(
        at: maintenant + PulseScreen.marge + _temps * k,
        accent: k == 0 ? PulseAccent.downbeat : PulseAccent.beat,
      );
    }
    // Le micro s'ouvre sur le dernier clic : un temps avant qu'il commence.
    _ouverture?.cancel();
    _ouverture = Timer(
      PulseScreen.marge + _temps * 3,
      () => unawaited(_ecouter()),
    );
  }

  Future<void> _ecouter() async {
    if (!mounted || _etat != _Etat.clics) {
      return;
    }
    setState(() {
      _etat = _Etat.joue;
      _message = 'A toi : huit temps.';
    });
    try {
      final PitchSource micro = await widget.pitchSourceFactory();
      if (!mounted || _etat != _Etat.joue) {
        await micro.dispose();
        return;
      }
      _micro = micro;
      _derniere = DateTime.now();
      _trames = micro.features.listen(_onTrame);
      await micro.start();
    } on MicPermissionDenied {
      setState(() {
        _etat = _Etat.pret;
        _message = 'Le micro est refuse : impossible de t entendre.';
      });
      return;
    }
    // Il s'arrete trop longtemps : on juge ce qu'on a.
    _veille = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final DateTime? d = _derniere;
      if (d != null &&
          DateTime.now().difference(d) > _temps * 3 &&
          _etat == _Etat.joue) {
        _juger();
      }
    });
  }

  void _onTrame(FeatureFrame f) {
    if (_etat != _Etat.joue || !f.onset || f.timeMs < PulseScreen.ignorerMs) {
      return;
    }
    _derniere = DateTime.now();
    setState(() => _attaques.add(f.timeMs));
    if (_attaques.length >= _jeu.beats) {
      _juger();
    }
  }

  void _juger() {
    _veille?.cancel();
    unawaited(_fermer());
    final int avant = _jeu.best;
    final PulseResult? r = _jeu.judge(_attaques);
    if (_jeu.best > avant) {
      widget.onBest?.call(_jeu.best);
    }
    setState(() {
      _etat = _Etat.pret;
      if (r == null) {
        _message = 'Je n ai pas entendu assez de notes. On recommence ?';
        return;
      }
      final String sens = r.driftPercent.abs() < 2
          ? 'pile au tempo'
          : r.driftPercent > 0
              ? 'un peu plus vite'
              : 'un peu plus lent';
      _message = 'Tu as tenu ${r.heldBpm.round()} pour $_bpm : $sens. '
          'Regularite a ${r.jitterMs} ms pres. ${r.score} sur 100.';
    });
  }

  Future<void> _fermer() async {
    _ouverture?.cancel();
    _veille?.cancel();
    final PitchSource? m = _micro;
    _micro = null;
    unawaited(_trames?.cancel());
    _trames = null;
    await m?.dispose();
  }

  @override
  void dispose() {
    _ouverture?.cancel();
    _veille?.cancel();
    unawaited(_fermer());
    unawaited(widget.engine.stopAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return KeepScreenAwake(
      actif: _etat != _Etat.pret,
      child: Scaffold(
        appBar: AppBar(title: const Text('Le tempo cache')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _jeu.best == 0
                      ? 'Pas encore de record'
                      : 'Record : ${_jeu.best} sur 100',
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      onPressed: _etat == _Etat.pret && _bpm > 40
                          ? () => setState(() => _bpm -= 4)
                          : null,
                      icon: const Icon(Icons.remove),
                      tooltip: 'Plus lent',
                    ),
                    Text(
                      '$_bpm',
                      key: PulseScreen.tempoKey,
                      style: theme.textTheme.displaySmall,
                    ),
                    IconButton(
                      onPressed: _etat == _Etat.pret && _bpm < 160
                          ? () => setState(() => _bpm += 4)
                          : null,
                      icon: const Icon(Icons.add),
                      tooltip: 'Plus vite',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _etat == _Etat.joue
                      ? '${_attaques.length} / ${_jeu.beats}'
                      : 'a la noire',
                  key: PulseScreen.compteKey,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _message,
                  key: PulseScreen.messageKey,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton.icon(
                  key: PulseScreen.jouerKey,
                  onPressed:
                      _etat == _Etat.pret ? () => unawaited(_jouer()) : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Ecouter, puis jouer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
