import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/exercises/exercise.dart';
import '../../core/exercises/work_loop.dart';
import '../../core/exercises/exercise_catalog.dart';
import '../../core/exercises/exercise_progress.dart';
import '../../core/import/imported_piece.dart';
import '../../core/import/musicxml_reader.dart';
import '../../core/import/piece_importer.dart';
import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/audio/bench_recorder.dart';
import '../../core/audio/take_player.dart';
import '../../core/play/accompaniment.dart';
import '../../core/play/audio_engine.dart';
import '../../core/play/headphones.dart';
import '../../core/store/piece_store.dart';
import '../../core/store/document_saver.dart';
import '../../core/store/homework.dart';
import '../../core/store/measure_heat.dart';
import '../../core/store/session_store.dart';
import '../../core/store/take_history.dart';
import 'accompaniment_screen.dart';
import 'loop_screen.dart';
import 'bench_screen.dart';
import 'calibration_screen.dart';
import 'drone_screen.dart';
import 'exercises_screen.dart';
import 'free_play_screen.dart';
import 'metronome_screen.dart';
import 'note_by_note_screen.dart';
import 'training_screen.dart';
import 'mic_check_screen.dart';
import 'passage_editor_screen.dart';
import 'piece_screen.dart';
import 'progress_screen.dart';
import 'session_screen.dart';
import 'tuner_screen.dart';

