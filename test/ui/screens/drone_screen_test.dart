import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/drone.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/ui/screens/drone_screen.dart';

void main() {
  Future<FakeAudioEngine> poser(
    WidgetTester tester, {
    double a4 = 440,
    Size taille = const Size(400, 800),
  }) async {
    final FakeAudioEngine moteur = FakeAudioEngine();
    await tester.binding.setSurfaceSize(taille);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: DroneScreen(engine: moteur, a4: a4)),
    );
    return moteur;
  }

  Future<void> faireSonner(WidgetTester tester) async {
    await tester.tap(find.byKey(DroneScreen.jouerKey));
    await tester.pumpAndSettle();
  }

  group('DroneScreen', () {
    testWidgets('rien ne sonne tant qu on n a pas demande', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      expect(moteur.drones, isEmpty);
      expect(moteur.starts, 0);
      expect(find.text('Faire sonner Sol'), findsOneWidget);
    });

    testWidgets('le bourdon sonne la tonique et sa quinte', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);

      expect(moteur.sounding, hasLength(2));
      expect(moteur.drones.first.frequencyHz, closeTo(196.0, 0.01));
      // Quinte pure : le rapport 3/2 exactement, pas la quinte du piano.
      expect(
        moteur.drones[1].frequencyHz / moteur.drones.first.frequencyHz,
        closeTo(1.5, 1e-9),
      );
    });

    testWidgets('il sonne au diapason mesure', (WidgetTester tester) async {
      final FakeAudioEngine moteur = await poser(tester, a4: 442);
      await faireSonner(tester);
      expect(moteur.drones.first.frequencyHz, closeTo(196.0 * 442 / 440, 0.01));
    });

    testWidgets('changer de note ne coupe pas le son', (
      WidgetTester tester,
    ) async {
      // On cherche sa tonalite en glissant, pas en rallumant.
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      final FakeDroneVoice premiere = moteur.drones.first;

      await tester.tap(find.byKey(DroneScreen.noteKey(2)));
      await tester.pumpAndSettle();

      expect(moteur.drones, hasLength(2), reason: 'aucune voix relancee');
      expect(premiere.stopped, isFalse);
      expect(
        premiere.frequencyHz,
        closeTo(const Drone(pitchClass: 2).tonicHz, 0.01),
      );
    });

    testWidgets('retirer la quinte ne laisse qu une voix', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      await tester.tap(find.byKey(DroneScreen.quinteKey));
      await tester.pumpAndSettle();
      expect(moteur.sounding, hasLength(1));
    });

    testWidgets('le volume se propage aux voix qui sonnent', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      await tester.drag(
        find.byKey(DroneScreen.volumeKey),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      for (final FakeDroneVoice voix in moteur.sounding) {
        expect(voix.volume, lessThan(0.3));
      }
    });

    testWidgets('arreter coupe tout', (WidgetTester tester) async {
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      await tester.tap(find.byKey(DroneScreen.jouerKey));
      await tester.pumpAndSettle();
      expect(moteur.sounding, isEmpty);
    });

    testWidgets('quitter l ecran coupe le son', (WidgetTester tester) async {
      // Un bourdon qui continue derriere la seance serait le pire bogue
      // possible : l'application emettrait pendant qu'elle note (ADR-008).
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      expect(moteur.sounding, isNotEmpty);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(moteur.sounding, isEmpty);
    });

    testWidgets('rien ne deborde en paysage', (WidgetTester tester) async {
      await poser(tester, taille: const Size(800, 400));
      expect(tester.takeException(), isNull);
    });
  });
}
