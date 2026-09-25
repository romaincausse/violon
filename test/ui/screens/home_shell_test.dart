import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_source.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_progress.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/music/demo_passage.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/play/audio_engine.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/core/store/session_store.dart';
import 'package:violon/main.dart';
import 'package:violon/ui/screens/drone_screen.dart';
import 'package:violon/ui/screens/exercises_screen.dart';
import 'package:violon/ui/screens/free_play_screen.dart';
import 'package:violon/ui/screens/home_shell.dart';
import 'package:violon/ui/screens/metronome_screen.dart';
import 'package:violon/ui/screens/mic_check_screen.dart';
import 'package:violon/ui/screens/session_screen.dart';
import 'package:violon/ui/screens/training_screen.dart';
import 'package:violon/ui/screens/tuner_screen.dart';

Future<PitchSource> micMuet() async => FakePitchSource(const <PitchEstimate>[]);

/// Le moteur de son de la derniere application posee.
///
/// Un test de widget n'a pas de haut-parleur : on injecte le moteur factice
/// plutot que SoLoud, qui ouvrirait le materiel audio a chaque `pumpWidget`.
late FakeAudioEngine sonFactice;

AudioEngine sonInjecte() => sonFactice;

/// La memoire de la derniere application posee.
late FakeSessionStore memoireFactice;

SessionStore memoireInjectee() => memoireFactice;

Future<void> poser(WidgetTester tester, {RememberedSession? memoire}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  sonFactice = FakeAudioEngine();
  memoireFactice = FakeSessionStore(memoire ?? RememberedSession.vide);
  await tester.pumpWidget(
    const ViolonApp(
      pitchSourceFactory: micMuet,
      audioEngineFactory: sonInjecte,
      sessionStoreFactory: memoireInjectee,
    ),
  );
  // Deux images : l'application attend d'avoir relu la memoire avant de
  // s'afficher, plutot que de montrer la demo puis de la remplacer.
  await tester.pump();
  await tester.pump();
}

/// Ouvre le tiroir d'outils et laisse l'animation finir.
Future<void> ouvrirLesOutils(WidgetTester tester) async {
  await tester.tap(find.byKey(HomeShell.outilsKey));
  await tester.pumpAndSettle();
}

