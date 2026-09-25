import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/exercises/exercise.dart';
import '../../core/exercises/exercise_catalog.dart';
import '../../core/exercises/exercise_progress.dart';
import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/play/audio_engine.dart';
import 'drone_screen.dart';
import 'exercises_screen.dart';
import 'free_play_screen.dart';
import 'metronome_screen.dart';
import 'mic_check_screen.dart';
import 'passage_editor_screen.dart';
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
    super.key,
  });

  final PitchSourceFactory pitchSourceFactory;

  /// Fabrique du moteur de son.
  ///
  /// **Un seul moteur pour toute l'application**, tenu ici. Deux ecrans qui
  /// ouvriraient chacun le materiel audio se marcheraient dessus, et un
  /// bourdon lance depuis un ecran ferme continuerait de sonner.
  final AudioEngineFactory audioEngineFactory;
  final Passage passage;
  final double a4;
  final ValueChanged<Passage> onPassageChanged;
  final ValueChanged<double> onA4Changed;

  static const Key outilsKey = Key('ouvrir-les-outils');
  static const Key navKey = Key('navigation');

  /// Entree du catalogue de gammes et d'exercices, pour les tests.
  static const Key exercicesKey = Key('ouvrir-les-exercices');

  static const Key bourdonKey = Key('ouvrir-le-bourdon');
  static const Key metronomeKey = Key('ouvrir-le-metronome');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// L'application s'ouvre sur *Jouer*, jamais sur un menu.
  int _destination = 0;

  /// Ou en est l'eleve dans le catalogue.
  ///
  /// **Volatile, tant que la persistance n'existe pas** (lot H1) : la
  /// progression vit le temps d'une seance. C'est assez pour que l'application
  /// designe la prochaine tache pendant qu'on travaille, et c'est ce qui
  /// compte ce soir.
  final ExerciseProgress _progres = ExerciseProgress();

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
  Exercise? _exercice;

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
    if (acquisAvant || !_progres.estAcquis(exercice)) {
      return;
    }
    final int palier = _progres.palierOuvert;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          palier > palierAvant
              ? '${exercice.titre} : acquis a ${resultat.tempoBpm}. '
                  'Palier $palier ouvert.'
              : '${exercice.titre} : acquis a ${resultat.tempoBpm}.',
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
    _exercice = choix.exercise;
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
              // Accorder est la premiere chose de chaque seance : elle
              // merite son raccourci, en plus du tiroir.
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
          : _Repertoire(
              passage: widget.passage,
              a4: widget.a4,
              progres: _progres,
              exercice: _exercice,
              onSaisir: () => unawaited(_saisirUnPassage()),
              onExercices: () => unawaited(_ouvrirLesExercices()),
            ),
      bottomNavigationBar: NavigationBar(
        key: HomeShell.navKey,
        selectedIndex: _destination,
        onDestinationSelected: (int i) {
          // Le dernier bouton n'est pas une destination : c'est le tiroir.
          if (i == 2) {
            unawaited(_ouvrirLesOutils());
            return;
          }
          setState(() => _destination = i);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.play_arrow), label: 'Jouer'),
          NavigationDestination(
            icon: Icon(Icons.library_music),
            label: 'Repertoire',
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
  });

  final Passage passage;
  final double a4;
  final ExerciseProgress progres;

  /// L'exercice d'ou vient le passage en cours, s'il en vient d'un.
  final Exercise? exercice;

  final VoidCallback onSaisir;
  final VoidCallback onExercices;

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
            Card(
              color: theme.colorScheme.primaryContainer,
              child: ListTile(
                key: HomeShell.exercicesKey,
                leading: const Icon(Icons.straighten),
                title: const Text('Gammes et exercices'),
                subtitle: Text(
                  tache == null
                      ? 'Tout le catalogue est acquis'
                      : 'A travailler : ${tache.titre}',
                ),
                trailing: Text(
                  '${progres.acquis}/${ExerciseCatalog.all.length}',
                  style: theme.textTheme.titleMedium,
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
                          '${passage.writtenTempoBpm} bpm'
                      : passage.measureCount == 1
                          ? 'Mesure ${passage.firstMeasure} - '
                              '${passage.writtenTempoBpm} bpm'
                          : 'Mesures ${passage.firstMeasure} a '
                              '${passage.lastMeasure} - '
                              '${passage.writtenTempoBpm} bpm',
                ),
                trailing: const Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
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