/// La coquille de navigation.
///
/// **L'application n'a pas d'accueil.** Elle s'ouvre sur le travail en cours,
/// et un seul appui lance la prise. Un ecran d'accueil couterait un appui par
/// seance, tous les soirs, pour une information que l'enfant connait deja --
/// et dix secondes sont la duree au-dela de laquelle il repose le violon.
///
/// **Des destinations, et un tiroir d'outils.** Un onglet remplace l'ecran ;
/// un outil se pose par-dessus. L'accordeur se prend violon en main, au
/// milieu d'une seance : l'ouvrir ne doit rien faire perdre.
///
/// Raisonnement complet dans `docs/navigation.md`.
class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.pitchSourceFactory,
    required this.passage,
    required this.a4,
    required this.onPassageChanged,
    required this.onA4Changed,
    required this.audioEngineFactory,
    required this.takePlayerFactory,
    required this.onRemember,
    required this.pieceStore,
    required this.documentPicker,
    required this.pieceImporter,
    this.initialBests = const <ExerciseBest>[],
    this.initialExercise,
    this.initialPieces = PieceLibrary.vide,
    this.initialExcerpt,
    this.benchRecorderFactory,
    this.historyStore,
    this.initialHistory = TakeHistory.vide,
    this.clock = DateTime.now,
    this.documentSaver,
    this.homeworkStore,
    this.initialHomework = HomeworkList.vide,
    this.latencyMs,
    this.onLatencyChanged,
    this.headphones,
    super.key,
  });

  /// Ce qui est branche en sortie, pour l'accompagnement qui suit (J5).
  final HeadphoneProbe? headphones;

  /// La latence mesuree (J2), et de quoi la retenir.
  final int? latencyMs;
  final ValueChanged<int>? onLatencyChanged;

  static const Key latenceKey = Key('calibrer-la-latence');

  /// Les devoirs du professeur (lot T1). `null` : rien ne se retient.
  final HomeworkStore? homeworkStore;
  final HomeworkList initialHomework;

  static const Key donnerKey = Key('donner-en-devoir');
  static Key devoirKey(String workKey) => Key('devoir-$workKey');

  /// Pour enregistrer le rapport de la semaine (T3).
  final DocumentSaver? documentSaver;

  /// L'historique des prises (jalon 9). `null` : rien ne se retient.
  final HistoryStore? historyStore;
  final TakeHistory initialHistory;

  /// L'horloge de l'historique, injectable pour les tests.
  final DateTime Function() clock;

  /// L'enregistreur du banc d'essai, present en debug seulement : sans lui,
  /// l'outil n'apparait pas.
  final BenchRecorderFactory? benchRecorderFactory;

  /// Les morceaux importes, et ce qu'il faut pour en importer (lot H6).
  final PieceStore pieceStore;
  final DocumentPicker documentPicker;
  final PieceImporter pieceImporter;
  final PieceLibrary initialPieces;

  /// Le passage de morceau travaille en dernier, s'il y en avait un.
  final RememberedExcerpt? initialExcerpt;

  final PitchSourceFactory pitchSourceFactory;

  /// Fabrique du moteur de son.
  ///
  /// **Un seul moteur pour toute l'application**, tenu ici. Deux ecrans qui
  /// ouvriraient chacun le materiel audio se marcheraient dessus, et un
  /// bourdon lance depuis un ecran ferme continuerait de sonner.
  final AudioEngineFactory audioEngineFactory;

  /// Fabrique du liseur de prise, pour le mode libre.
  ///
  /// **Une fabrique, pas une instance partagee** comme le moteur de son : une
  /// seule prise se rejoue a la fois, sur un seul ecran, et le liseur meurt
  /// avec lui. Le tenir ici le ferait survivre a l'ecran qui l'a ouvert.
  final TakePlayerFactory takePlayerFactory;

  /// La progression relue, s'il y en avait une.
  final List<ExerciseBest> initialBests;

  /// L'exercice travaille en dernier, s'il y en avait un.
  final Exercise? initialExercise;

  /// Signale ce qu'il y a a se rappeler.
  ///
  /// La coquille ne range rien elle-meme : elle previent, et c'est `ViolonApp`
  /// qui ecrit. Deux ecrivains sur la meme cle, et la derniere ecriture efface
  /// ce que l'autre venait d'ajouter.
  final void Function(
    List<ExerciseBest> bests,
    Exercise? exercice,
    int? tempo,
    RememberedExcerpt? extrait,
  ) onRemember;
  final Passage passage;
  final double a4;
  final ValueChanged<Passage> onPassageChanged;
  final ValueChanged<double> onA4Changed;

  static const Key outilsKey = Key('ouvrir-les-outils');
  static const Key progresKey = Key('onglet-progres');
  static const Key navKey = Key('navigation');

  /// Entree du catalogue de gammes et d'exercices, pour les tests.
  static const Key exercicesKey = Key('ouvrir-les-exercices');

  static const Key importerKey = Key('importer-un-morceau');

  static const Key bourdonKey = Key('ouvrir-le-bourdon');
  static const Key metronomeKey = Key('ouvrir-le-metronome');
  static const Key leconKey = Key('mode-lecon');
  static const Key bancKey = Key('ouvrir-le-banc');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// L'application s'ouvre sur *Jouer*, jamais sur un menu.
  int _destination = 0;

  /// L'ecran de travail est passe en plein ecran.
  ///
  /// La barre de navigation est ici, pas dans l'ecran de travail : lui seul
  /// sait qu'on veut le plein ecran, elle seule peut s'effacer.
  bool _pleinEcran = false;

  /// Ou en est l'eleve dans le catalogue.
  ///
  /// **Volatile, tant que la persistance n'existe pas** (lot H1) : la
  /// progression vit le temps d'une seance. C'est assez pour que l'application
  /// designe la prochaine tache pendant qu'on travaille, et c'est ce qui
  /// compte ce soir.
  late final ExerciseProgress _progres = ExerciseProgress()
    ..restore(widget.initialBests);

  /// Le moteur de son, cree une fois et partage.
  ///
  /// Le construire n'ouvre rien : le materiel audio ne s'ouvre qu'au premier
  /// son demande. Une application qu'on lance pour travailler en silence ne
  /// doit pas reveiller le haut-parleur.
  late final AudioEngine _son = widget.audioEngineFactory();

  /// L'exercice d'ou vient le passage en cours, s'il en vient d'un.
  ///
  /// Un passage saisi a la main n'est pas un exercice du catalogue : il ne
  /// doit rien faire avancer, sinon n'importe quelles quatre mesures
  /// ouvriraient les paliers.
  late Exercise? _exercice = widget.initialExercise;

  /// Tempo de la derniere prise lancee, pour le ranger avec l'exercice.
  late int? _tempo =
      widget.initialExercise == null ? null : widget.passage.writtenTempoBpm;

  /// Les morceaux du repertoire. La coquille les tient et les range elle-meme :
  /// contrairement a la seance, ils ne s'ecrivent qu'a l'import.
  late PieceLibrary _morceaux = widget.initialPieces;

  /// Qui mene la prise : l'eleve (suivi) ou le metronome (lot S6). Garde ici
  /// pour survivre aux changements d'onglet.
  SessionMode _menee = SessionMode.follow;

  /// Ce que les prises ont laisse, d'une seance a l'autre.
  late TakeHistory _historique = widget.initialHistory;

  /// Ce qu'on travaille, de facon stable d'un jour a l'autre : l'exercice,
  /// les mesures du morceau, ou le passage saisi.
  String get _cleDuTravail {
    final Exercise? e = _exercice;
    if (e != null) {
      return 'exo:${e.id}';
    }
    final RememberedExcerpt? x = _extrait;
    if (x != null) {
      return 'piece:${x.pieceId}:${x.fromMeasure}-${x.toMeasure}';
    }
    return 'passage:${widget.passage.title}';
  }

  late HomeworkList _devoirs = widget.initialHomework;

  /// Le mode lecon (T4) : le temps d'un cours, le bilan detaille.
  bool _lecon = false;

  void _rangerLesDevoirs(HomeworkList l) {
    setState(() => _devoirs = l);
    final HomeworkStore? store = widget.homeworkStore;
    if (store != null) {
      unawaited(store.save(l).catchError((Object _) {}));
    }
  }

  /// Le professeur pose le passage en cours en devoir : le tempo vise, et un
  /// mot s'il en a un.
  Future<void> _donnerEnDevoir() async {
    final _Devoir? choix = await showModalBottomSheet<_Devoir>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext c) => _FeuilleDuDevoir(
        passage: widget.passage,
        tempoEcrit: _tempoEcrit ?? widget.passage.pulseBpm,
      ),
    );
    if (choix == null || !mounted) {
      return;
    }
    final RememberedExcerpt? x = _extrait;
    _rangerLesDevoirs(
      _devoirs.withHomework(
        Homework(
          workKey: _cleDuTravail,
          title: widget.passage.title,
          targetPulseBpm: choix.tempo,
          createdAtMs: widget.clock().millisecondsSinceEpoch,
          exerciseId: _exercice?.id,
          pieceId: x?.pieceId,
          fromMeasure: x?.fromMeasure,
          toMeasure: x?.toMeasure,
          note: choix.mot,
        ),
      ),
    );
  }

  /// Rouvre le passage d'un devoir, la ou on le travaille : l'exercice, ou
  /// les mesures du morceau.
  void _ouvrirLeDevoir(Homework d) {
    final String? exo = d.exerciseId;
    if (exo != null) {
      final Exercise? e = ExerciseCatalog.byId(exo);
      if (e == null) {
        return;
      }
      _exercice = e;
      _tempo = _progres.tempoPropose(e);
      _extrait = null;
      _seRappeler();
      widget.onPassageChanged(e.toPassage(tempoBpm: _tempo));
      setState(() => _destination = 0);
      return;
    }
    final String? mo = d.pieceId;
    final int? de = d.fromMeasure;
    final int? a = d.toMeasure;
    final ImportedPiece? m = mo == null ? null : _morceaux.byId(mo);
    final Passage? extrait =
        m == null || de == null || a == null ? null : m.excerpt(de, a);
    if (extrait == null) {
      return;
    }
    _exercice = null;
    _tempo = null;
    _extrait = RememberedExcerpt(pieceId: mo!, fromMeasure: de!, toMeasure: a!);
    _seRappeler();
    widget.onPassageChanged(extrait);
    setState(() => _destination = 0);
  }

  void _garder(TakeRecord fiche) {
    setState(() => _historique = _historique.withTake(fiche));
    final HistoryStore? store = widget.historyStore;
    if (store != null) {
      // Une prise perdue n'empeche pas de jouer : l'ecriture echoue en
      // silence, comme celle de la seance.
      unawaited(store.save(_historique).catchError((Object _) {}));
    }
  }

  /// Le passage de morceau en cours, exclusif de [_exercice].
  late RememberedExcerpt? _extrait = widget.initialExcerpt;

  void _seRappeler() => widget.onRemember(
        _progres.bests.values.toList(growable: false),
        _exercice,
        _tempo,
        _extrait,
      );

  /// Le tempo ecrit du travail en cours, en temps battus : le tempo vise de
  /// l'exercice, ou celui du morceau. Un passage saisi n'en a pas d'autre que
  /// le sien.
  int? get _tempoEcrit {
    final Exercise? exercice = _exercice;
    if (exercice != null) {
      return exercice.tempoVise;
    }
    final RememberedExcerpt? extrait = _extrait;
    if (extrait != null) {
      return _morceaux.byId(extrait.pieceId)?.passage.pulseBpm;
    }
    return null;
  }

  /// Ouvre l'accompagnement du passage en cours, avec la partie ecrite du
  /// morceau quand il en vient d'un.
  Future<void> _accompagner() async {
    final RememberedExcerpt? extrait = _extrait;
    final ImportedPiece? morceau =
        extrait == null ? null : _morceaux.byId(extrait.pieceId);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext c) => AccompanimentScreen(
          passage: widget.passage,
          engine: _son,
          a4: widget.a4,
          scoreAccompaniment: morceau?.accompanimentFor(widget.passage) ??
              const <AccompanimentNote>[],
          pitchSourceFactory: widget.pitchSourceFactory,
          headphones: widget.headphones,
          latencyMs: widget.latencyMs,
        ),
      ),
    );
  }

  /// Le meme passage, a un autre tempo -- et on s'en souvient.
  void _changerDeTempo(int pulse) {
    final Passage passage = widget.passage.withPulseBpm(pulse);
    if (_exercice != null) {
      _tempo = passage.writtenTempoBpm;
    }
    final RememberedExcerpt? extrait = _extrait;
    if (extrait != null) {
      final int? ecrit =
          _morceaux.byId(extrait.pieceId)?.passage.writtenTempoBpm;
      _extrait = extrait.withTempo(
        passage.writtenTempoBpm == ecrit ? null : passage.writtenTempoBpm,
      );
    }
    _seRappeler();
    widget.onPassageChanged(passage);
  }

  void _dire(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Choisit un fichier, le lit, le range, et ouvre le morceau.
  ///
  /// **Chaque echec se dit en une phrase qui dit quoi faire**, et aucun ne
  /// laisse l'application dans un etat intermediaire : un morceau est range
  /// en entier, ou pas du tout.
  Future<void> _importer() async {
    final PickedDocument? document;
    try {
      document = await widget.documentPicker.pick();
    } on Exception {
      _dire('Le fichier n a pas pu etre ouvert.');
      return;
    }
    if (document == null || !mounted) {
      return;
    }
    final ImportedPiece morceau;
    try {
      morceau = widget.pieceImporter.read(document);
    } on ImportException catch (e) {
      _dire(e.message);
      return;
    }
    final PieceLibrary avant = _morceaux;
    setState(() => _morceaux = _morceaux.withPiece(morceau));
    try {
      await widget.pieceStore.save(_morceaux);
    } on Exception {
      if (mounted) {
        setState(() => _morceaux = avant);
        _dire('Le morceau n a pas pu etre range sur le telephone.');
      }
      return;
    }
    if (mounted) {
      await _ouvrirLeMorceau(morceau);
    }
  }

  Future<void> _ouvrirLeMorceau(ImportedPiece morceau) async {
    final RememberedExcerpt? dernier =
        _extrait?.pieceId == morceau.id ? _extrait : null;
    final PieceAction? action = await Navigator.of(context).push<PieceAction>(
      MaterialPageRoute<PieceAction>(
        builder: (BuildContext c) => PieceScreen(
          piece: morceau,
          initialFrom: dernier?.fromMeasure,
          initialTo: dernier?.toMeasure,
          heat: MeasureHeat.of(_historique, morceau.id, widget.clock()),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case WorkBars(from: final int de, to: final int a):
        final Passage? extrait = morceau.excerpt(de, a);
        if (extrait == null) {
          return;
        }
        // D'autres mesures du meme morceau se travaillent au meme tempo : on
        // ne revient pas au tempo du papier parce qu'on a deplace le curseur.
        final int? tempoDeTravail = dernier?.tempoBpm;
        final Passage passage = tempoDeTravail == null
            ? extrait
            : extrait.withTempoBpm(tempoDeTravail);
        // Un passage de morceau n'est pas un exercice : il ne doit rien faire
        // avancer dans le catalogue.
        _exercice = null;
        _tempo = null;
        _extrait = RememberedExcerpt(
            pieceId: morceau.id, fromMeasure: de, toMeasure: a);
        _seRappeler();
        widget.onPassageChanged(passage);
        setState(() => _destination = 0);
      case RemovePiece():
        final PieceLibrary avant = _morceaux;
        setState(() => _morceaux = _morceaux.without(morceau.id));
        try {
          await widget.pieceStore.save(_morceaux);
        } on Exception {
          if (mounted) {
            setState(() => _morceaux = avant);
            _dire('Le morceau n a pas pu etre retire.');
          }
          return;
        }
        if (_extrait?.pieceId == morceau.id) {
          // Le passage en cours reste jouable ce soir ; on cesse seulement de
          // le rouvrir demain sur un morceau qui n'existe plus.
          _extrait = null;
          _seRappeler();
        }
    }
  }

  /// Note la prise dans la progression.
  ///
  /// Un exercice fraichement acquis se dit -- une fois, discretement. C'est
  /// une donnee qui monte, pas une recompense : un chiffre et un tempo, pas
  /// une fanfare.
  void _noterLExercice(SessionResult resultat) {
    final Exercise? exercice = _exercice;
    if (exercice == null) {
      return;
    }
    final bool acquisAvant = _progres.estAcquis(exercice);
    final int palierAvant = _progres.palierOuvert;
    setState(() {
      _progres.record(
        ExerciseAttempt(
          exerciseId: exercice.id,
          score: resultat.score,
          tempoBpm: resultat.tempoBpm,
          coverage: resultat.coverage,
        ),
      );
    });
    _seRappeler();
    if (acquisAvant || !_progres.estAcquis(exercice)) {
      return;
    }
    final int palier = _progres.palierOuvert;
    final int suivant = _progres.tempoPropose(exercice);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          palier > palierAvant
              ? '${exercice.titre} : acquis a ${resultat.tempoBpm}. '
                  'Palier $palier ouvert.'
              // Une donnee qui monte devient une invitation : c'est la seule
              // recompense que le projet s'autorise.
              : '${exercice.titre} : acquis a ${resultat.tempoBpm}. '
                  'Et a $suivant ?',
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_son.dispose());
    super.dispose();
  }

  Future<void> _ouvrirLesExercices() async {
    final ExerciseChoice? choix =
        await Navigator.of(context).push<ExerciseChoice>(
      MaterialPageRoute<ExerciseChoice>(
        builder: (BuildContext context) => ExercisesScreen(progress: _progres),
      ),
    );
    if (choix == null) {
      return;
    }
    if (choix.mode == ExerciseMode.noteANote) {
      // Ni passage ni progression : note a note n'est pas une prise notee,
      // c'est un exercice de main gauche.
      final Exercise exo = choix.exercise;
      if (!mounted || exo is! MotifExercise) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext c) => NoteByNoteScreen(
            exercise: exo,
            pitchSourceFactory: widget.pitchSourceFactory,
            a4: widget.a4,
          ),
        ),
      );
      return;
    }
    if (choix.mode == ExerciseMode.travailler) {
      // On ne touche ni au passage ni a la progression : travailler n'est pas
      // passer. Rien de ce qui se joue ici ne sera note.
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext c) => TrainingScreen(
            exercise: choix.exercise,
            tempoBpm: choix.tempoBpm,
            engine: _son,
            a4: widget.a4,
          ),
        ),
      );
      return;
    }
    _exercice = choix.exercise;
    _tempo = choix.tempoBpm;
    _extrait = null;
    _seRappeler();
    widget.onPassageChanged(
      choix.exercise.toPassage(tempoBpm: choix.tempoBpm),
    );
    // On va jouer : choisir un exercice, c'est vouloir le travailler tout de
    // suite -- pas revenir a une liste.
    setState(() => _destination = 0);
  }

  Future<void> _ouvrirLesOutils() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        // Defilant, et pas seulement "au cas ou" : a cinq outils le tiroir
        // depasse deja la moitie d'un ecran de telephone en portrait. Une
        // colonne qui ne defile pas rognerait le dernier outil au lieu de le
        // laisser atteindre.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Accorder'),
                subtitle: const Text('Les quatre cordes, et les quintes'),
                onTap: () => _ouvrir(
                  context,
                  (BuildContext c) => TunerScreen(
                    pitchSourceFactory: widget.pitchSourceFactory,
                    a4: widget.a4,
                    onA4Changed: widget.onA4Changed,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.graphic_eq),
                title: const Text('Jouer librement'),
                subtitle: const Text('Elle ecoute, elle ne note rien'),
                onTap: () => _ouvrir(
                  context,
                  (BuildContext c) => FreePlayScreen(
                    pitchSourceFactory: widget.pitchSourceFactory,
                    takePlayerFactory: widget.takePlayerFactory,
                    a4: widget.a4,
                  ),
                ),
              ),
              ListTile(
                key: HomeShell.bourdonKey,
                leading: const Icon(Icons.blur_on),
                title: const Text('Bourdon'),
                subtitle: const Text('Une note tenue, pour s accorder dessus'),
                onTap: () => _ouvrir(
                  context,
                  (BuildContext c) => DroneScreen(engine: _son, a4: widget.a4),
                ),
              ),
              ListTile(
                key: HomeShell.metronomeKey,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Metronome'),
                subtitle: const Text('Celui qui fait du bruit'),
                onTap: () => _ouvrir(
                  context,
                  (BuildContext c) => MetronomeScreen(engine: _son),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Est-ce qu elle m entend ?'),
                subtitle: const Text('Verifier le micro'),
                onTap: () => _ouvrir(
                  context,
                  (BuildContext c) => MicCheckScreen(
                    pitchSourceFactory: widget.pitchSourceFactory,
                  ),
                ),
              ),
              ListTile(
                key: HomeShell.latenceKey,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Latence'),
                subtitle: Text(
                  widget.latencyMs == null
                      ? 'A mesurer une fois, pour l accompagnement qui suit'
                      : 'Mesuree : ${widget.latencyMs} ms',
                ),
                onTap: () => _ouvrir(
                  context,
                  (BuildContext c) => CalibrationScreen(
                    engine: _son,
                    pitchSourceFactory: widget.pitchSourceFactory,
                    current: widget.latencyMs,
                    onMeasured: (int l) => widget.onLatencyChanged?.call(l),
                  ),
                ),
              ),
              // En dernier : il sert une fois par semaine. Le temps d'un
              // cours, le bilan donne aussi le detail chiffre, pour le
              // professeur (T4) ; a la maison, une tache.
              StatefulBuilder(
                builder: (BuildContext c, StateSetter majTiroir) =>
                    SwitchListTile(
                  key: HomeShell.leconKey,
                  secondary: const Icon(Icons.school_outlined),
                  title: const Text('Mode lecon'),
                  subtitle: const Text('Le detail chiffre, pour le professeur'),
                  value: _lecon,
                  onChanged: (bool v) {
                    setState(() => _lecon = v);
                    majTiroir(() {});
                  },
                ),
              ),
              if (widget.benchRecorderFactory
                  case final BenchRecorderFactory banc)
                ListTile(
                  key: HomeShell.bancKey,
                  leading: const Icon(Icons.fiber_manual_record_outlined),
                  title: const Text('Banc d essai'),
                  subtitle: const Text('Debug : enregistrer les prises'),
                  onTap: () => _ouvrir(
                    context,
                    (BuildContext c) => BenchScreen(recorder: banc()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Referme le tiroir, puis ouvre l'ecran : sans quoi il resterait derriere.
  void _ouvrir(BuildContext sheetContext, WidgetBuilder builder) {
    Navigator.of(sheetContext).pop();
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: builder),
      ),
    );
  }

  Future<void> _saisirUnPassage() async {
    final Passage? saisi = await Navigator.of(context).push<Passage>(
      MaterialPageRoute<Passage>(
        builder: (BuildContext context) => const PassageEditorScreen(),
      ),
    );
    if (saisi != null) {
      // Un passage saisi n'est plus l'exercice d'avant : sans cet oubli, une
      // prise sur un tout autre passage serait comptee pour lui.
      _exercice = null;
      _tempo = null;
      _extrait = null;
      _seRappeler();
      widget.onPassageChanged(saisi);
      // On revient jouer : saisir un passage, c'est vouloir le travailler.
      setState(() => _destination = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _destination == 0
          ? SessionScreen(
              passage: widget.passage,
              a4: widget.a4,
              pitchSourceFactory: widget.pitchSourceFactory,
              onResult: _noterLExercice,
              onChangePassage: () => unawaited(_saisirUnPassage()),
              onTempoChanged: _changerDeTempo,
              writtenPulseBpm: _tempoEcrit,
              onAccompany: () => unawaited(_accompagner()),
              mode: _menee,
              historyKey: _cleDuTravail,
              takePlayerFactory: widget.takePlayerFactory,
              lesson: _lecon,
              onTakeRecorded: _garder,
              clock: widget.clock,
              onModeChanged: (SessionMode m) => setState(() => _menee = m),
              onLoop: (BarSelection s, int pulse) => unawaited(
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext c) => LoopScreen(
                      passage: widget.passage,
                      selection: s,
                      startPulseBpm: pulse,
                      pitchSourceFactory: widget.pitchSourceFactory,
                      a4: widget.a4,
                    ),
                  ),
                ),
              ),
              // Accorder est la premiere chose de chaque seance : elle
              // merite son raccourci, en plus du tiroir.
              onFullScreen: (bool plein) => setState(() => _pleinEcran = plein),
              onTune: () => unawaited(
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext c) => TunerScreen(
                      pitchSourceFactory: widget.pitchSourceFactory,
                      a4: widget.a4,
                      onA4Changed: widget.onA4Changed,
                    ),
                  ),
                ),
              ),
            )
          : _destination == 2
              ? ProgressScreen(
                  history: _historique,
                  clock: widget.clock,
                  saver: widget.documentSaver,
                )
              : _Repertoire(
                  passage: widget.passage,
                  a4: widget.a4,
                  progres: _progres,
                  exercice: _exercice,
                  onSaisir: () => unawaited(_saisirUnPassage()),
                  onExercices: () => unawaited(_ouvrirLesExercices()),
                  morceaux: _morceaux,
                  onImporter: () => unawaited(_importer()),
                  onMorceau: (ImportedPiece m) =>
                      unawaited(_ouvrirLeMorceau(m)),
                  devoirs: _devoirs,
                  historique: _historique,
                  onDevoir: _ouvrirLeDevoir,
                  onRetirerDevoir: (Homework d) =>
                      _rangerLesDevoirs(_devoirs.without(d.workKey)),
                  onDonner: () => unawaited(_donnerEnDevoir()),
                ),
      bottomNavigationBar: _pleinEcran
          ? null
          : NavigationBar(
              key: HomeShell.navKey,
              selectedIndex: _destination,
              onDestinationSelected: (int i) {
                // Le dernier bouton n'est pas une destination : c'est le tiroir.
                if (i == 3) {
                  unawaited(_ouvrirLesOutils());
                  return;
                }
                setState(() => _destination = i);
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                    icon: Icon(Icons.play_arrow), label: 'Jouer'),
                NavigationDestination(
                  icon: Icon(Icons.library_music),
                  label: 'Repertoire',
                ),
                NavigationDestination(
                  key: HomeShell.progresKey,
                  icon: Icon(Icons.show_chart),
                  label: 'Progres',
                ),
                NavigationDestination(
                  key: HomeShell.outilsKey,
                  icon: Icon(Icons.handyman),
                  label: 'Outils',
                ),
              ],
            ),
    );
  }
}

