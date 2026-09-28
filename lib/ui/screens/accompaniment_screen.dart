import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/play/accompaniment.dart';
import '../../core/play/accompaniment_plan.dart';
import '../../core/play/audio_engine.dart';
import '../../core/play/harmonizer.dart';
import '../../core/play/instrument.dart';
import '../widgets/keep_screen_awake.dart';
import '../widgets/score_view.dart';

/// Jouer avec quelqu'un : le passage, et un accompagnement qu'on choisit.
///
/// **Un mode a part, ou l'application joue et n'ecoute pas** (ADR-008) : le
/// haut-parleur est a dix centimetres du micro. Rien n'est note ici. C'est la
/// variete qui manquait au travail d'une mesure qu'on rejoue dix fois -- la
/// meme mesure, avec un piano, une flute, un orgue.
///
/// **C'est l'eleve qui choisit** ce que joue l'accompagnement et avec quel
/// instrument : la melodie pour l'entendre et se caler, la partie ecrite du
/// fichier quand elle existe, ou une basse et des accords deduits.
class AccompanimentScreen extends StatefulWidget {
  const AccompanimentScreen({
    required this.passage,
    required this.engine,
    this.scoreAccompaniment = const <AccompanimentNote>[],
    this.a4 = PitchUtils.defaultA4,
    super.key,
  });

  final Passage passage;
  final AudioEngine engine;

  /// L'accompagnement ecrit du morceau, pour ce passage ; vide sinon.
  final List<AccompanimentNote> scoreAccompaniment;

  /// Le diapason mesure : l'accompagnement s'accorde sur le violon, pas
  /// l'inverse.
  final double a4;

  static const Key jouerKey = Key('accompagnement-jouer');
  static const Key boucleKey = Key('accompagnement-boucle');
  static Key sourceKey(AccompanimentSource s) =>
      Key('accompagnement-source-${s.name}');
  static Key instrumentKey(String id) => Key('accompagnement-instrument-$id');

  @override
  State<AccompanimentScreen> createState() => _AccompanimentScreenState();
}

