import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/score/staff_layout.dart';
import 'package:violon/core/score/stems_and_beams.dart';

void main() {
  StemsAndBeams poser(
    List<(int, NoteValue)> notes, {
    int beatsPerMeasure = 4,
  }) {
    final PassageBuilder b = PassageBuilder(beatsPerMeasure: beatsPerMeasure);
    for (final (int midi, NoteValue value) in notes) {
      b.add(midi, value);
    }
    return StemsAndBeams.of(StaffLayout.of(b.build()));
  }

  group('Sens des hampes', () {
    test('sous la ligne du milieu, la hampe monte', () {
      // Sol4 est au pas -2.
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.quarter),
      ]);
      expect(s.stems.single.direction, StemDirection.up);
    });

    test('au-dessus de la ligne du milieu, la hampe descend', () {
      // Mi5 est au pas +3.
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (76, NoteValue.quarter),
      ]);
      expect(s.stems.single.direction, StemDirection.down);
    });

    test('sur la ligne du milieu, la hampe descend par convention', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (71, NoteValue.quarter),
      ]);
      expect(s.stems.single.direction, StemDirection.down);
    });

    test('la hampe s attache au bord de la tete, pas a son centre', () {
      final StemsAndBeams monte = poser(<(int, NoteValue)>[
        (67, NoteValue.quarter),
      ]);
      final StemsAndBeams descend = poser(<(int, NoteValue)>[
        (76, NoteValue.quarter),
      ]);
      final StaffLayout l = StaffLayout.of(
        (PassageBuilder()..add(67, NoteValue.quarter)).build(),
      );
      final double centre = l.notes.single.xSpaces;

      expect(monte.stems.single.xSpaces, greaterThan(centre),
          reason: 'a droite');
      expect(descend.stems.single.xSpaces, lessThan(centre),
          reason: 'a gauche');
    });

    test('un groupe ligature partage un seul sens', () {
      // Sol4 (pas -2) et mi5 (pas +3) dans le meme temps : c'est le mi5, plus
      // eloigne de la ligne du milieu, qui impose la hampe descendante.
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.eighth),
        (76, NoteValue.eighth),
      ]);
      expect(s.beams, hasLength(1));
      expect(
        s.stems.map((Stem st) => st.direction),
        everyElement(StemDirection.down),
      );
    });
  });

  group('Longueur des hampes', () {
    test('une hampe normale fait 3,5 espaces', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.quarter),
      ]);
      expect(s.stems.single.lengthSpaces, closeTo(3.5, 1e-9));
    });

    test('une note loin hors portee allonge sa hampe jusqu au milieu', () {
      // Sol3 est au pas -9, soit 4,5 espaces sous la ligne du milieu : une
      // hampe de 3,5 la laisserait flotter sous la portee.
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (55, NoteValue.quarter),
      ]);
      expect(s.stems.single.tipYSpaces, 0,
          reason: 'atteint la ligne du milieu');
      expect(s.stems.single.lengthSpaces, greaterThan(3.5));
    });
  });

  group('Crochets et ligatures', () {
    test('une ronde n a pas de hampe du tout', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[(67, NoteValue.whole)]);
      expect(s.stems, isEmpty);
    });

    test('une noire isolee a une hampe sans crochet', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.quarter),
      ]);
      expect(s.stems.single.flagCount, 0);
    });

    test('une croche seule dans son temps porte un crochet', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.eighth),
        (67, NoteValue.eighth),
      ], beatsPerMeasure: 4);
      // Ces deux croches tombent dans le meme temps : elles se ligaturent.
      expect(s.beams, hasLength(1));
      expect(s.stems.map((Stem st) => st.flagCount), everyElement(0));
    });

    test('une croche suivie d une noire garde son crochet', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.eighth),
        (69, NoteValue.eighth),
        (71, NoteValue.quarter),
      ]);
      expect(s.beams, hasLength(1), reason: 'les deux croches du 1er temps');
      expect(s.stems.last.flagCount, 0, reason: 'la noire n a pas de crochet');
    });

    test('les doubles portent deux ligatures', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.sixteenth),
        (69, NoteValue.sixteenth),
        (71, NoteValue.sixteenth),
        (72, NoteValue.sixteenth),
      ]);
      expect(s.beams, hasLength(1), reason: 'quatre doubles = un temps');
      expect(s.beams.single.beamCount, 2);
    });

    test('une croche pointee reste une croche', () {
      // 0,75 temps : elle ne doit pas basculer du cote des noires.
      final PassageBuilder b = PassageBuilder();
      b.add(67, NoteValue.eighth, dotted: true);
      b.add(69, NoteValue.sixteenth);
      final StemsAndBeams s = StemsAndBeams.of(StaffLayout.of(b.build()));

      expect(s.beams, hasLength(1), reason: 'le rythme pointe se ligature');
      expect(s.beams.single.beamCount, 2,
          reason: 'la double impose deux barres');
    });
  });

  group('Groupement par temps', () {
    test('la ligature ne franchit pas la limite de temps', () {
      // Quatre croches = deux temps = deux ligatures, pas une seule.
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.eighth),
        (69, NoteValue.eighth),
        (71, NoteValue.eighth),
        (72, NoteValue.eighth),
      ]);
      expect(s.beams, hasLength(2));
      expect(s.beams[0].noteIndices, <int>[0, 1]);
      expect(s.beams[1].noteIndices, <int>[2, 3]);
    });

    test('la ligature ne franchit pas la barre de mesure', () {
      // Deux temps par mesure : les croches 3 et 4 sont dans la mesure 2.
      final StemsAndBeams s = poser(
        <(int, NoteValue)>[
          (67, NoteValue.eighth),
          (69, NoteValue.eighth),
          (71, NoteValue.eighth),
          (72, NoteValue.eighth),
        ],
        beatsPerMeasure: 1,
      );
      expect(s.beams, hasLength(2));
      for (final Beam b in s.beams) {
        expect(b.noteIndices, hasLength(2));
      }
    });

    test('une croche seule dans son temps ne fait pas de ligature', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.quarter),
        (69, NoteValue.eighth),
        (71, NoteValue.quarter),
      ]);
      expect(s.beams, isEmpty);
      expect(
        s.stems[1].flagCount,
        1,
        reason: 'faute de voisine, elle porte un crochet',
      );
    });
  });

  group('Forme des tetes', () {
    const int parNoire = 480;

    test('la ronde et la blanche sont evidees, le reste est plein', () {
      expect(StemsAndBeams.headFor(1920, parNoire), NoteHead.whole);
      expect(StemsAndBeams.headFor(960, parNoire), NoteHead.half);
      expect(StemsAndBeams.headFor(480, parNoire), NoteHead.filled);
      expect(StemsAndBeams.headFor(240, parNoire), NoteHead.filled);
    });

    test('une blanche pointee reste une blanche', () {
      // 3 temps : elle ne doit pas passer pour une ronde.
      expect(StemsAndBeams.headFor(1440, parNoire), NoteHead.half);
    });

    test('le nombre de crochets suit la figure', () {
      expect(StemsAndBeams.flagsFor(1920, parNoire), -1, reason: 'ronde');
      expect(StemsAndBeams.flagsFor(480, parNoire), 0, reason: 'noire');
      expect(StemsAndBeams.flagsFor(240, parNoire), 1, reason: 'croche');
      expect(StemsAndBeams.flagsFor(120, parNoire), 2, reason: 'double');
    });
  });

  group('Position de la ligature', () {
    test('elle se pose a l extremite la plus lointaine du groupe', () {
      // Hampes montantes : la ligature prend le tip le plus haut, donc le
      // plus petit y. Aucune hampe ne peut ainsi etre trop courte.
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (60, NoteValue.eighth), // do4, grave
        (67, NoteValue.eighth), // sol4, plus aigu
      ]);
      final Beam b = s.beams.single;
      expect(b.direction, StemDirection.up);
      final double plusHaut = s.stems
          .map((Stem st) => st.tipYSpaces)
          .reduce((double a, double c) => a < c ? a : c);
      expect(b.ySpaces, plusHaut);
    });

    test('elle relie la premiere et la derniere hampe du groupe', () {
      final StemsAndBeams s = poser(<(int, NoteValue)>[
        (67, NoteValue.eighth),
        (69, NoteValue.eighth),
      ]);
      final Beam b = s.beams.single;
      expect(b.startXSpaces, s.stems.first.xSpaces);
      expect(b.endXSpaces, s.stems.last.xSpaces);
      expect(b.endXSpaces, greaterThan(b.startXSpaces));
    });
  });
}
