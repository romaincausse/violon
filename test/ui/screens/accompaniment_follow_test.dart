import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/play/accompaniment.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/core/play/headphones.dart';
import 'package:violon/ui/screens/accompaniment_screen.dart';

/// L'accompagnement qui suit (J5, ADR-016).
void main() {
  // re mi fa# sol la, noires.
  final Passage passage = () {
    final PassageBuilder b = PassageBuilder();
    for (final int m in <int>[62, 64, 66, 67, 69]) {
      b.add(m, NoteValue.quarter);
    }
    return Passage(
      title: 'suivi',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 80,
    );
  }();

  // Une basse par croche, ecrite dans le fichier.
  final List<AccompanimentNote> basse = <AccompanimentNote>[
    for (int t = 0; t < 5 * 480; t += 240)
      AccompanimentNote(midi: 50, onsetTicks: t, durationTicks: 240),
  ];

  late FakePitchSource micro;
  int t = 0;

  Future<FakeAudioEngine> poser(
    WidgetTester tester,
    Headphones casque, {
    int? latence = 40,
  }) async {
    t = 0;
    final FakeAudioEngine moteur = FakeAudioEngine()
      ..clock = const Duration(seconds: 10);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AccompanimentScreen(
          passage: passage,
          engine: moteur,
          scoreAccompaniment: basse,
          pitchSourceFactory: () async =>
              micro = FakePitchSource(const <PitchEstimate>[]),
          headphones: FakeHeadphoneProbe(casque),
          latencyMs: latence,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return moteur;
  }

  Future<void> jouer(WidgetTester tester, int? midi, int trames) async {
    for (int i = 0; i < trames; i++) {
      if (midi != null) {
        micro.emit(
          PitchEstimate(
            frequencyHz: PitchUtils.midiToFrequency(midi),
            confidence: 1,
            timestampMs: t,
          ),
        );
      }
      micro.emitFeature(
        FeatureFrame(
          timeMs: t,
          midi: midi?.toDouble(),
          rms: midi == null ? 0.001 : 0.1,
          onset: midi != null && i == 0,
        ),
      );
      t += 23;
      await tester.pump();
    }
  }

  SwitchListTile interrupteur(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byKey(AccompanimentScreen.suitKey));

  testWidgets('sans casque, elle ne peut pas suivre, et dit pourquoi', (
    WidgetTester tester,
  ) async {
    await poser(tester, Headphones.none);
    expect(interrupteur(tester).onChanged, isNull);
    expect(find.textContaining('Branche un casque filaire'), findsOneWidget);
  });

  testWidgets('au casque Bluetooth non plus : son retard ne se mesure pas', (
    WidgetTester tester,
  ) async {
    await poser(tester, Headphones.bluetooth);
    expect(interrupteur(tester).onChanged, isNull);
    expect(find.textContaining('Bluetooth'), findsOneWidget);
  });

  testWidgets('sans latence mesuree, il faut d abord la mesurer', (
    WidgetTester tester,
  ) async {
    await poser(tester, Headphones.wired, latence: null);
    expect(interrupteur(tester).onChanged, isNull);
    expect(find.textContaining('latence'), findsOneWidget);
  });

  testWidgets('au casque filaire, elle pose la suite a chaque attaque', (
    WidgetTester tester,
  ) async {
    final FakeAudioEngine moteur = await poser(tester, Headphones.wired);
    await tester.tap(find.byKey(AccompanimentScreen.suitKey));
    await tester.pumpAndSettle();
    expect(interrupteur(tester).value, isTrue);
    await tester.tap(find.byKey(AccompanimentScreen.jouerKey));
    await tester.pump();
    await tester.pump();
    // Tant qu'il ne joue pas, elle ne joue rien.
    await jouer(tester, null, 10);
    expect(moteur.notes, isEmpty);
    await jouer(tester, 62, 20);
    await jouer(tester, 64, 20);
    await jouer(tester, 66, 20);
    expect(moteur.notes, isNotEmpty);
    // Elle ne pose qu'un temps d'avance : pas tout le morceau d'un coup.
    expect(moteur.notes.length, lessThan(basse.length));
    // Et rien n'est pose avant l'horloge du moteur.
    for (final FakeNote n in moteur.notes) {
      expect(n.at, greaterThanOrEqualTo(moteur.clock));
    }
    await tester.tap(find.byKey(AccompanimentScreen.jouerKey));
    await tester.pump();
  });
}
