import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/exercises/work_loop.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/ui/screens/loop_screen.dart';

/// La boucle de travail (jalon 8), de bout en bout avec un micro scripte.
void main() {
  // Trois mesures de quatre noires.
  final Passage passage = () {
    final PassageBuilder b = PassageBuilder();
    for (final int m in <int>[
      62, 64, 66, 67, //
      69, 71, 73, 74,
      76, 74, 73, 71,
    ]) {
      b.add(m, NoteValue.quarter);
    }
    return Passage(
      title: 'boucle',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 120,
    );
  }();

  late FakePitchSource micro;
  int t = 0;

  Future<void> poser(WidgetTester tester) async {
    t = 0;
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: LoopScreen(
          passage: passage,
          selection: const BarSelection(2, 2),
          startPulseBpm: 100,
          pitchSourceFactory: () async =>
              micro = FakePitchSource(const <PitchEstimate>[]),
        ),
      ),
    );
  }

  Future<void> commencer(WidgetTester tester) async {
    await tester.tap(find.byKey(LoopScreen.commencerKey));
    await tester.pump();
    await tester.pump();
  }

  Future<void> jouer(WidgetTester tester, int? midi, int trames) async {
    for (int i = 0; i < trames; i++) {
      // La boucle a pu se fermer seule, sur une reussite : micro ferme.
      if (find.byKey(LoopScreen.finirKey).evaluate().isEmpty) {
        return;
      }
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

  /// La mesure 2, a 100 a la noire (26 trames de 23 ms), puis l'archet pose.
  Future<void> mesure2(WidgetTester tester) async {
    for (final int m in <int>[69, 71, 73, 74]) {
      await jouer(tester, m, 26);
    }
    await jouer(tester, null, 80);
  }

  String message(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(LoopScreen.messageKey)).data!;

  testWidgets('deux essais reussis, et le tempo monte d un cran', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await commencer(tester);
    expect(find.text('Vise 100 (noire)'), findsOneWidget);
    await jouer(tester, null, 5);
    await mesure2(tester);
    expect(message(tester), contains('Encore une fois pour monter'));
    expect(find.textContaining('Reussis : 1'), findsOneWidget);
    await mesure2(tester);
    expect(message(tester), contains('Un cran plus vite'));
    expect(find.text('Vise 106 (noire)'), findsOneWidget);
    expect(find.textContaining('Reussis : 2'), findsOneWidget);
    await tester.tap(find.byKey(LoopScreen.finirKey));
    await tester.pump();
  });

  testWidgets('apres un essai rate, on termine sur une reussite', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await commencer(tester);
    await jouer(tester, null, 5);
    // Il s'arrete au milieu, et ne reprend pas.
    await jouer(tester, 69, 26);
    await jouer(tester, 71, 26);
    await jouer(tester, null, 160);
    expect(message(tester), contains('jusqu au bout'));
    await tester.tap(find.byKey(LoopScreen.finirKey));
    await tester.pump();
    expect(message(tester), contains('Une derniere fois'));
    // La derniere fois reussie ferme la boucle.
    await mesure2(tester);
    expect(find.byKey(LoopScreen.commencerKey), findsOneWidget);
    expect(message(tester), contains('reussite'));
  });

  testWidgets('les mesures se choisissent avant de commencer', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    expect(find.byKey(LoopScreen.selectionKey), findsOneWidget);
    // Le point de rupture est un outil d'adulte : pas sur son chemin (V0).
    expect(find.byKey(LoopScreen.ruptureKey), findsNothing);
    await commencer(tester);
    expect(find.byKey(LoopScreen.selectionKey), findsNothing);
    await tester.tap(find.byKey(LoopScreen.finirKey));
    await tester.pump();
  });
}
