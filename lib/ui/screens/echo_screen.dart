import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/echo_game.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/play/audio_engine.dart';
import '../widgets/keep_screen_awake.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// L'echo (jeu G1) : elle joue un motif au violon, il le rejoue d'oreille.
///
/// **Elle emet, puis elle ecoute, jamais les deux** (ADR-008) : le motif
/// sonne, le micro ne s'ouvre qu'une fois le son eteint, et se referme des
/// que le motif est rejoue ou qu'il s'arrete.
class EchoScreen extends StatefulWidget {
  const EchoScreen({
    required this.pool,
    required this.engine,
    required this.pitchSourceFactory,
    this.a4 = PitchUtils.defaultA4,
    this.best = 0,
    this.onBest,
    this.seed,
    super.key,
  });

  final List<int> pool;
  final AudioEngine engine;
  final PitchSourceFactory pitchSourceFactory;
  final double a4;
  final int best;

  /// Appele a chaque nouveau record.
  final ValueChanged<int>? onBest;

  /// Une graine fixe, pour les tests. Sinon, un motif different a chaque
  /// partie.
  final int? seed;

  static const Key ecouterKey = Key('echo-ecouter');
  static const Key messageKey = Key('echo-message');
  static const Key longueurKey = Key('echo-longueur');
  static const Key entenduesKey = Key('echo-entendues');

  /// Une note toutes les demi-secondes : assez lent pour l'entendre, assez
  /// vif pour que ce soit un motif.
  static const Duration pas = Duration(milliseconds: 500);
  static const Duration marge = Duration(milliseconds: 300);
  static const Duration queue = Duration(milliseconds: 400);

  /// Il s'arrete plus de tant apres une note : c'est qu'il a fini.
  static const int finMs = 2500;

  @override
  State<EchoScreen> createState() => _EchoScreenState();
}

enum _Etat { pret, ecoute, joue }

class _EchoScreenState extends State<EchoScreen> {
  late final EchoGame _jeu = EchoGame(
    pool: widget.pool,
    seed: widget.seed ?? DateTime.now().millisecondsSinceEpoch,
    best: widget.best,
  );
  _Etat _etat = _Etat.pret;
  String _message = 'Ecoute le motif, puis rejoue-le.';
  HeardNotes _entendues = HeardNotes();
  Timer? _finDuSon;
  Timer? _veille;
  DateTime? _derniereArrivee;

  PitchSource? _micro;
  StreamSubscription<SmoothedPitch>? _hauteurs;

  Future<void> _ecouter() async {
    await _fermer();
    setState(() {
      _etat = _Etat.ecoute;
      _message = 'Ecoute...';
    });
    await widget.engine.prepareInstrument('violon');
    final Duration maintenant = await widget.engine.now();
    if (!mounted || _etat != _Etat.ecoute) {
      return;
    }
    final List<int> motif = _jeu.motif;
    for (int k = 0; k < motif.length; k++) {
      await widget.engine.scheduleNote(
        instrument: 'violon',
        at: maintenant + EchoScreen.marge + EchoScreen.pas * k,
        frequencyHz: PitchUtils.midiToFrequency(motif[k], a4: widget.a4),
        duration: EchoScreen.pas * 0.9,
        volume: 0.7,
      );
    }
    _finDuSon?.cancel();
    _finDuSon = Timer(
      EchoScreen.marge + EchoScreen.pas * motif.length + EchoScreen.queue,
      () => unawaited(_aToi()),
    );
  }

  Future<void> _aToi() async {
    if (!mounted || _etat != _Etat.ecoute) {
      return;
    }
    setState(() {
      _etat = _Etat.joue;
      _message = 'A toi.';
      _entendues = HeardNotes();
    });
    try {
      final PitchSource micro = await widget.pitchSourceFactory();
      if (!mounted || _etat != _Etat.joue) {
        await micro.dispose();
        return;
      }
      _micro = micro;
      _derniereArrivee = DateTime.now();
      _hauteurs = micro.smoothedPitches.listen(_onHauteur);
      await micro.start();
    } on MicPermissionDenied {
      setState(() {
        _etat = _Etat.pret;
        _message = 'Le micro est refuse : impossible de t entendre.';
      });
      return;
    }
    // Il a fini quand il s'arrete : une veille qui regarde l'heure, pas un
    // declencheur de son.
    _veille = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final DateTime? d = _derniereArrivee;
      if (d != null &&
          DateTime.now().difference(d).inMilliseconds > EchoScreen.finMs) {
        _juger();
      }
    });
  }

  void _onHauteur(SmoothedPitch h) {
    if (_etat != _Etat.joue) {
      return;
    }
    _derniereArrivee = DateTime.now();
    final int avant = _entendues.notes.length;
    _entendues.hear(
      PitchUtils.frequencyToMidi(h.frequencyHz, a4: widget.a4),
      h.timestampMs,
    );
    if (_entendues.notes.length != avant) {
      setState(() {});
      if (_entendues.notes.length >= _jeu.length) {
        _juger();
      }
    }
  }

  void _juger() {
    if (_etat != _Etat.joue) {
      return;
    }
    _veille?.cancel();
    unawaited(_fermer());
    final List<int> joue = _entendues.notes;
    final int longueur = _jeu.length;
    final int justes = _jeu.matchedPrefix(joue);
    final int recordAvant = _jeu.best;
    final bool ok = _jeu.judge(joue);
    if (_jeu.best > recordAvant) {
      widget.onBest?.call(_jeu.best);
    }
    setState(() {
      _etat = _Etat.pret;
      _message = ok
          ? 'C est ca : $longueur notes. La suivante en a ${_jeu.length}.'
          : joue.isEmpty
              ? 'Je n ai rien entendu. On reecoute ?'
              : '${justes == 0 ? 'Pas tout a fait' : 'Les $justes premieres '
                  'etaient justes'}. On reecoute, en ${_jeu.length} notes.';
    });
  }

  Future<void> _fermer() async {
    _veille?.cancel();
    final PitchSource? m = _micro;
    _micro = null;
    unawaited(_hauteurs?.cancel());
    _hauteurs = null;
    await m?.dispose();
  }

  @override
  void dispose() {
    _finDuSon?.cancel();
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
        appBar: AppBar(title: const Text('L echo')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _jeu.best == 0
                      ? 'Pas encore de record'
                      : 'Record : ${_jeu.best} notes',
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Text(
                  '${_jeu.length} notes',
                  key: EchoScreen.longueurKey,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Une pastille par note du motif, pleine quand elle est
                // entendue : on voit ou l'on en est sans voir les notes.
                Wrap(
                  key: EchoScreen.entenduesKey,
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: <Widget>[
                    for (int k = 0; k < _jeu.length; k++)
                      Icon(
                        _etat == _Etat.joue && k < _entendues.notes.length
                            ? Icons.circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _message,
                  key: EchoScreen.messageKey,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton.icon(
                  key: EchoScreen.ecouterKey,
                  onPressed: _etat == _Etat.ecoute
                      ? null
                      : () => unawaited(_ecouter()),
                  icon: const Icon(Icons.hearing),
                  label: Text(_etat == _Etat.joue ? 'Reecouter' : 'Ecouter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
