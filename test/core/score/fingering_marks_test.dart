import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/score/fingering_marks.dart';
import 'package:violon/core/score/score_layout.dart';
import 'package:violon/core/score/staff_layout.dart';

/// Des noires, chacune avec son doigte ou sans.
Passage doigte(List<(int, NoteValue, String?)> notes) {
  final PassageBuilder b = PassageBuilder();
  for (final (int midi, NoteValue v, String? _) in notes) {
    b.add(midi, v);
  }
  final Passage p = b.build();
  return Passage(
    title: p.title,
    ticksPerBeat: p.ticksPerBeat,
    notes: <ScoreNote>[
      for (int i = 0; i < p.notes.length; i++)
        p.notes[i].copyWith(fingering: notes[i].$3),
    ],
  );
}

void main() {
  test('dans la portee, le chiffre se pose au-dessus de la ligne du haut', () {
    // Mi5, hampe descendante : rien ne monte au-dessus de la portee.
    final Map<int, double> y = FingeringMarks.place(StaffLayout.of(
      doigte(<(int, NoteValue, String?)>[(76, NoteValue.quarter, '2')]),
    ));
    expect(y[0], closeTo(-2 - 0.5 - 0.7, 1e-9));
  });

  test('au-dessus de la portee, il monte avec la tete', () {
    // Do6, deux lignes supplementaires.
    final StaffLayout s = StaffLayout.of(
      doigte(<(int, NoteValue, String?)>[(84, NoteValue.quarter, '4')]),
    );
    final double tete = s.notes.single.yInSpaces;
    expect(FingeringMarks.place(s)[0], closeTo(tete - 0.5 - 0.5 - 0.7, 1e-9));
  });

  test('une hampe montante passe en dessous du chiffre', () {
    // Re4, hampe montante dont la pointe depasse la ligne du haut.
    final StaffLayout s = StaffLayout.of(
      doigte(<(int, NoteValue, String?)>[(62, NoteValue.quarter, '0')]),
    );
    final double y = FingeringMarks.place(s)[0]!;
    expect(y + FingeringMarks.heightSpaces / 2, lessThan(-2 - 0.4));
  });

  test('sans doigte, rien ; et la reserve du systeme couvre le chiffre', () {
    final Passage p = doigte(<(int, NoteValue, String?)>[
      // Mi6 : le chiffre deborde la marge ordinaire du systeme.
      (88, NoteValue.quarter, '4'),
      (76, NoteValue.quarter, null),
    ]);
    final Map<int, double> y = FingeringMarks.place(StaffLayout.of(p));
    expect(y.keys, <int>[0]);
    final ScoreLayout l = ScoreLayout.of(p, maxWidthSpaces: 60);
    final SystemMetrics avec = SystemMetrics.of(l);
    final SystemMetrics sans = SystemMetrics.of(ScoreLayout.of(
      doigte(<(int, NoteValue, String?)>[
        (88, NoteValue.quarter, null),
        (76, NoteValue.quarter, null),
      ]),
      maxWidthSpaces: 60,
    ));
    expect(avec.topSpaces, lessThan(y[0]! - FingeringMarks.heightSpaces / 2));
    expect(avec.topSpaces, lessThan(sans.topSpaces));
  });
}
