import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/score/staff_geometry.dart';

void main() {
  group('StaffGeometry - les pas de la cle de sol', () {
    test('les cinq lignes de la portee tombent aux pas pairs', () {
      // De bas en haut : mi4, sol4, si4, re5, fa5.
      expect(StaffGeometry.stepOf(64), -4, reason: 'mi4, ligne du bas');
      expect(StaffGeometry.stepOf(67), -2, reason: 'sol4, ligne de la cle');
      expect(StaffGeometry.stepOf(71), 0, reason: 'si4, ligne du milieu');
      expect(StaffGeometry.stepOf(74), 2, reason: 're5');
      expect(StaffGeometry.stepOf(77), 4, reason: 'fa5, ligne du haut');
    });

    test('les interlignes tombent aux pas impairs', () {
      // Fa-la-do-mi, le mot "FACE" des methodes anglaises.
      expect(StaffGeometry.stepOf(65), -3, reason: 'fa4');
      expect(StaffGeometry.stepOf(69), -1, reason: 'la4');
      expect(StaffGeometry.stepOf(72), 1, reason: 'do5');
      expect(StaffGeometry.stepOf(76), 3, reason: 'mi5');
    });

    test('le do du milieu est la premiere ligne supplementaire du bas', () {
      expect(StaffGeometry.stepOf(60), -6);
      expect(StaffGeometry.ledgerSteps(-6), <int>[-6]);
    });

    test('les quatre cordes a vide du violon tombent ou il faut', () {
      expect(StaffGeometry.stepOf(55), -9, reason: 'sol3, sous la portee');
      expect(StaffGeometry.stepOf(62), -5, reason: 're4, sous la ligne du bas');
      expect(StaffGeometry.stepOf(69), -1, reason: 'la4');
      expect(StaffGeometry.stepOf(76), 3, reason: 'mi5');
    });

    test('une alteration ne deplace pas la note d un pas', () {
      // Un fa# se pose exactement sur le fa : c'est le diese qui le dit.
      expect(StaffGeometry.stepOf(66), StaffGeometry.stepOf(65));
      expect(StaffGeometry.accidentalOf(66), Accidental.sharp);
      expect(StaffGeometry.accidentalOf(65), Accidental.none);
    });

    test('les cinq classes alterees sont exactement les touches noires', () {
      final List<int> alterees = <int>[
        for (int midi = 60; midi < 72; midi++)
          if (StaffGeometry.accidentalOf(midi) == Accidental.sharp) midi % 12,
      ];
      expect(alterees, <int>[1, 3, 6, 8, 10]);
    });

    test('les pas et les noms de notes restent d accord', () {
      // Deux notes de meme lettre a une octave d ecart sont a sept pas.
      for (final int midi in <int>[55, 60, 62, 67, 69]) {
        expect(
          StaffGeometry.stepOf(midi + 12) - StaffGeometry.stepOf(midi),
          7,
          reason: '${PitchUtils.noteName(midi)} a l octave',
        );
      }
    });
  });

  group('StaffGeometry - lignes supplementaires', () {
    test('aucune ligne tant qu on reste sur la portee', () {
      for (int step = -5; step <= 5; step++) {
        expect(StaffGeometry.ledgerSteps(step), isEmpty, reason: 'pas $step');
      }
    });

    test('une note dans l interligne au-dela porte les lignes sous elle', () {
      // Sol3 pend sous la deuxieme ligne supplementaire, il n en a pas une
      // a sa propre hauteur.
      expect(StaffGeometry.ledgerSteps(-9), <int>[-6, -8]);
      expect(StaffGeometry.ledgerSteps(-8), <int>[-6, -8]);
      expect(StaffGeometry.ledgerSteps(-7), <int>[-6]);
    });

    test('vers l aigu aussi', () {
      expect(StaffGeometry.ledgerSteps(6), <int>[6], reason: 'la5');
      expect(StaffGeometry.ledgerSteps(8), <int>[6, 8], reason: 'do6');
      expect(StaffGeometry.ledgerSteps(5), isEmpty, reason: 'sol5');
    });

    test('les lignes supplementaires sont toujours paires et ordonnees', () {
      for (final int step in <int>[-12, -9, -6, 7, 10]) {
        final List<int> lignes = StaffGeometry.ledgerSteps(step);
        expect(lignes.every((int s) => s.isEven), isTrue);
        expect(
          lignes.map((int s) => s.abs()).toList(),
          orderedEquals(lignes.map((int s) => s.abs()).toList()..sort()),
          reason: 'de la portee vers l exterieur',
        );
      }
    });
  });

  group('StaffGeometry - ordonnees', () {
    test('un pas vaut un demi-espace, vers le haut', () {
      expect(StaffGeometry.yInSpaces(0), 0);
      expect(StaffGeometry.yInSpaces(2), -1, reason: 'une ligne plus haut');
      expect(StaffGeometry.yInSpaces(-4), 2, reason: 'la ligne du bas');
    });

    test('la portee fait quatre espaces de haut', () {
      final double haut = StaffGeometry.yInSpaces(StaffGeometry.topLineStep);
      final double bas = StaffGeometry.yInSpaces(StaffGeometry.bottomLineStep);
      expect(bas - haut, 4);
    });
  });
}
