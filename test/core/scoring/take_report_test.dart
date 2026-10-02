import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/live_tuning.dart';
import 'package:violon/core/scoring/rhythm_judge.dart';
import 'package:violon/core/scoring/take_report.dart';

void main() {
  // Quatre mesures de quatre noires.
  final Passage p = () {
    final PassageBuilder b = PassageBuilder();
    for (int i = 0; i < 16; i++) {
      b.add(60 + i, NoteValue.quarter);
    }
    return Passage(
      title: 't',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 100,
    );
  }();

  /// Joue les notes [de] a [a] incluses, chacune pendant [ms], a partir de
  /// [depart]. Rend l'instant de fin.
  int jouer(List<PlayedEvent> e, int de, int a, int depart,
      {int ms = 600, Map<int, int> durees = const <int, int>{}}) {
    int t = depart;
    for (int i = de; i <= a; i++) {
      final int d = durees[i] ?? ms;
      e.add(PlayedEvent(noteIndex: i, startMs: t, endMs: t + d));
      t += d;
    }
    return t;
  }

  /// Une justesse parfaite sur toutes les notes jouees.
  LiveTuning juste() {
    final LiveTuning t = LiveTuning();
    for (final ScoreNote n in p.notes) {
      for (int k = 0; k < 3; k++) {
        t.observe(
          n,
          PitchEstimate(
            frequencyHz: PitchUtils.midiToFrequency(n.midi),
            confidence: 1,
            timestampMs: 0,
          ),
        );
      }
    }
    return t;
  }

  TakeReport rapport(List<PlayedEvent> e) =>
      TakeReport.of(p, RhythmJudge.fromEvents(p, e), juste());

  test('joue d un trait, juste et en place : aucune tache', () {
    final List<PlayedEvent> e = <PlayedEvent>[];
    jouer(e, 0, 15, 0);
    final TakeReport r = rapport(e);
    expect(r.nextTask, isNull);
    expect(r.measures.every((MeasureReport m) => m.heard), isTrue);
    expect(r.byMeasure(2)!.rhythmScore, 100);
  });

  test('une mesure reprise et arretee est la tache, pour ces raisons', () {
    final List<PlayedEvent> e = <PlayedEvent>[];
    int t = jouer(e, 0, 9, 0);
    // Il s'arrete au debut de la mesure 3, et la reprend trois fois.
    for (int k = 0; k < 3; k++) {
      t = jouer(e, 8, 10, t + 1500);
    }
    jouer(e, 11, 15, t);
    final TakeReport r = rapport(e);
    final MeasureReport m3 = r.byMeasure(3)!;
    expect(m3.restarts, 3);
    expect(m3.stops, 3);
    expect(r.nextTask!.measure, 3);
    expect(r.nextTask!.mainWeakness, Weakness.stops);
  });

  test('une note sautee ou ecourtee est vue', () {
    final List<PlayedEvent> e = <PlayedEvent>[];
    int t = jouer(e, 0, 5, 0);
    // Il saute la note 6, enchaine, et ecourte la 10.
    t = jouer(e, 7, 15, t, durees: <int, int>{10: 150});
    final TakeReport r = rapport(e);
    expect(r.byMeasure(2)!.avoided, contains(6));
    expect(r.byMeasure(3)!.avoided, contains(10));
  });

  test('il ralentit dans la mesure difficile, sans s en rendre compte', () {
    final List<PlayedEvent> e = <PlayedEvent>[];
    // A 100, sauf la mesure 3 jouee 30 % plus lentement.
    jouer(e, 0, 15, 0, durees: <int, int>{8: 780, 9: 780, 10: 780, 11: 780});
    final TakeReport r = rapport(e);
    expect(r.byMeasure(3)!.tempoRatio, closeTo(600 / 780, 0.02));
    expect(r.byMeasure(1)!.tempoRatio, closeTo(1, 0.02));
    expect(r.nextTask!.measure, 3);
    expect(r.nextTask!.mainWeakness, Weakness.slowing);
  });

  test('ce qui n a pas ete joue n est pas une tache', () {
    final List<PlayedEvent> e = <PlayedEvent>[];
    jouer(e, 0, 7, 0);
    final TakeReport r = rapport(e);
    expect(r.byMeasure(4)!.heard, isFalse);
    expect(r.nextTask, isNull);
  });
}