void main() {
  group('HomeShell', () {
    testWidgets('l application s ouvre sur le travail, pas sur un menu', (
      WidgetTester tester,
    ) async {
      // Dix secondes, c'est la duree au-dela de laquelle un enfant repose le
      // violon. Un ecran d'accueil couterait un appui par seance, tous les
      // soirs, pour une information qu'il connait deja.
      await poser(tester);
      expect(find.byType(SessionScreen), findsOneWidget);
      expect(find.text('Jouer le passage'), findsOneWidget);
    });

    testWidgets('le repertoire montre le passage en cours', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();

      expect(find.text(buildDemoPassage().title), findsOneWidget);
      expect(find.text('Saisir un passage'), findsOneWidget);
    });

    testWidgets('les outils s ouvrent par-dessus, sans changer d onglet', (
      WidgetTester tester,
    ) async {
      // Un onglet remplace l'ecran ; un outil se pose par-dessus. On prend
      // l'accordeur violon en main, au milieu d'une seance.
      await poser(tester);
      await ouvrirLesOutils(tester);

      expect(find.text('Accorder'), findsOneWidget);
      expect(find.text('Jouer librement'), findsOneWidget);
      expect(find.text('Est-ce qu elle m entend ?'), findsOneWidget);
      expect(find.byType(SessionScreen), findsOneWidget,
          reason: 'la seance est toujours la, dessous');
    });

    testWidgets('le tiroir mene a l accordeur', (WidgetTester tester) async {
      await poser(tester);
      await ouvrirLesOutils(tester);
      await tester.tap(find.text('Accorder'));
      await tester.pumpAndSettle();
      expect(find.byType(TunerScreen), findsOneWidget);
    });

    testWidgets('le tiroir mene au mode libre', (WidgetTester tester) async {
      await poser(tester);
      await ouvrirLesOutils(tester);
      await tester.tap(find.text('Jouer librement'));
      await tester.pumpAndSettle();
      expect(find.byType(FreePlayScreen), findsOneWidget);
      expect(find.text('Rien n est note ici.'), findsOneWidget);
    });

    testWidgets('le tiroir mene au controle du micro', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await ouvrirLesOutils(tester);
      await tester.tap(find.text('Est-ce qu elle m entend ?'));
      await tester.pumpAndSettle();
      expect(find.byType(MicCheckScreen), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(MicCheckScreen.sourceKey)).data,
        'source factice',
      );
    });

    testWidgets('accorder garde son raccourci depuis la seance', (
      WidgetTester tester,
    ) async {
      // C'est la premiere chose de chaque seance : elle merite un appui, pas
      // deux.
      await poser(tester);
      await tester.tap(find.byTooltip('Accorder'));
      await tester.pumpAndSettle();
      expect(find.byType(TunerScreen), findsOneWidget);
    });

    testWidgets('le tiroir mene au bourdon', (WidgetTester tester) async {
      await poser(tester);
      await ouvrirLesOutils(tester);
      await tester.tap(find.text('Bourdon'));
      await tester.pumpAndSettle();
      expect(find.byType(DroneScreen), findsOneWidget);
      // Rien ne sonne tant qu'on ne l'a pas demande : ouvrir l'ecran n'ouvre
      // pas le materiel audio.
      expect(sonFactice.drones, isEmpty);
    });

    testWidgets('le tiroir mene au metronome sonore', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await ouvrirLesOutils(tester);
      await tester.tap(find.text('Metronome'));
      await tester.pumpAndSettle();
      expect(find.byType(MetronomeScreen), findsOneWidget);
      expect(sonFactice.clicks, isEmpty);
    });

    testWidgets('lancer l application n ouvre aucun son', (
      WidgetTester tester,
    ) async {
      // Une application qu'on ouvre pour travailler en silence ne doit pas
      // reveiller le haut-parleur. Le moteur est cree, il n'est pas demarre.
      await poser(tester);
      expect(sonFactice.starts, 0);
      expect(sonFactice.isRunning, isFalse);
    });

    testWidgets('le repertoire mene aux gammes et aux exercices', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();

      expect(find.text('Gammes et exercices'), findsOneWidget);
      expect(
        find.text('A travailler : ${ExerciseCatalog.all.first.titre}'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(HomeShell.exercicesKey));
      await tester.pumpAndSettle();
      expect(find.byType(ExercisesScreen), findsOneWidget);
    });

    testWidgets('un exercice choisi devient le passage a jouer', (
      WidgetTester tester,
    ) async {
      // Choisir un exercice, c'est vouloir le travailler tout de suite : on
      // revient jouer, pas a une liste.
      final Exercise premier = ExerciseCatalog.all.first;
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomeShell.exercicesKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(ExercisesScreen.prochaineTacheKey),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesScreen.passerKey));
      await tester.pumpAndSettle();

      expect(find.byType(SessionScreen), findsOneWidget);
      expect(find.text(premier.titre), findsOneWidget);
      expect(
        tester.widget<SessionScreen>(find.byType(SessionScreen)).passage.title,
        premier.titre,
      );
    });

    testWidgets('le repertoire decrit un exercice par sa methode', (
      WidgetTester tester,
    ) async {
      // Un exercice n'a pas de numeros de mesure : ils ne sont ecrits sur
      // aucune partition.
      final Exercise premier = ExerciseCatalog.all.first;
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomeShell.exercicesKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(ExercisesScreen.prochaineTacheKey),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesScreen.passerKey));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();
      expect(
        find.text('${premier.source.court} - ${premier.tempoVise} bpm'),
        findsOneWidget,
      );
    });

    testWidgets('travailler ouvre l entrainement, et ne note rien', (
      WidgetTester tester,
    ) async {
      // Travailler n'est pas passer : le passage en cours ne change pas, et
      // rien de ce qui se joue la ne sera compte.
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomeShell.exercicesKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(ExercisesScreen.prochaineTacheKey),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesScreen.travaillerKey));
      await tester.pumpAndSettle();

      expect(find.byType(TrainingScreen), findsOneWidget);
      expect(find.byType(SessionScreen), findsNothing);
      expect(
        find.text(
          'Rien n est note ici : l application joue, elle n ecoute pas. '
          'Quand tu veux te controler, passe l exercice.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('l application reprend l exercice de la veille', (
      WidgetTester tester,
    ) async {
      // La moitie manquante de "demarrer en dix secondes" : on ouvre, et c'est
      // deja ce qu'on travaillait, au tempo atteint.
      final Exercise hier = ExerciseCatalog.byId('gamme-sol-majeur-2')!;
      await poser(
        tester,
        memoire: const RememberedSession(
          exerciseId: 'gamme-sol-majeur-2',
          tempoBpm: 76,
        ),
      );

      final SessionScreen ecran =
          tester.widget<SessionScreen>(find.byType(SessionScreen));
      expect(ecran.passage.title, hier.titre);
      expect(ecran.passage.writtenTempoBpm, 76);
    });

    testWidgets('la progression relue est celle qui s affiche', (
      WidgetTester tester,
    ) async {
      final Exercise fait = ExerciseCatalog.all.first;
      await poser(
        tester,
        memoire: RememberedSession(
          bests: <ExerciseBest>[
            ExerciseBest(
              exerciseId: fait.id,
              meilleurScore: 96,
              meilleurTempoPropre: fait.tempoVise,
              essais: 4,
            ),
          ],
        ),
      );
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();

      expect(find.text('1/19'), findsOneWidget);
      expect(
        find.text('A travailler : ${ExerciseCatalog.all[1].titre}'),
        findsOneWidget,
      );
    });

    testWidgets('choisir un exercice le range pour la prochaine fois', (
      WidgetTester tester,
    ) async {
      final Exercise premier = ExerciseCatalog.all.first;
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomeShell.exercicesKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(ExercisesScreen.prochaineTacheKey),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesScreen.passerKey));
      await tester.pumpAndSettle();

      expect(memoireFactice.current.exerciseId, premier.id);
      expect(memoireFactice.current.tempoBpm, premier.tempoVise);
    });

    testWidgets('travailler ne range rien : ce n est pas une prise', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomeShell.exercicesKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(ExercisesScreen.prochaineTacheKey),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesScreen.travaillerKey));
      await tester.pumpAndSettle();

      expect(memoireFactice.current.exerciseId, isNull);
    });

    testWidgets('le diapason par defaut est annonce au repertoire', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();
      expect(
        find.text('Diapason : ${PitchUtils.defaultA4.round()} Hz (par defaut)'),
        findsOneWidget,
      );
    });
  });
}
