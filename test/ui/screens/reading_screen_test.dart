import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/ui/screens/reading_screen.dart';
import 'package:violon/ui/widgets/score_view.dart';

void main() {
  late FakePitchSource micro;

  Future<void> poser(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingScreen(
          pitchSourceFactory: () async =>
              micro = FakePitchSource(const <PitchEstimate>[]),
          pool: const <int>[62, 64, 66, 67, 69],
          keyFifths: 2,
          duration: const Duration(seconds: 10),
        ),
      ),
    );
    await tester.pump();
  }

  int noteAffichee(WidgetTester tester) => tester
      .widget<ScoreView>(find.byType(ScoreView))
      .passage
      .notes
      .single
      .midi;

  Future<void> jouer(WidgetTester tester, int midi, int de, int a) async {
    for (int t = de; t <= a; t += 50) {
      micro.emit(PitchEstimate(
        frequencyHz: PitchUtils.midiToFrequency(midi),
        confidence: 1,
        timestampMs: t,
      ));
      await tester.pump();
    }
  }

  testWidgets('la note tenue est lue, et la suivante arrive',
      (WidgetTester tester) async {
    await poser(tester);
    final int cible = noteAffichee(tester);
    expect(find.text('0 lue'), findsOneWidget);
    await jouer(tester, cible, 0, 400);
    expect(find.text('1 lue'), findsOneWidget);
    expect(noteAffichee(tester), isNot(cible));
  });

  testWidgets('une autre note ne fait pas avancer',
      (WidgetTester tester) async {
    await poser(tester);
    final int cible = noteAffichee(tester);
    final int autre = cible == 62 ? 64 : 62;
    await jouer(tester, autre, 0, 600);
    expect(find.text('0 lue'), findsOneWidget);
    expect(noteAffichee(tester), cible);
  });

  testWidgets('au bout du temps, le bilan, et on peut recommencer',
      (WidgetTester tester) async {
    await poser(tester);
    await jouer(tester, noteAffichee(tester), 0, 400);
    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(ReadingScreen.bilanKey), findsOneWidget);
    expect(find.text('1 note lue en deux minutes.'), findsOneWidget);
    await tester.tap(find.byKey(ReadingScreen.recommencerKey));
    await tester.pump();
    expect(find.text('0 lue'), findsOneWidget);
  });
}