class _AccompanimentScreenState extends State<AccompanimentScreen>
    with SingleTickerProviderStateMixin {
  late AccompanimentSource _source = widget.scoreAccompaniment.isNotEmpty
      ? AccompanimentSource.score
      : AccompanimentSource.chords;
  String _instrument = 'piano';
  bool _boucle = true;
  double _volume = 0.6;

  InstrumentLibrary _bibliotheque = InstrumentLibrary.vide;

  /// En train de jouer, decompte compris.
  bool _joue = false;

  /// Marge entre le depart demande et la premiere note : le temps de poser
  /// le decompte dans le moteur avant qu'il doive sonner.
  static const Duration _marge = Duration(milliseconds: 300);

  late final Ticker _ticker = createTicker(_remplir);
  AccompanimentScheduler? _planificateur;
  AccompanimentPlan? _plan;
  Duration _origine = Duration.zero;
  Duration _ecoule = Duration.zero;
  Instrument? _instrumentEnCours;

  @override
  void initState() {
    super.initState();
    unawaited(_chargerLesInstruments());
  }

  Future<void> _chargerLesInstruments() async {
    final InstrumentLibrary lib = await widget.engine.instruments();
    if (!mounted) {
      return;
    }
    setState(() {
      _bibliotheque = lib;
      if (lib.byId(_instrument) == null && lib.instruments.isNotEmpty) {
        _instrument = lib.instruments.first.id;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Le son ne survit pas a l'ecran : on revient ensuite jouer ou le micro
    // ecoute, et un accompagnement oublie y serait note.
    unawaited(widget.engine.stopAll());
    super.dispose();
  }

  List<AccompanimentNote> get _notes => switch (_source) {
        AccompanimentSource.melody => melodyOf(widget.passage),
        AccompanimentSource.score => widget.scoreAccompaniment,
        AccompanimentSource.chords => Harmonizer.accompaniment(widget.passage),
      };

  Future<void> _basculer() async {
    if (_joue) {
      await _arreter();
      return;
    }
    setState(() => _joue = true);
    final Instrument? instrument = _bibliotheque.byId(_instrument);
    if (instrument == null) {
      setState(() => _joue = false);
      return;
    }
    // Tout est charge avant de planifier la moindre note : un echantillon qui
    // se charge pendant qu'il devrait sonner sonnerait en retard.
    await widget.engine.prepareInstrument(instrument.id);
    final Duration maintenant = await widget.engine.now();
    if (!mounted || !_joue) {
      return;
    }
    final AccompanimentPlan plan = AccompanimentPlan(
      passage: widget.passage,
      notes: _notes,
      loop: _boucle,
    );
    _plan = plan;
    _instrumentEnCours = instrument;
    _planificateur = AccompanimentScheduler(plan);
    _origine = maintenant + _marge;
    _chrono
      ..reset()
      ..start();
    await _poser(Duration.zero);
    _ticker.start();
  }

  final Stopwatch _chrono = Stopwatch();

  Future<void> _arreter() async {
    _ticker.stop();
    _chrono.stop();
    _planificateur = null;
    setState(() {
      _joue = false;
      _ecoule = Duration.zero;
    });
    await widget.engine.stopAll();
  }

  /// A chaque image : on remplit la file, et on avance le curseur.
  ///
  /// **Ce minuteur ne declenche rien.** Chaque note est posee avec son
  /// instant exact sur l'horloge du moteur ; s'il se reveille en retard, il
  /// pose les memes notes aux memes instants (ADR-012).
  void _remplir(Duration _) {
    final AccompanimentPlan? plan = _plan;
    if (plan == null) {
      return;
    }
    // Le chronometre part avec la marge : la partition commence quand le
    // moteur commence, pas quand on a appuye.
    final Duration ecoule = _chrono.elapsed - _marge;
    unawaited(_poser(_chrono.elapsed));
    setState(() => _ecoule = ecoule);
    if (plan.isFinishedAt(ecoule)) {
      unawaited(_arreter());
    }
  }

  Future<void> _poser(Duration depuisLeDepart) async {
    final AccompanimentScheduler? planificateur = _planificateur;
    final Instrument? instrument = _instrumentEnCours;
    if (planificateur == null || instrument == null) {
      return;
    }
    final (List<TimedClick> clics, List<TimedNote> notes) =
        planificateur.due(depuisLeDepart);
    for (final TimedClick c in clics) {
      await widget.engine
          .scheduleClickAt(at: _origine + c.at, accent: c.accent);
    }
    for (final TimedNote n in notes) {
      await widget.engine.scheduleNote(
        instrument: instrument.id,
        at: _origine + n.at,
        // Ramenee dans la tessiture : une basse confiee a une flute monte
        // d'une octave plutot que de devenir meconnaissable.
        frequencyHz: PitchUtils.midiToFrequency(
          instrument.fold(n.midi),
          a4: widget.a4,
        ),
        duration: n.duration,
        volume: _volume * n.velocity,
      );
    }
  }

  Future<void> _changer(VoidCallback changement) async {
    final bool relancer = _joue;
    if (relancer) {
      await _arreter();
    }
    setState(changement);
    if (relancer) {
      await _basculer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? tick = _joue ? _plan?.tickAt(_ecoule) : null;
    return KeepScreenAwake(
      actif: _joue,
      child: Scaffold(
        appBar: AppBar(title: const Text('Accompagnement')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: <Widget>[
                    Text(
                      '${widget.passage.title} - ${widget.passage.tempoText}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'L application joue avec toi. Elle n ecoute pas, '
                      'elle ne note rien.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text('Ce qu elle joue', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _choixSource(
                          AccompanimentSource.score,
                          'Le piano du morceau',
                          enabled: widget.scoreAccompaniment.isNotEmpty,
                        ),
                        _choixSource(AccompanimentSource.chords, 'Des accords'),
                        _choixSource(AccompanimentSource.melody, 'La melodie'),
                      ],
                    ),
                    if (_source == AccompanimentSource.chords)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Des accords proposes d apres ta melodie : une '
                          'harmonie possible, pas forcement celle du '
                          'compositeur.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('Avec quoi', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final Instrument i in _bibliotheque.instruments)
                          ChoiceChip(
                            key: AccompanimentScreen.instrumentKey(i.id),
                            label: Text(i.name),
                            selected: _instrument == i.id,
                            onSelected: (bool oui) {
                              if (oui) {
                                unawaited(_changer(() => _instrument = i.id));
                              }
                            },
                          ),
                      ],
                    ),
                    SwitchListTile(
                      key: AccompanimentScreen.boucleKey,
                      contentPadding: EdgeInsets.zero,
                      value: _boucle,
                      onChanged: (bool v) =>
                          unawaited(_changer(() => _boucle = v)),
                      title: const Text('En boucle'),
                      subtitle: const Text('Le passage recommence sans arret'),
                    ),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.volume_down, size: 20),
                        Expanded(
                          child: Slider(
                            value: _volume,
                            divisions: 10,
                            // Le volume s'applique aux notes suivantes : pas
                            // besoin de relancer pour l'entendre changer.
                            onChanged: (double v) =>
                                setState(() => _volume = v),
                          ),
                        ),
                        const Icon(Icons.volume_up, size: 20),
                      ],
                    ),
                    SizedBox(
                      height: 240,
                      child: ScoreView(
                        passage: widget.passage,
                        cursorTick: tick,
                        maxSpaceSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  key: AccompanimentScreen.jouerKey,
                  onPressed: _bibliotheque.instruments.isEmpty
                      ? null
                      : () => unawaited(_basculer()),
                  icon: Icon(_joue ? Icons.stop : Icons.play_arrow),
                  label: Text(_joue ? 'Arreter' : 'Jouer ensemble'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choixSource(
    AccompanimentSource source,
    String libelle, {
    bool enabled = true,
  }) =>
      ChoiceChip(
        key: AccompanimentScreen.sourceKey(source),
        label: Text(libelle),
        selected: _source == source,
        onSelected: enabled
            ? (bool oui) {
                if (oui) {
                  unawaited(_changer(() => _source = source));
                }
              }
            : null,
      );
}
