import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/score/staff_geometry.dart';
import 'package:violon/core/score/staff_layout.dart';

void main() {
  /// Quatre noires dans une mesure a quatre temps, puis une cinquieme qui
  /// ouvre la mesure suivante.
  Passage cinqNoires() {
    final PassageBuilder b = PassageBuilder(
      beatsPerMeasure: 4,
      firstMeasure: 12,
    );
    for (int i = 0; i < 5; i++) {
      b.add(67, NoteValue.quarter);
    }
    return b.build();
  }

  group('StaffLayout', () {
    test('l abscisse est proportionnelle au temps', () {
      final PassageBuilder b = PassageBuilder();
      b.add(67, NoteValue.quarter); // 1 temps
      b.add(69, NoteValue.eighth); // un demi-temps
      b.add(71, NoteValue.eighth);
      final StaffLayout l = StaffLayout.of(b.build(), spacesPerBeat: 6);

      final List<double> x = l.notes.map((PlacedNote p) => p.xSpaces).toList();
      expect(x[1] - x[0], closeTo(6, 1e-9), reason: 'une noire = 6 espaces');
      expect(x[2] - x[1], closeTo(3, 1e-9), reason: 'une croche = 3 espaces');
    });

    test('la premiere note laisse la place de la cle', () {
      final StaffLayout l = StaffLayout.of(cinqNoires(), leadingSpaces: 9);
      expect(l.notes.first.xSpaces, 9);
    });

    test('un changement de mesure pose une barre', () {
      final StaffLayout l = StaffLayout.of(cinqNoires());
      // Une barre entre les mesures 12 et 13, plus la barre finale.
      expect(l.barlineXSpaces.length, 2);
    });

    test('la barre tombe entre la derniere note et le temps fort suivant', () {
      final StaffLayout l = StaffLayout.of(cinqNoires());
      final double avant = l.notes[3].xSpaces; // 4e temps de la mesure 12
      final double apres = l.notes[4].xSpaces; // 1er temps de la mesure 13
      final double barre = l.barlineXSpaces.first;

      expect(barre, greaterThan(avant));
      expect(barre, lessThan(apres));
    });

    test('la barre ouvre un espace supplementaire, elle ne chevauche pas', () {
      const double gap = 2.5;
      final StaffLayout l = StaffLayout.of(
        cinqNoires(),
        spacesPerBeat: 6,
        barlineGapSpaces: gap,
      );
      // Sans barre, la 5e note serait a 6 espaces de la 4e comme les autres.
      expect(l.notes[4].xSpaces - l.notes[3].xSpaces, closeTo(6 + gap, 1e-9));
      expect(l.notes[1].xSpaces - l.notes[0].xSpaces, closeTo(6, 1e-9));
    });

    test('un passage d une seule mesure n a que la barre finale', () {
      final PassageBuilder b = PassageBuilder(beatsPerMeasure: 4);
      for (int i = 0; i < 4; i++) {
        b.add(67, NoteValue.quarter);
      }
      final StaffLayout l = StaffLayout.of(b.build());
      expect(l.barlineXSpaces.length, 1);
      expect(l.barlineXSpaces.single, lessThanOrEqualTo(l.widthSpaces));
    });

    test('la largeur couvre la duree de la derniere note', () {
      final PassageBuilder b = PassageBuilder();
      b.add(67, NoteValue.whole); // 4 temps
      final StaffLayout l = StaffLayout.of(
        b.build(),
        spacesPerBeat: 6,
        leadingSpaces: 9,
        trailingSpaces: 3,
      );
      // 9 de cle + 4 temps a 6 espaces + 3 de marge.
      expect(l.widthSpaces, closeTo(9 + 24 + 3, 1e-9));
    });

    test('chaque note recoit son pas, son alteration et ses lignes', () {
      final PassageBuilder b = PassageBuilder();
      b.add(55, NoteValue.quarter); // sol3, sous la portee
      b.add(66, NoteValue.quarter); // fa#4
      final StaffLayout l = StaffLayout.of(b.build());

      expect(l.notes[0].step, -9);
      expect(l.notes[0].ledgerSteps, <int>[-6, -8]);
      expect(l.notes[0].accidental, Accidental.none);

      expect(l.notes[1].step, StaffGeometry.stepOf(65), reason: 'pose sur fa');
      expect(l.notes[1].accidental, Accidental.sharp);
      expect(l.notes[1].ledgerSteps, isEmpty);
    });

    test('les bornes tiennent compte des notes hors portee', () {
      final PassageBuilder b = PassageBuilder();
      b.add(55, NoteValue.quarter); // sol3
      b.add(83, NoteValue.quarter); // si5
      final StaffLayout l = StaffLayout.of(b.build());

      expect(l.lowestStep, -9);
      expect(l.highestStep, StaffGeometry.stepOf(83));
      expect(l.lowestStep, lessThan(StaffGeometry.bottomLineStep));
      expect(l.highestStep, greaterThan(StaffGeometry.topLineStep));
    });

    test('les bornes ne se resserrent jamais en deca de la portee', () {
      final StaffLayout l = StaffLayout.of(cinqNoires()); // que des sol4
      expect(l.lowestStep, StaffGeometry.bottomLineStep);
      expect(l.highestStep, StaffGeometry.topLineStep);
    });

    test('la mise en page ne bouge pas si le passage commence en mesure 1', () {
      final PassageBuilder a = PassageBuilder(firstMeasure: 1);
      final PassageBuilder z = PassageBuilder(firstMeasure: 12);
      for (int i = 0; i < 5; i++) {
        a.add(67, NoteValue.quarter);
        z.add(67, NoteValue.quarter);
      }
      // Le numero imprime sur la partition ne change pas la gravure.
      expect(
        StaffLayout.of(a.build()).notes.map((PlacedNote p) => p.xSpaces),
        StaffLayout.of(z.build()).notes.map((PlacedNote p) => p.xSpaces),
      );
    });
  });
}
