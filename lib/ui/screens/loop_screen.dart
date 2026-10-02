import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/work_loop.dart';
import '../../core/follow/performance_features.dart';
import '../../core/follow/take_follower.dart';
import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/scoring/rhythm_judge.dart';
import '../../core/scoring/take_report.dart';
import '../widgets/keep_screen_awake.dart';
import '../widgets/score_view.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// La boucle de travail (jalon 8) : quelques mesures, encore et encore, et
/// le tempo qui monte quand ca tient.
///
/// **L'application propose, il dispose** (R5) : la selection arrive toute
/// faite quand le bilan l'a designee (R1), et se change d'un geste avant de
/// commencer.
///
/// **Un seul micro pour toute la boucle.** Le rouvrir a chaque essai couterait
/// une demi-seconde et un clic dans le haut-parleur ; il reste ouvert, et
/// chaque essai a son propre suivi.
class LoopScreen extends StatefulWidget {
  const LoopScreen({
    required this.passage,
    required this.selection,
    required this.startPulseBpm,
    required this.pitchSourceFactory,
    this.a4 = PitchUtils.defaultA4,
    super.key,
  });

  /// Le passage entier, dans lequel la selection se decoupe.
  final Passage passage;
  final BarSelection selection;

  /// Le tempo de depart : celui qu'il tenait.
  final int startPulseBpm;
  final PitchSourceFactory pitchSourceFactory;
  final double a4;

  static const Key commencerKey = Key('boucle-commencer');
  static const Key ruptureKey = Key('boucle-rupture');
  static const Key selectionKey = Key('boucle-selection');
  static const Key objectifKey = Key('boucle-objectif');
  static const Key reussitesKey = Key('boucle-reussites');
  static const Key messageKey = Key('boucle-message');
  static const Key finirKey = Key('boucle-finir');

  @override
  State<LoopScreen> createState() => _LoopScreenState();
}

class _LoopScreenState extends State<LoopScreen> {
  late BarSelection _selection = widget.selection;
  bool _rupture = false;

  WorkLoop? _boucle;
  TakeFollower? _essai;
  PitchSource? _source;
  StreamSubscription<SmoothedPitch>? _hauteurs;
  StreamSubscription<FeatureFrame>? _trames;
  String? _message;
  bool _micRefuse = false;

  /// Le dernier essai a rate et il veut s'arreter : une derniere fois, la ou
  /// ca tenait (R4).
  bool _derniere = false;

  bool get _enCours => _boucle != null;

  static const int _abandonMs = 3000;

  Passage? get _extrait => WorkLoop.excerpt(widget.passage, _selection);

  String get _unite =>
      widget.passage.meter?.pulseName(widget.passage.ticksPerBeat) ?? 'noire';

  @override
  void dispose() {
    unawaited(_fermer());
    super.dispose();
  }

  Future<void> _commencer() async {
    final Passage? extrait = _extrait;
    if (extrait == null) {
      return;
    }
    setState(() {
      _boucle = WorkLoop(
        selection: _selection,
        startPulseBpm: widget.startPulseBpm,
        writtenPulseBpm: widget.passage.pulseBpm,
        findBreakingPoint: _rupture,
      );
      _essai = TakeFollower(extrait, a4: widget.a4);
      _message = 'Joue les ${_selection.length == 1 ? 'la mesure' : 'mesures'}'
          ' quand tu veux.';
      _derniere = false;
    });
    try {
      final PitchSource source = await widget.pitchSourceFactory();
      if (!mounted || !_enCours) {
        await source.dispose();
        return;
      }
      _source = source;
      _hauteurs = source.smoothedPitches.listen((SmoothedPitch h) {
        _essai?.addPitch(h);
      });
      _trames = source.features.listen(_onTrame);
      await source.start();
    } on MicPermissionDenied {
      if (mounted) {
        setState(() {
          _micRefuse = true;
          _boucle = null;
        });
      }
    }
  }

  void _onTrame(FeatureFrame trame) {
    final TakeFollower? essai = _essai;
    if (essai == null) {
      return;
    }
    essai.addFrame(trame);
    // Fini : la derniere note et l'archet pose. Ou abandonne en route : trois
    // secondes sans jouer, et l'essai compte -- sans reussite -- pour que le
    // suivant reparte du debut de la selection.
    if (essai.finished || (essai.started && essai.restingForMs >= _abandonMs)) {
      _terminerLEssai(essai);
    } else {
      setState(() {});
    }
  }

  void _terminerLEssai(TakeFollower essai) {
    final WorkLoop? boucle = _boucle;
    final Passage? extrait = _extrait;
    if (boucle == null || extrait == null) {
      return;
    }
    essai.rescore();
    final RhythmJudge juge = essai.rhythm!;
    final TakeReport rapport = essai.report!;
    final int arrets =
        rapport.measures.fold<int>(0, (int n, MeasureReport m) => n + m.stops);
    final LoopAttempt tentative = LoopAttempt(
      reachedEnd: essai.reachedEnd,
      tuningScore: essai.tuning.overallScore,
      rhythmScore: juge.overallScore,
      heldPulseBpm: juge.pulseBpm,
      stops: arrets,
      targetPulseBpm: boucle.targetPulseBpm,
    );
    final LoopStep suite = boucle.record(tentative);
    final bool derniereReussie = _derniere && tentative.success;
    setState(() {
      _message = derniereReussie
          ? 'Ca tient. On s arrete sur une reussite.'
          : _dire(tentative, suite, boucle);
      // Le prochain essai repart de zero ; la boucle, elle, se souvient.
      _essai = TakeFollower(extrait, a4: widget.a4);
    });
    if (suite == LoopStep.done || derniereReussie) {
      unawaited(_fermer());
      setState(() => _boucle = null);
    }
  }

