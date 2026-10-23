import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/score/dynamic_marks.dart';
import 'package:violon/core/score/score_layout.dart';
import 'package:violon/core/score/smufl.dart';
import 'package:violon/core/score/staff_layout.dart';

/// Les nuances gravees (K9).
void main() {
  Passage avec(List<(int, String?, String?)> notes) {
    final PassageBuilder b = PassageBuilder();
    for (final (int m, String? _, String? _) in notes) {
      b.add(m, NoteValue.quarter);
    }
    final Passage p = b.build();
    return Passage(
      title: p.title,
      ticksPerBeat: p.ticksPerBeat,
      notes: <ScoreNote>[
        for (int i = 0; i < p.notes.length; i++)
          p.notes[i].copyWith(
            dynamicMark: notes[i].$2,
            hairpin: notes[i].$3,
          ),
      ],
    );
  }

  test('sous la portee, sous une hampe descendante, et le texte qui va', () {
    final StaffLayout s = StaffLayout.of(avec(<(int, String?, String?)>[
      (67, 'mf', null), // sol4, hampe montante : sous la portee
      (71, null, 'cresc'), // si4, hampe descendante : sous la hampe
      (74, null, 'fin'),
    ]));
    final Map<int, double> y = DynamicMarks.place(s);
    expect(y.keys, <int>[0, 1]);
    expect(y[0], closeTo(2 + 0.6 + 0.9, 1e-9));
    expect(y[1]!, greaterThan(y[0]!), reason: 'la hampe descend plus bas');
    expect(DynamicMarks.textFor(s.notes[0]), 'mf');
    expect(DynamicMarks.textFor(s.notes[1]), 'cresc.');
    expect(DynamicMarks.textFor(s.notes[2]), isNull);
  });

  test('la reserve du bas du systeme couvre la nuance', () {
    final Passage p = avec(<(int, String?, String?)>[(57, 'p', null)]);
    final SystemMetrics m =
        SystemMetrics.of(ScoreLayout.of(p, maxWidthSpaces: 60));
    final double y = DynamicMarks.place(StaffLayout.of(p))[0]!;
    expect(m.bottomSpaces, greaterThan(y + DynamicMarks.heightSpaces / 2));
  });

  test('mf, pp, f s ecrivent avec les lettres de la police', () {
    expect(
        Smufl.dynamicFor('mf'), '${Smufl.dynamicMezzo}${Smufl.dynamicForte}');
    expect(
        Smufl.dynamicFor('pp'), '${Smufl.dynamicPiano}${Smufl.dynamicPiano}');
    expect(Smufl.dynamicFor('sfz'), isNull);
  });
}
