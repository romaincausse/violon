import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/bench_score.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/score_note.dart';

Map<String, Object?> note(
  String id,
  int onset, {
  int midi = 67,
  int duree = 480,
  int mesure = 1,
  String? slur,
  bool tie = false,
}) =>
    <String, Object?>{
      'id': id,
      'midi': midi,
      'onsetTicks': onset,
      'durationTicks': duree,
      'measure': mesure,
      if (slur != null) 'slur': slur,
      if (tie) 'tie': true,
    };

Map<String, Object?> partition(List<Map<String, Object?>> notes) =>
    <String, Object?>{
      'title': 'essai',
      'ticksPerBeat': 480,
      'writtenTempoBpm': 72,
      'notes': notes,
    };

void main() {
  group('BenchScore', () {
    test('lit les champs du modele pivot', () {
      final BenchScore s = BenchScore.fromJson(
        partition(
            <Map<String, Object?>>[note('n1', 0), note('n2', 480, midi: 69)]),
      );
      expect(s.passage.noteCount, 2);
      expect(s.passage.notes[1].midi, 69);
      expect(s.passage.writtenTempoBpm, 72);
      expect(s.slurredInto, isEmpty);
    });

    test('une note de meme liaison que la precedente arrive sans attaque', () {
      final BenchScore s = BenchScore.fromJson(
        partition(<Map<String, Object?>>[
          note('n1', 0, slur: 'a'),
          note('n2', 480, slur: 'a'),
          note('n3', 960, slur: 'b'),
          note('n4', 1440),
        ]),
      );
      expect(s.slurredInto, <String>{'n2'});
    });

    test('une tenue est fondue dans la note qu elle prolonge', () {
      // Pour l'oreille, une blanche liee a une noire est une seule note.
      final BenchScore s = BenchScore.fromJson(
        partition(<Map<String, Object?>>[
          note('n1', 0, duree: 960),
          note('n2', 960, tie: true),
          note('n3', 1440, midi: 69),
        ]),
      );
      expect(
        s.passage.notes.map((ScoreNote n) => n.id),
        <String>['n1', 'n3'],
      );
      expect(s.passage.notes.first.durationTicks, 1440);
    });

    test('une partition mal formee est refusee avec l endroit de la faute', () {
      expect(
        () => BenchScore.fromJson(
          partition(<Map<String, Object?>>[
            <String, Object?>{'id': 'n1', 'midi': 'sol'},
          ]),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('note 1'),
          ),
        ),
      );
      expect(
        () => BenchScore.fromJson(
          partition(<Map<String, Object?>>[note('n1', 0, tie: true)]),
        ),
        throwsFormatException,
      );
      expect(
        () => BenchScore.fromJson(partition(<Map<String, Object?>>[])),
        throwsFormatException,
      );
    });

    test('toJson puis fromJson rend la meme partition et les memes liaisons',
        () {
      final PassageBuilder b = PassageBuilder();
      for (final int m in <int>[67, 69, 71, 72]) {
        b.add(m, NoteValue.quarter);
      }
      final Passage p = Passage(
        title: 'aller-retour',
        notes: b.notes,
        ticksPerBeat: 480,
        writtenTempoBpm: 60,
      );
      final BenchScore relu = BenchScore.fromJson(
        BenchScore.toJson(p, slurredInto: <String>{'n2', 'n3'}),
      );
      expect(relu.slurredInto, <String>{'n2', 'n3'});
      expect(
        relu.passage.notes
            .map((ScoreNote n) => '${n.id}/${n.midi}/${n.measure}'),
        p.notes.map((ScoreNote n) => '${n.id}/${n.midi}/${n.measure}'),
      );
    });
  });
}
