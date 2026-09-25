import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/exercises/exercise_progress.dart';
import 'package:violon/ui/screens/exercises_screen.dart';

/// Ouvre l'ecran derriere un vrai Navigator, et rend de quoi lire son choix.
///
/// Le Navigator n'est pas un decor : la moitie du travail de l'ecran consiste
/// a se refermer en rendant l'exercice choisi.
Future<ExerciseChoice? Function()> ouvrir(
  WidgetTester tester, {
  ExerciseProgress? progress,
  Size taille = const Size(400, 800),
}) async {
  ExerciseChoice? choix;
  await tester.binding.setSurfaceSize(taille);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final ExerciseProgress progres = progress ?? ExerciseProgress();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                choix = await Navigator.of(context).push<ExerciseChoice>(
                  MaterialPageRoute<ExerciseChoice>(
                    builder: (BuildContext c) =>
                        ExercisesScreen(progress: progres),
                  ),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return () => choix;
}

/// Fait defiler jusqu'a ce que l'element soit **visible**, pas seulement
/// construit : un widget present a 818 pixels d'une fenetre de 800 ne recoit
/// pas les appuis.
Future<void> atteindre(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('ExercisesScreen', () {
    testWidgets('la prochaine tache est en tete, avant le catalogue', (
      WidgetTester tester,
    ) async {
      // Ouvrir sur dix-neuf exercices non acquis serait ouvrir sur un bilan
      // d echec. Une tache, puis le reste pour qui veut choisir.
      await ouvrir(tester);
      expect(find.byKey(ExercisesScreen.prochaineTacheKey), findsOneWidget);
      expect(find.text('Ta prochaine tache'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ExercisesScreen.prochaineTacheKey),
          matching: find.text(ExerciseCatalog.all.first.titre),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tout le catalogue est atteignable', (
      WidgetTester tester,
    ) async {
      await ouvrir(tester);
      for (final Exercise exercise in ExerciseCatalog.all) {
        await atteindre(
            tester, find.byKey(ExercisesScreen.tileKey(exercise.id)));
        expect(find.byKey(ExercisesScreen.tileKey(exercise.id)), findsOneWidget,
            reason: exercise.id);
      }
    });

    testWidgets('le palier ouvert n a pas de cadenas, le suivant si', (
      WidgetTester tester,
    ) async {
      await ouvrir(tester);
      expect(
        find.descendant(
          of: find.byKey(ExercisesScreen.palierKey(1)),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsNothing,
      );
      await atteindre(tester, find.byKey(ExercisesScreen.palierKey(2)));
      expect(
        find.descendant(
          of: find.byKey(ExercisesScreen.palierKey(2)),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('un palier ferme reste jouable', (WidgetTester tester) async {
      // ADR-011 : la progression guide, elle ne verrouille pas. Si le
      // professeur a donne la gamme de si bemol cette semaine, l application
      // n a pas a la refuser.
      final Exercise ferme = ExerciseCatalog.byId('gamme-si-bemol-majeur-2')!;
      final ExerciseChoice? Function() choix = await ouvrir(tester);
      await atteindre(tester, find.byKey(ExercisesScreen.tileKey(ferme.id)));
      await tester.tap(find.byKey(ExercisesScreen.tileKey(ferme.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesScreen.travaillerKey));
      await tester.pumpAndSettle();
      expect(choix()?.exercise.id, ferme.id);
    });

    testWidgets('choisir la prochaine tache rend le tempo vise', (
      WidgetTester tester,
    ) async {
      final Exercise premier = ExerciseCatalog.all.first;
      final ExerciseChoice? Function() choix = await ouvrir(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(ExercisesScreen.prochaineTacheKey),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesScreen.travaillerKey));
      await tester.pumpAndSettle();
      expect(choix()?.exercise.id, premier.id);
      expect(choix()?.tempoBpm, premier.tempoVise);
    });

    testWidgets('le tempo de travail peut descendre sous le tempo vise', (
      WidgetTester tester,
    ) async {
      final Exercise premier = ExerciseCatalog.all.first;
      final ExerciseChoice? Function() choix = await ouvrir(tester);
      await tester.tap(find.byKey(ExercisesScreen.tileKey(premier.id)));
      await tester.pumpAndSettle();

      // On glisse le reglage a fond vers la gauche : le minimum utile.
      await tester.drag(
        find.byKey(ExercisesScreen.tempoKey),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesScreen.travaillerKey));
      await tester.pumpAndSettle();

      expect(choix()?.tempoBpm, 40);
      expect(choix()?.exercise.id, premier.id);
    });

    testWidgets('refermer la feuille ne choisit rien', (
      WidgetTester tester,
    ) async {
      final ExerciseChoice? Function() choix = await ouvrir(tester);
      await tester.tap(
        find.byKey(ExercisesScreen.tileKey(ExerciseCatalog.all.first.id)),
      );
      await tester.pumpAndSettle();
      // Un appui a cote referme la feuille : l ecran doit rester ouvert.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(choix(), isNull);
      expect(find.byType(ExercisesScreen), findsOneWidget);
    });

    testWidgets('le conseil d un exercice s affiche avec le tempo', (
      WidgetTester tester,
    ) async {
      final Exercise avecConseil =
          ExerciseCatalog.all.firstWhere((Exercise e) => e.conseil != null);
      await ouvrir(tester);
      await atteindre(
        tester,
        find.byKey(ExercisesScreen.tileKey(avecConseil.id)),
      );
      await tester.tap(find.byKey(ExercisesScreen.tileKey(avecConseil.id)));
      await tester.pumpAndSettle();
      expect(find.text(avecConseil.conseil!), findsOneWidget);
    });

    testWidgets('ce qui est acquis se voit, et la tache avance', (
      WidgetTester tester,
    ) async {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise premier = ExerciseCatalog.all.first;
      progres.record(ExerciseAttempt(
        exerciseId: premier.id,
        score: 94,
        tempoBpm: premier.tempoVise,
      ));
      await ouvrir(tester, progress: progres);

      expect(find.text('1 exercice acquis sur ${ExerciseCatalog.all.length}'),
          findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ExercisesScreen.prochaineTacheKey),
          matching: find.text(ExerciseCatalog.all[1].titre),
        ),
        findsOneWidget,
      );
      // Des donnees qui montent : le score obtenu et le tempo ou il a tenu.
      expect(
        find.descendant(
          of: find.byKey(ExercisesScreen.tileKey(premier.id)),
          matching: find.text('94\na ${premier.tempoVise}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tout acquis : plus de tache, et ca se dit', (
      WidgetTester tester,
    ) async {
      final ExerciseProgress progres = ExerciseProgress();
      for (final Exercise exercise in ExerciseCatalog.all) {
        progres.record(ExerciseAttempt(
          exerciseId: exercise.id,
          score: 100,
          tempoBpm: exercise.tempoVise,
        ));
      }
      await ouvrir(tester, progress: progres);
      expect(find.byKey(ExercisesScreen.prochaineTacheKey), findsNothing);
      expect(find.text('Tout le catalogue est acquis'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    for (final Size taille in const <Size>[Size(400, 800), Size(800, 400)]) {
      testWidgets('rien ne deborde en ${taille.width}x${taille.height}', (
        WidgetTester tester,
      ) async {
        // Les debordements de ce projet se sont tous montres en paysage, et
        // jamais sur l appareil : ils se voient ici ou nulle part.
        await ouvrir(tester, taille: taille);
        expect(tester.takeException(), isNull);
        // La feuille de tempo est le seul endroit ou la hauteur est comptee.
        await tester.tap(
          find.byKey(ExercisesScreen.tileKey(ExerciseCatalog.all.first.id)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'la feuille de tempo');
      });
    }
  });
}
