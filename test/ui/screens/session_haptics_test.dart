import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/music/demo_passage.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/play/count_in.dart';
import 'package:violon/ui/screens/session_screen.dart';
import 'package:violon/ui/widgets/score_view.dart';

/// Le vibreur hors ecoute (D6).
void main() {
  final Passage demo = buildDemoPassage();

  testWidgets('le decompte se sent : une vibration par temps, pas plus', (
    WidgetTester tester,
  ) async {
    int vibrations = 0;
    late FakePitchSource micro;
    await tester.pumpWidget(
      MaterialApp(
        home: SessionScreen(
          passage: demo,
          onChangePassage: () {},
          onTune: () {},
          mode: SessionMode.metronome,
          vibrate: () => vibrations++,
          pitchSourceFactory: () async =>
              micro = FakePitchSource(const <PitchEstimate>[]),
        ),
      ),
    );
    await tester.tap(find.text('Jouer le passage'));
    await tester.pump();
    await tester.pump();
    final CountIn decompte = CountIn(
      tempoBpm: demo.pulseBpm,
      beats: demo.pulsesPerMeasure ?? 4,
    );
    // Pendant le decompte, l'archet se prepare : ce que le micro entend ne
    // doit pas etre note sur la premiere note.
    micro.emit(
      PitchEstimate(
        frequencyHz: PitchUtils.midiToFrequency(demo.notes.first.midi - 1),
        confidence: 1,
        timestampMs: 0,
      ),
    );
    for (int i = 0; i < 40; i++) {
      await tester.pump(decompte.duration ~/ 40);
    }
    expect(vibrations, decompte.beats);
    final ScoreView vue = tester.widget<ScoreView>(find.byType(ScoreView));
    expect(vue.colorOf!(demo.notes.first), isNull);
    // Une fois le passage commence, plus rien ne vibre : le micro ecoute.
    await tester.pump(const Duration(seconds: 2));
    expect(vibrations, decompte.beats);
    await tester.tap(find.text('Arreter'));
    await tester.pump();
  });

  testWidgets('en suivi, rien ne vibre jamais', (WidgetTester tester) async {
    int vibrations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SessionScreen(
          passage: demo,
          onChangePassage: () {},
          onTune: () {},
          vibrate: () => vibrations++,
          pitchSourceFactory: () async =>
              FakePitchSource(const <PitchEstimate>[]),
        ),
      ),
    );
    await tester.tap(find.text('Jouer le passage'));
    await tester.pump(const Duration(seconds: 3));
    expect(vibrations, 0);
    await tester.tap(find.text('Arreter'));
    await tester.pump();
  });
}