  /// Une phrase par essai, sans reproche : ce qui s'est passe, et ce qu'on
  /// fait maintenant.
  String _dire(LoopAttempt t, LoopStep suite, WorkLoop b) {
    final String tenu =
        t.heldPulseBpm == null ? '' : ' (tu as joue a ${t.heldPulseBpm})';
    return switch (suite) {
      LoopStep.done =>
        'Ca tient au tempo ${b.findBreakingPoint ? 'consolide' : 'ecrit'}'
            ' : ${b.targetPulseBpm}. Bravo.',
      LoopStep.faster =>
        'Deux fois de suite ! Un cran plus vite : vise ${b.targetPulseBpm}.',
      LoopStep.consolidate => 'Point de rupture : ${b.breakingPointBpm}. '
          'On consolide a ${b.targetPulseBpm}.',
      LoopStep.again => t.success
          ? 'Ca tient$tenu. Encore une fois pour monter.'
          : !t.reachedEnd
              ? 'Va jusqu au bout de la selection, puis pose l archet.'
              : t.stops > 0
                  ? 'Encore une fois, sans t arreter$tenu.'
                  : (t.heldPulseBpm ?? 0) <
                          t.targetPulseBpm * WorkLoop.tempoTolerance
                      ? 'Encore une fois, en visant ${t.targetPulseBpm}$tenu.'
                      : 'Encore une fois$tenu.',
    };
  }

  /// Il veut s'arreter. Sur un echec, on propose une derniere fois (R4).
  Future<void> _arreter() async {
    final WorkLoop? boucle = _boucle;
    final int? derniere = boucle?.finishOnSuccessPulseBpm;
    if (boucle != null && derniere != null && !_derniere) {
      setState(() {
        _derniere = true;
        _message = 'Une derniere fois, a $derniere : on termine sur une '
            'reussite.';
      });
      return;
    }
    await _fermer();
    if (mounted) {
      setState(() {
        _boucle = null;
        _essai = null;
      });
    }
  }

  Future<void> _fermer() async {
    final PitchSource? source = _source;
    _source = null;
    unawaited(_hauteurs?.cancel());
    unawaited(_trames?.cancel());
    _hauteurs = null;
    _trames = null;
    await source?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WorkLoop? boucle = _boucle;
    final Passage? extrait = _extrait;
    final TakeFollower? essai = _essai;
    final int? i = essai?.position?.noteIndex;
    final int? tick = i == null || extrait == null || !_enCours
        ? null
        : essai!.position!.resting
            ? extrait.notes[i].offsetTicks
            : extrait.notes[i].onsetTicks;
    return KeepScreenAwake(
      actif: _enCours,
      child: Scaffold(
        appBar: AppBar(title: Text('Boucle - $_selection')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!_enCours) ...<Widget>[
                  Text('Les mesures', style: theme.textTheme.titleSmall),
                  _choixDesMesures(),
                  SwitchListTile(
                    key: LoopScreen.ruptureKey,
                    contentPadding: EdgeInsets.zero,
                    value: _rupture,
                    onChanged: (bool v) => setState(() => _rupture = v),
                    title: const Text('Chercher mon point de rupture'),
                    subtitle: const Text(
                      'Le tempo monte jusqu a ce que ca casse, puis redescend',
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    'Vise ${boucle!.targetPulseBpm} ($_unite)',
                    key: LoopScreen.objectifKey,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reussis : ${boucle.successes}'
                    '${boucle.bestPulseBpm == null ? '' : ' - meilleur tempo : ${boucle.bestPulseBpm}'}',
                    key: LoopScreen.reussitesKey,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  // Deux points : ce qu'il faut pour monter d'un cran.
                  Row(
                    children: <Widget>[
                      for (int k = 0; k < WorkLoop.successesToClimb; k++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            k < boucle.streak
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (extrait != null)
                  Expanded(
                    child: ScoreView(
                      passage: extrait,
                      cursorTick: tick,
                      cursorUncertain: essai?.unsure ?? false,
                    ),
                  )
                else
                  const Spacer(),
                if (_message != null || _micRefuse)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _micRefuse
                          ? 'Micro refuse : la boucle a besoin de t entendre.'
                          : _message!,
                      key: LoopScreen.messageKey,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (_enCours)
                  FilledButton.icon(
                    key: LoopScreen.finirKey,
                    onPressed: () => unawaited(_arreter()),
                    icon: const Icon(Icons.stop),
                    label: Text(_derniere ? 'Arreter quand meme' : 'Arreter'),
                  )
                else
                  FilledButton.icon(
                    key: LoopScreen.commencerKey,
                    onPressed:
                        extrait == null ? null : () => unawaited(_commencer()),
                    icon: const Icon(Icons.repeat),
                    label: const Text('Commencer la boucle'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// R5 : il choisit ses mesures, d'un geste. Celles que le bilan a
  /// designees sont deja la.
  Widget _choixDesMesures() {
    final int premiere = widget.passage.firstMeasure;
    final int derniere = widget.passage.lastMeasure;
    if (premiere == derniere) {
      return Text('Mesure $premiere');
    }
    return RangeSlider(
      key: LoopScreen.selectionKey,
      min: premiere.toDouble(),
      max: derniere.toDouble(),
      divisions: derniere - premiere,
      values: RangeValues(
        _selection.from.toDouble(),
        _selection.to.toDouble(),
      ),
      labels: RangeLabels('${_selection.from}', '${_selection.to}'),
      onChanged: (RangeValues v) => setState(
        () => _selection = BarSelection(v.start.round(), v.end.round()),
      ),
    );
  }
}
