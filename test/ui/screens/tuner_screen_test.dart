import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/microphone_pitch_source.dart';
import 'package:violon/core/audio/pitch_source.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/tuner.dart';
import 'package:violon/ui/screens/tuner_screen.dart';
import 'package:violon/ui/widgets/tuner_gauge.dart';

import '../../core/audio/fake_capture.dart';

void main() {
  /// Un signal PCM d'une hauteur donnee, assez long pour plusieurs trames.
  Uint8ListBuilder sinus(double frequenceHz, int trames) =>
      Uint8ListBuilder(frequenceHz, trames);

  Future<FakeCapture> poser(
    WidgetTester tester, {
    double a4 = 440,
    ValueChanged<double>? onA4Changed,
  }) async {
    final FakeCapture micro = FakeCapture();
    await tester.pumpWidget(
      MaterialApp(
        home: TunerScreen(
          pitchSourceFactory: () async =>
              MicrophonePitchSource(micro) as PitchSource,
          a4: a4,
          onA4Changed: onA4Changed ?? (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return micro;
  }

  Future<void> jouer(
    WidgetTester tester,
    FakeCapture micro,
    double frequenceHz, {
    int trames = 6,
  }) async {
    micro.controleur.add(sinus(frequenceHz, trames).build());
    await tester.pump();
    await tester.pump();
  }

  group('TunerScreen', () {
    testWidgets('sans son, il invite a jouer une corde', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      expect(find.text('Joue une corde a vide'), findsOneWidget);
      expect(find.byType(TunerGauge), findsOneWidget);
    });

    testWidgets('les quatre cordes sont proposees', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      for (final String nom in <String>['Sol', 'Re', 'La', 'Mi']) {
        expect(find.text(nom), findsOneWidget);
      }
    });

    testWidgets('un la juste est annonce juste', (WidgetTester tester) async {
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 440);

      expect(find.text('La4'), findsOneWidget);
      expect(find.text('juste'), findsOneWidget);
    });

    testWidgets('une corde basse annonce son ecart en cents', (
      WidgetTester tester,
    ) async {
      // 435 Hz, soit une vingtaine de cents sous le la.
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 435);

      expect(find.text('La4'), findsOneWidget);
      expect(find.textContaining('cents'), findsOneWidget);
      final String texte =
          tester.widget<Text>(find.byKey(const Key('tuner-cents'))).data!;
      expect(texte.startsWith('-'), isTrue, reason: 'trop bas : $texte');
    });

    testWidgets('une corde haute le dit aussi', (WidgetTester tester) async {
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 446);

      final String texte =
          tester.widget<Text>(find.byKey(const Key('tuner-cents'))).data!;
      expect(texte.startsWith('+'), isTrue, reason: 'trop haut : $texte');
    });

    testWidgets('le diapason de reference est affiche', (
      WidgetTester tester,
    ) async {
      await poser(tester, a4: 442);
      expect(find.text('Diapason 442 Hz'), findsOneWidget);
    });

    testWidgets('un la a 442 est juste quand la reference est 442', (
      WidgetTester tester,
    ) async {
      // La regle de justesse relative : juger contre l'accord reel de
      // l'instrument, pas contre un chiffre.
      final FakeCapture micro = await poser(tester, a4: 442);
      await jouer(tester, micro, 442);
      expect(find.text('juste'), findsOneWidget);
    });

    testWidgets('on peut adopter le diapason mesure', (
      WidgetTester tester,
    ) async {
      double? adopte;
      final FakeCapture micro = await poser(
        tester,
        onA4Changed: (double v) => adopte = v,
      );
      await jouer(tester, micro, 442);

      final Finder bouton = find.textContaining('Adopter');
      expect(bouton, findsOneWidget);
      await tester.tap(bouton);
      await tester.pump();

      expect(adopte, closeTo(442, 1.5));
    });

    testWidgets('un micro refuse le dit clairement', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TunerScreen(
            pitchSourceFactory: () async => throw const MicPermissionDenied(),
            a4: 440,
            onA4Changed: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Micro refuse'), findsOneWidget);
    });

    testWidgets('quitter l ecran libere le micro', (
      WidgetTester tester,
    ) async {
      final FakeCapture micro = await poser(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // La liberation est asynchrone : on laisse l'horloge avancer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(micro.liberations, 1);
    });
  });

  group('TunerGauge', () {
    testWidgets('sans lecture, aucune aiguille n est peinte', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TunerGauge(reading: null))),
      );
      expect(find.byKey(const Key('tuner-gauge')), findsOneWidget);
    });

    testWidgets('l aiguille se colle au bord au-dela de l etendue', (
      WidgetTester tester,
    ) async {
      // Une corde tres fausse ne doit pas dessiner hors de l'ecran.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TunerGauge(
              reading: TunerReading(
                frequencyHz: PitchUtils.midiToFrequency(69),
                stringMidi: 69,
                centsOffset: -240,
                inTune: false,
                steady: true,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Fabrique un signal PCM 16 bits d'une sinusoide.
class Uint8ListBuilder {
  Uint8ListBuilder(this.frequenceHz, this.trames);

  final double frequenceHz;
  final int trames;

  Uint8List build() {
    const int sampleRate = 44100;
    final int n = 2048 * trames;
    final Uint8List bytes = Uint8List(n * 2);
    final ByteData vue = ByteData.view(bytes.buffer);
    for (int i = 0; i < n; i++) {
      final double v = math.sin(2 * math.pi * frequenceHz * i / sampleRate);
      vue.setInt16(i * 2, (v * 30000).round(), Endian.little);
    }
    return bytes;
  }
}
