import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/dictation_drill.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/play/accompaniment_plan.dart';

void main() {
  // Trois mesures de quatre noires, a 120.
  Passage passage() {
    final PassageBuilder b = PassageBuilder();
    for (final int m in <int>[
      62, 64, 66, 67, //
      69, 71, 73, 74,
      76, 74, 73, 71,
    ]) {
      b.add(m, NoteValue.quarter);
    }
    return Passage(
      title: 'dictee',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 120,
    );
  }

  group('DictationDrill', () {
    test('la premiere mesure, ses notes au tempo, et sa duree', () {
      final DictationDrill d = DictationDrill(passage: passage());
      expect(d.measure, 1);
      expect(d.excerpt.notes.map((n) => n.midi), <int>[62, 64, 66, 67]);
      final List<TimedNote> n = d.notesToPlay;
      expect(n.map((TimedNote x) => x.at.inMilliseconds),
          <int>[0, 500, 1000, 1500]);
      expect(n.first.duration, const Duration(milliseconds: 500));
      expect(d.playingLength, const Duration(seconds: 2));
    });

    test('passer avance, et on revient au debut apres la derniere', () {
      final DictationDrill d = DictationDrill(passage: passage());
      d.skip();
      expect(d.measure, 2);
      expect(d.excerpt.notes.first.midi, 69);
      d.skip();
      d.skip();
      expect(d.measure, 1);
      expect(d.heard, 0, reason: 'passer n est pas entendre');
    });
  });
}
