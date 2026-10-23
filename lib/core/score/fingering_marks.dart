import 'dart:math' as math;

import 'staff_layout.dart';
import 'stems_and_beams.dart';

/// Ou graver le chiffre de doigte d'une tete (lot K2), en espaces de portee.
///
/// **Au-dessus de tout ce qui est deja grave** : de la portee, de la tete et
/// d'une hampe montante ou de sa ligature. C'est ainsi qu'une edition pour
/// violon pose ses doigtes, et c'est tout ce que l'ADR-007 permet : un
/// chiffre, pas un graveur general.
class FingeringMarks {
  const FingeringMarks._();

  /// Blanc entre ce qui est grave et le chiffre.
  static const double gapSpaces = 0.5;

  /// Hauteur reservee au chiffre.
  static const double heightSpaces = 1.4;

  /// La ligne du haut de la portee.
  static const double _ligneDuHaut = -2;

  /// Le centre vertical du chiffre de chaque tete doigtee de [staff], par
  /// indice de tete. Une tete qui prolonge la precedente ne repete pas le
  /// doigte : c'est la meme note.
  static Map<int, double> place(StaffLayout staff) {
    final Map<int, double> centres = <int, double>{};
    StemsAndBeams? hampes;
    for (int i = 0; i < staff.notes.length; i++) {
      final PlacedNote n = staff.notes[i];
      if (n.note.fingering == null || n.isContinuation) {
        continue;
      }
      hampes ??= StemsAndBeams.of(staff);
      double ciel = math.min(_ligneDuHaut, n.yInSpaces - 0.5);
      final double? pointe = _hampeMontante(hampes, i);
      if (pointe != null && pointe < ciel) {
        ciel = pointe;
      }
      centres[i] = ciel - gapSpaces - heightSpaces / 2;
    }
    return centres;
  }

  /// Le haut de la hampe montante de la tete [i] -- sa ligature si elle en a
  /// une --, ou `null`.
  static double? _hampeMontante(StemsAndBeams hampes, int i) {
    for (final Beam b in hampes.beams) {
      if (b.direction == StemDirection.up && b.noteIndices.contains(i)) {
        return b.ySpaces;
      }
    }
    for (final Stem s in hampes.stems) {
      if (s.noteIndex == i && s.direction == StemDirection.up) {
        return s.tipYSpaces;
      }
    }
    return null;
  }
}
