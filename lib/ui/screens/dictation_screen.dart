import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/dictation_drill.dart';
import '../../core/follow/performance_features.dart';
import '../../core/follow/take_follower.dart';
import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/play/accompaniment_plan.dart';
import '../../core/play/audio_engine.dart';
import '../widgets/keep_screen_awake.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// La dictee d'une mesure (lot L2) : elle joue, il rejoue d'oreille.
///
/// **Elle emet, puis elle ecoute, jamais les deux** (ADR-008) : la mesure
/// sonne au violon enregistre, le micro ne s'ouvre qu'une fois le son fini,
/// et se referme des que l'archet est pose. Rien n'est garde : une dictee
/// n'est pas une prise.
class DictationScreen extends StatefulWidget {
  const DictationScreen({
    required this.passage,
    required this.engine,
    required this.pitchSourceFactory,
    this.a4 = PitchUtils.defaultA4,
    this.instrument = 'violon',
    super.key,
  });

  final Passage passage;
  final AudioEngine engine;
  final PitchSourceFactory pitchSourceFactory;
  final double a4;

  /// Le violon : c'est ce qu'il doit reconnaitre, et ce qu'il va rejouer.
  final String instrument;

  static const Key ecouterKey = Key('dictee-ecouter');
  static const Key passerKey = Key('dictee-passer');
  static const Key mesureKey = Key('dictee-mesure');
  static const Key messageKey = Key('dictee-message');
  static const Key compteKey = Key('dictee-compte');

  /// Avant la premiere note : le temps de poser les notes dans le moteur.
  static const Duration marge = Duration(milliseconds: 300);

  /// Apres la derniere : le temps qu'elle s'eteigne avant d'ouvrir le micro.
  static const Duration queue = Duration(milliseconds: 400);

  /// Trois secondes sans jouer, et la mesure est rendue telle quelle.
  static const int abandonMs = 3000;

  @override
  State<DictationScreen> createState() => _DictationScreenState();
}

enum _Etat { pret, ecoute, joue }

class _DictationScreenState extends State<DictationScreen> {
  late final DictationDrill _dictee = DictationDrill(passage: widget.passage);
  _Etat _etat = _Etat.pret;
  String _message = 'Ecoute la mesure, puis rejoue-la d oreille.';
  Timer? _finDuSon;

  PitchSource? _micro;
  StreamSubscription<SmoothedPitch>? _hauteurs;
  StreamSubscription<FeatureFrame>? _trames;
  TakeFollower? _essai;

  Future<void> _ecouter() async {
    await _fermerLeMicro();
    setState(() {
      _etat = _Etat.ecoute;
      _message = 'Ecoute...';
    });
    await widget.engine.prepareInstrument(widget.instrument);
    final Duration maintenant = await widget.engine.now();
    if (!mounted || _etat != _Etat.ecoute) {
      return;
    }
    final Duration depart = maintenant + DictationScreen.marge;
    for (final TimedNote n in _dictee.notesToPlay) {
      await widget.engine.scheduleNote(
        instrument: widget.instrument,
        at: depart + n.at,
        frequencyHz: PitchUtils.midiToFrequency(n.midi, a4: widget.a4),
        duration: n.duration,
        volume: 0.7,
      );
    }
    _finDuSon?.cancel();
    _finDuSon = Timer(
      DictationScreen.marge + _dictee.playingLength + DictationScreen.queue,
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
    });
    _essai = TakeFollower(_dictee.excerpt, a4: widget.a4);
    try {
      final PitchSource micro = await widget.pitchSourceFactory();
      if (!mounted || _etat != _Etat.joue) {
        await micro.dispose();
        return;
      }
      _micro = micro;
      _hauteurs = micro.smoothedPitches.listen((SmoothedPitch h) {
        _essai?.addPitch(h);
      });
      _trames = micro.features.listen(_onTrame);
      await micro.start();
    } on MicPermissionDenied {
      setState(() {
        _etat = _Etat.pret;
        _message = 'Le micro est refuse : impossible de t entendre.';
      });
    }
  }

  void _onTrame(FeatureFrame trame) {
    final TakeFollower? essai = _essai;
    if (essai == null || _etat != _Etat.joue) {
      return;
    }
    essai.addFrame(trame);
    if (essai.finished ||
        (essai.started && essai.restingForMs >= DictationScreen.abandonMs)) {
      _juger(essai);
    }
  }

  void _juger(TakeFollower essai) {
    _essai = null;
    unawaited(_fermerLeMicro());
    final int avant = _dictee.measure;
    final bool ok = _dictee.judge(essai);
    setState(() {
      _etat = _Etat.pret;
      _message = ok
          ? 'C est ca. La mesure $avant est entendue.'
          : 'Pas tout a fait. Ecoute encore la mesure $avant.';
    });
  }

  void _passer() {
    _dictee.skip();
    setState(() => _message = 'On passe a la mesure ${_dictee.measure}.');
  }

  Future<void> _fermerLeMicro() async {
    final PitchSource? m = _micro;
    _micro = null;
    unawaited(_hauteurs?.cancel());
    unawaited(_trames?.cancel());
    _hauteurs = null;
    _trames = null;
    await m?.dispose();
  }

  @override
  void dispose() {
    _finDuSon?.cancel();
    unawaited(_fermerLeMicro());
    unawaited(widget.engine.stopAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return KeepScreenAwake(
      actif: _etat != _Etat.pret,
      child: Scaffold(
        appBar: AppBar(title: const Text('Dictee')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  widget.passage.title,
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Text(
                  'Mesure ${_dictee.measure}',
                  key: DictationScreen.mesureKey,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _message,
                  key: DictationScreen.messageKey,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_dictee.heard} mesure${_dictee.heard > 1 ? 's' : ''} '
                  'entendue${_dictee.heard > 1 ? 's' : ''}',
                  key: DictationScreen.compteKey,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton.icon(
                  key: DictationScreen.ecouterKey,
                  onPressed: _etat == _Etat.ecoute
                      ? null
                      : () => unawaited(_ecouter()),
                  icon: const Icon(Icons.hearing),
                  label: Text(_etat == _Etat.joue ? 'Reecouter' : 'Ecouter'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: DictationScreen.passerKey,
                  onPressed: _etat == _Etat.pret ? _passer : null,
                  child: const Text('Passer a la suivante'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