/// Ce qu'on peut choisir de travailler.
///
/// **Les gammes d'abord, le passage saisi ensuite.** Un exercice ne demande
/// aucune preparation : il se genere, il est pret ce soir. Un passage de
/// morceau se saisit note par note, ce qui est un travail en soi -- donc un
/// geste plus rare, et plus bas dans la liste.
///
/// La troisieme destination prevue par `docs/navigation.md` -- *Progres* --
/// attend la persistance (lot H1) : un onglet vide serait pire que pas
/// d'onglet du tout. Les devoirs du professeur arrivent au jalon 10.
class _Repertoire extends StatelessWidget {
  const _Repertoire({
    required this.passage,
    required this.a4,
    required this.progres,
    required this.exercice,
    required this.onSaisir,
    required this.onExercices,
    required this.morceaux,
    required this.onImporter,
    required this.onMorceau,
    required this.devoirs,
    required this.historique,
    required this.onDevoir,
    required this.onRetirerDevoir,
    required this.onDonner,
  });

  final HomeworkList devoirs;
  final TakeHistory historique;
  final ValueChanged<Homework> onDevoir;
  final ValueChanged<Homework> onRetirerDevoir;
  final VoidCallback onDonner;

  final Passage passage;
  final double a4;
  final ExerciseProgress progres;

