import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/play/drone.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/core/play/metronome_clock.dart';
import 'package:violon/ui/screens/training_screen.dart';

void main() {
  final Exercise gamme = ExerciseCatalog.byId('gamme-sol-majeur-2')!;
  final Exercise motif = ExerciseCatalog.byId('motif-en-ligne-2-3')!;

  Future<FakeAudioEngine> poser(
    WidgetTester tester, {
    Exercise? exercise,
    double a4 = 440,
    Size taille = const Size(400, 800),
  }) async {
    final FakeAudioEngine moteur = FakeAudioEngine();
    await tester.binding.setSurfaceSize(taille);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingScreen(
          exercise: exercise ?? gamme,
          tempoBpm: 72,
          engine: moteur,
          a4: a4,
        ),
      ),
    );
    return moteur;
  }

  group('TrainingScreen', () {
    testWidgets('rien ne sonne a l ouverture', (WidgetTester tester) async {
      final FakeAudioEngine moteur = await poser(tester);
      expect(moteur.drones, isEmpty);
      expect(moteur.clicks, isEmpty);
      expect(moteur.starts, 0);
    });

    testWidgets('le bourdon se pose sur la tonique de la gamme', (
      WidgetTester tester,
    ) async {
      // C'est tout l'interet du lien : la gamme de sol majeur appelle un
      // bourdon de sol, sans que l'enfant ait a le choisir.
      final FakeAudioEngine moteur = await poser(tester);
      expect(find.text('Bourdon sur Sol'), findsOneWidget);

      await tester.tap(find.byKey(TrainingScreen.bourdonKey));
      await tester.pumpAndSettle();

      expect(moteur.sounding, hasLength(2), reason: 'la tonique et sa quinte');
      expect(
        moteur.drones.first.frequencyHz,
        closeTo(const Drone(pitchClass: Drone.sol).tonicHz, 0.01),
      );
    });

    testWidgets('le bourdon suit le diapason mesure', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester, a4: 442);
      await tester.tap(find.byKey(TrainingScreen.bourdonKey));
      await tester.pumpAndSettle();
      expect(
        moteur.drones.first.frequencyHz,
        closeTo(const Drone(pitchClass: Drone.sol).tonicHz * 442 / 440, 0.01),
      );
    });

    testWidgets('un motif de doigts n a pas de bourdon, et ca se dit', (
      WidgetTester tester,
    ) async {
      // Le motif traverse les quatre cordes : aucune note tenue ne lui sert de
      // reference. Mieux vaut ne pas le proposer que d'en proposer un faux.
      final FakeAudioEngine moteur = await poser(tester, exercise: motif);
      expect(
        find.text('Pas de tonique : le motif traverse les quatre cordes'),
        findsOneWidget,
      );
      final SwitchListTile interrupteur = tester.widget<SwitchListTile>(
        find.byKey(TrainingScreen.bourdonKey),
      );
      expect(interrupteur.onChanged, isNull);
      expect(moteur.drones, isEmpty);
    });

    testWidgets('le metronome sonne au tempo de l exercice', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      expect(find.text('Metronome a 72'), findsOneWidget);

      await tester.tap(find.byKey(TrainingScreen.metronomeKey));
      await tester.pump();
      await tester.pump();

      expect(moteur.clicks, isNotEmpty);
      expect(moteur.clicks.first.accent, PulseAccent.downbeat);
      expect(moteur.clicks.first.delay, Duration.zero);
    });

    testWidgets('le bourdon survit a l arret du metronome', (
      WidgetTester tester,
    ) async {
      // Couper les clics deja planifies coupe tout ce qui sonne : il faut donc
      // relancer le bourdon, sinon il disparait avec eux.
      final FakeAudioEngine moteur = await poser(tester);
      await tester.tap(find.byKey(TrainingScreen.bourdonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TrainingScreen.metronomeKey));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(TrainingScreen.metronomeKey));
      await tester.pump();
      await tester.pump();

      expect(moteur.sounding, hasLength(2), reason: 'le bourdon sonne encore');
    });

    testWidgets('quitter l ecran coupe tout', (WidgetTester tester) async {
      final FakeAudioEngine moteur = await poser(tester);
      await tester.tap(find.byKey(TrainingScreen.bourdonKey));
      await tester.pumpAndSettle();
      expect(moteur.sounding, isNotEmpty);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      expect(moteur.sounding, isEmpty);
    });

    testWidgets('rien ne deborde en paysage', (WidgetTester tester) async {
      await poser(tester, taille: const Size(800, 400));
      expect(tester.takeException(), isNull);
    });
  });
}
