import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/ui/screens/dictation_screen.dart';

/// La dictee d'une mesure, de bout en bout : le moteur joue, le micro scripte
/// rejoue.
void main() {
  final Passage passage = () {
    final PassageBuilder b = PassageBuilder();
    for (final int m in <int>[
      62, 64, 66, 67, //
      69, 71, 73, 74,
    ]) {
      b.add(m, NoteValue.quarter);
    }
    return Passage(
      title: 'dictee',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 120,
    );
  }();

  late FakeAudioEngine moteur;
  late FakePitchSource micro;
  int t = 0;

  Future<void> poser(WidgetTester tester) async {
    t = 0;
    moteur = FakeAudioEngine()..clock = const Duration(seconds: 10);
    await tester.pumpWidget(
      MaterialApp(
        home: DictationScreen(
          passage: passage,
          engine: moteur,
          pitchSourceFactory: () async =>
              micro = FakePitchSource(const <PitchEstimate>[]),
        ),
      ),
    );
  }

  String message(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(DictationScreen.messageKey)).data!;

  /// Ecouter, puis attendre que le son soit fini et le micro ouvert.
  Future<void> ecouter(WidgetTester tester) async {
    await tester.tap(find.byKey(DictationScreen.ecouterKey));
    await tester.pump();
    await tester.pump();
    // 300 ms de marge, deux secondes de mesure, 400 ms de queue.
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump();
  }

  Future<void> jouer(WidgetTester tester, int? midi, int trames) async {
    for (int i = 0; i < trames; i++) {
      if (message(tester) != 'A toi.') {
        return;
      }
      if (midi != null) {
        micro.emit(PitchEstimate(
          frequencyHz: PitchUtils.midiToFrequency(midi),
          confidence: 1,
          timestampMs: t,
        ));
      }
      micro.emitFeature(FeatureFrame(
        timeMs: t,
        midi: midi?.toDouble(),
        rms: midi == null ? 0.001 : 0.1,
        onset: midi != null && i == 0,
      ));
      t += 23;
      await tester.pump();
    }
  }

  testWidgets('elle joue la mesure au violon, puis ecoute', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    expect(find.text('Mesure 1'), findsOneWidget);
    await tester.tap(find.byKey(DictationScreen.ecouterKey));
    await tester.pump();
    await tester.pump();
    expect(moteur.prepared, contains('violon'));
    expect(moteur.notes, hasLength(4));
    expect(moteur.notes.first.at, const Duration(milliseconds: 10300));
    expect(moteur.notes.first.instrument, 'violon');
    expect(message(tester), 'Ecoute...');
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump();
    expect(message(tester), 'A toi.');
  });

  testWidgets('rejouee juste, la mesure est entendue et la suivante vient', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await ecouter(tester);
    await jouer(tester, null, 5);
    for (final int m in <int>[62, 64, 66, 67]) {
      await jouer(tester, m, 26);
    }
    await jouer(tester, null, 80);
    await tester.pump();
    expect(message(tester), contains('C est ca'));
    expect(find.text('Mesure 2'), findsOneWidget);
    expect(find.text('1 mesure entendue'), findsOneWidget);
  });

  testWidgets('rejouee fausse, on reste sur la mesure', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await ecouter(tester);
    await jouer(tester, null, 5);
    // Les bonnes notes, mais chacune un demi-ton trop haut.
    for (final int m in <int>[63, 65, 67, 68]) {
      await jouer(tester, m, 26);
    }
    await jouer(tester, null, 160);
    await tester.pump();
    expect(message(tester), contains('Pas tout a fait'));
    expect(find.text('Mesure 1'), findsOneWidget);
    expect(find.text('0 mesure entendue'), findsOneWidget);
  });

  testWidgets('passer va a la suivante sans l entendre', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await tester.tap(find.byKey(DictationScreen.passerKey));
    await tester.pump();
    expect(find.text('Mesure 2'), findsOneWidget);
    expect(find.text('0 mesure entendue'), findsOneWidget);
  });
}