  /// L'exercice d'ou vient le passage en cours, s'il en vient d'un.
  final Exercise? exercice;

  final VoidCallback onSaisir;
  final VoidCallback onExercices;
  final PieceLibrary morceaux;
  final VoidCallback onImporter;
  final ValueChanged<ImportedPiece> onMorceau;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Exercise? tache = progres.prochaineTache;
    return Scaffold(
      appBar: AppBar(title: const Text('Repertoire')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // Les devoirs d'abord : c'est ce que le professeur a demande, et
            // l'enfant n'a rien a chercher (T1).
            if (devoirs.items.isNotEmpty) ...<Widget>[
              Text('Les devoirs de la semaine',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final Homework d in devoirs.items)
                Card(
                  child: ListTile(
                    key: HomeShell.devoirKey(d.workKey),
                    leading: Icon(
                      d.doneIn(historique)
                          ? Icons.check_circle
                          : Icons.assignment_outlined,
                      color: d.doneIn(historique)
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    title: Text(d.title),
                    subtitle: Text(<String>[
                      if (d.bestSince(historique) case final int b)
                        'Vise ${d.targetPulseBpm} - tu en es a $b'
                      else
                        'Vise ${d.targetPulseBpm}',
                      if (d.note case final String n) n,
                    ].join('\n')),
                    onTap: () => onDevoir(d),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Retirer ce devoir',
                      onPressed: () => onRetirerDevoir(d),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            Card(
              // "Voila ta prochaine tache" est ce que l'application a a dire
              // ce soir : c'est la seule carte sombre de l'ecran, et il n'y
              // en aura jamais deux.
              color: theme.colorScheme.inverseSurface,
              child: ListTile(
                key: HomeShell.exercicesKey,
                textColor: theme.colorScheme.onInverseSurface,
                iconColor: theme.colorScheme.onInverseSurface,
                leading: const Icon(Icons.straighten),
                title: const Text('Gammes et exercices'),
                subtitle: Text(
                  tache == null
                      ? 'Tout le catalogue est acquis'
                      : 'A travailler : ${tache.titre}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onInverseSurface
                        .withValues(alpha: 0.75),
                  ),
                ),
                trailing: Text(
                  '${progres.acquis}/${ExerciseCatalog.all.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
                onTap: onExercices,
              ),
            ),
            const SizedBox(height: 16),
            Text('Le passage en cours', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Card(
              child: ListTile(
                title: Text(passage.title),
                subtitle: Text(
                  exercice != null
                      // Un exercice ne se decrit pas par ses numeros de
                      // mesure : ils ne sont ecrits sur aucune partition.
                      ? '${exercice!.source.court} - '
                          '${passage.tempoText}'
                      : passage.measureCount == 1
                          ? 'Mesure ${passage.firstMeasure} - '
                              '${passage.tempoText}'
                          : 'Mesures ${passage.firstMeasure} a '
                              '${passage.lastMeasure} - '
                              '${passage.tempoText}',
                ),
                trailing: const Icon(Icons.check_circle_outline),
              ),
            ),
            // Pour le professeur, en fin de cours, sur le telephone de
            // l'enfant : le passage en cours devient le devoir.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: HomeShell.donnerKey,
                onPressed: onDonner,
                icon: const Icon(Icons.assignment_add),
                label: const Text('Donner ce passage en devoir'),
              ),
            ),
            const SizedBox(height: 8),
            Text('Les morceaux', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            if (morceaux.pieces.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Un morceau s importe en MusicXML, exporte depuis MuseScore '
                  'ou un autre logiciel de partition.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final ImportedPiece m in morceaux.pieces)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.library_music_outlined),
                  title: Text(m.title),
                  subtitle: Text(
                    <String>[
                      if (m.composer != null) m.composer!,
                      '${m.lastMeasure - m.firstMeasure + 1} mesures',
                    ].join(' - '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onMorceau(m),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: HomeShell.importerKey,
              onPressed: onImporter,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importer un morceau'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSaisir,
              icon: const Icon(Icons.edit_note),
              label: const Text('Saisir un passage'),
            ),
            const SizedBox(height: 24),
            Text(
              a4 == PitchUtils.defaultA4
                  ? 'Diapason : 440 Hz (par defaut)'
                  : 'Diapason mesure : ${a4.toStringAsFixed(1)} Hz',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ce que le professeur a choisi pour un devoir.
class _Devoir {
  const _Devoir(this.tempo, this.mot);

  final int tempo;
  final String? mot;
}

/// Poser un devoir : le tempo vise, et un mot.
class _FeuilleDuDevoir extends StatefulWidget {
  const _FeuilleDuDevoir({required this.passage, required this.tempoEcrit});

  final Passage passage;
  final int tempoEcrit;

  static const Key poserKey = Key('poser-le-devoir');

  @override
  State<_FeuilleDuDevoir> createState() => _FeuilleDuDevoirState();
}

class _FeuilleDuDevoirState extends State<_FeuilleDuDevoir> {
  late int _tempo = widget.passage.pulseBpm;
  final TextEditingController _mot = TextEditingController();

  @override
  void dispose() {
    _mot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int max = (widget.tempoEcrit * 1.3).round();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.passage.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('Tempo vise : $_tempo (ecrit ${widget.tempoEcrit})'),
          Slider(
            value: _tempo.toDouble().clamp(30, max.toDouble()),
            min: 30,
            max: max.toDouble(),
            divisions: max - 30,
            label: '$_tempo',
            onChanged: (double v) => setState(() => _tempo = v.round()),
          ),
          TextField(
            controller: _mot,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Un mot pour la semaine (facultatif)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: _FeuilleDuDevoir.poserKey,
            onPressed: () => Navigator.of(context).pop(
              _Devoir(
                _tempo,
                _mot.text.trim().isEmpty ? null : _mot.text.trim(),
              ),
            ),
            child: const Text('Poser le devoir'),
          ),
        ],
      ),
    );
  }
}
