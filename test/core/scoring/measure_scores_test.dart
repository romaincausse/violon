import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/live_tuning.dart';
import 'package:violon/core/scoring/measure_scores.dart';

/// Deux mesures de deux notes chacune.
Passage passageDeDeuxMesures() {
  return Passage(
    title: 'test',
    ticksPerBeat: 480,
    notes: const <ScoreNote>[
      ScoreNote(
          id: 'n1', midi: 69, onsetTicks: 0, durationTicks: 480, measure: 1),
      ScoreNote(
          id: 'n2', midi: 71, onsetTicks: 480, durationTicks: 480, measure: 1),
      ScoreNote(
          id: 'n3', midi: 72, onsetTicks: 960, durationTicks: 480, measure: 2),
      ScoreNote(
          id: 'n4', midi: 74, onsetTicks: 1440, durationTicks: 480, measure: 2),
    ],
  );
}

/// Une mesure a [cents] de la note [midi].
PitchEstimate joue(int midi, double cents) => PitchEstimate(
      frequencyHz: PitchUtils.midiToFrequency(midi + cents / 100),
      confidence: 1,
      timestampMs: 0,
    );

/// Fait entendre [note] a [cents], assez de fois pour qu'elle soit notee.
void entendre(LiveTuning t, ScoreNote note, double cents) {
  for (int i = 0; i < 3; i++) {
    t.observe(note, joue(note.midi, cents));
  }
}

void main() {
  group('scoreByMeasure', () {
    test('sans rien entendre, les mesures existent mais n ont pas de note', () {
      final Passage p = passageDeDeuxMesures();
      final List<MeasureScore> mesures = scoreByMeasure(p, LiveTuning());

      expect(mesures, hasLength(2));
      expect(mesures.map((MeasureScore m) => m.measure), <int>[1, 2]);
      expect(mesures.every((MeasureScore m) => m.score == null), isTrue);
      expect(mesures.every((MeasureScore m) => m.heard), isFalse);
    });

    test('une mesure jouee juste vaut cent', () {
      final Passage p = passageDeDeuxMesures();
      final LiveTuning t = LiveTuning();
      entendre(t, p.notes[0], 0);
      entendre(t, p.notes[1], 0);

      expect(scoreByMeasure(p, t).first.score, 100);
    });

    test('la mesure est la moyenne de ses notes', () {
      final Passage p = passageDeDeuxMesures();
      final LiveTuning t = LiveTuning();
      entendre(t, p.notes[0], 0);
      entendre(t, p.notes[1], 60);

      final MeasureScore m = scoreByMeasure(p, t).first;
      final int n1 = t.scoreFor('n1')!;
      final int n2 = t.scoreFor('n2')!;
      expect(m.score, ((n1 + n2) / 2).round());
      expect(m.score, lessThan(100));
    });

    test('une note non entendue ne compte pas pour zero', () {
      // Meme regle que pour le score d'ensemble : un archet rate ou un micro
      // trop loin ne vaut pas une fausse note.
      final Passage p = passageDeDeuxMesures();
      final LiveTuning t = LiveTuning();
      entendre(t, p.notes[0], 0);

      final MeasureScore m = scoreByMeasure(p, t).first;
      expect(m.score, 100);
      expect(m.heardNotes, 1);
      expect(m.noteCount, 2);
      expect(m.coverage, 0.5);
    });

    test('chaque mesure est jugee separement', () {
      final Passage p = passageDeDeuxMesures();
      final LiveTuning t = LiveTuning();
      entendre(t, p.notes[0], 0);
      entendre(t, p.notes[1], 0);
      entendre(t, p.notes[2], 70);
      entendre(t, p.notes[3], 70);

      final List<MeasureScore> mesures = scoreByMeasure(p, t);
      expect(mesures[0].score, 100);
      expect(mesures[1].score, lessThan(60));
    });

    test('la numerotation suit la partition, pas l index', () {
      // Un passage qui commence mesure 12 doit dire 12 et 13 : c'est ce que
      // l'enfant lit sur son papier.
      final Passage p = Passage(
        title: 'test',
        ticksPerBeat: 480,
        notes: const <ScoreNote>[
          ScoreNote(
              id: 'a',
              midi: 69,
              onsetTicks: 0,
              durationTicks: 480,
              measure: 12),
          ScoreNote(
              id: 'b',
              midi: 71,
              onsetTicks: 480,
              durationTicks: 480,
              measure: 13),
        ],
      );
      expect(
        scoreByMeasure(p, LiveTuning()).map((MeasureScore m) => m.measure),
        <int>[12, 13],
      );
    });

    test('une mesure vide au milieu du passage reste presente', () {
      // Un silence d'une mesure entiere ne doit pas faire disparaitre la
      // mesure du bandeau : le passage compte trois cases, pas deux.
      final Passage p = Passage(
        title: 'test',
        ticksPerBeat: 480,
        notes: const <ScoreNote>[
          ScoreNote(
              id: 'a', midi: 69, onsetTicks: 0, durationTicks: 480, measure: 1),
          ScoreNote(
              id: 'b',
              midi: 71,
              onsetTicks: 3840,
              durationTicks: 480,
              measure: 3),
        ],
      );
      final List<MeasureScore> mesures = scoreByMeasure(p, LiveTuning());
      expect(mesures, hasLength(3));
      expect(mesures[1].noteCount, 0);
      expect(mesures[1].coverage, 0);
    });
  });
}
