import 'dart:math' as math;

import 'staff_layout.dart';
import 'stems_and_beams.dart';

/// Ou graver les nuances (lot K9), en espaces de portee : sous la portee,
/// sous la tete et sous une hampe descendante ou sa ligature, comme une
/// edition les pose.
///
/// **Un mot, pas un dessin** : "mf", "cresc.", "dim.". Le soufflet dessine
/// demanderait de savoir ou il finit sur un autre systeme ; le mot dit la
/// meme chose et tient dans ce que l'ADR-007 permet.
class DynamicMarks {
  const DynamicMarks._();

  static const double gapSpaces = 0.6;
  static const double heightSpaces = 1.8;

  /// La ligne du bas de la portee.
  static const double _ligneDuBas = 2;

  /// Le texte a graver sous une tete, ou `null`.
  static String? textFor(PlacedNote n) {
    if (n.isContinuation) {
      return null;
    }
    final String? nuance = n.note.dynamicMark;
    if (nuance != null) {
      return nuance;
    }
    return switch (n.note.hairpin) {
      'cresc' => 'cresc.',
      'dim' => 'dim.',
      _ => null,
    };
  }

  /// Le centre vertical de chaque nuance de [staff], par indice de tete.
  static Map<int, double> place(StaffLayout staff) {
    final Map<int, double> centres = <int, double>{};
    StemsAndBeams? hampes;
    for (int i = 0; i < staff.notes.length; i++) {
      final PlacedNote n = staff.notes[i];
      if (textFor(n) == null) {
        continue;
      }
      hampes ??= StemsAndBeams.of(staff);
      double sol = math.max(_ligneDuBas, n.yInSpaces + 0.5);
      final double? pointe = _hampeDescendante(hampes, i);
      if (pointe != null && pointe > sol) {
        sol = pointe;
      }
      centres[i] = sol + gapSpaces + heightSpaces / 2;
    }
    return centres;
  }

  static double? _hampeDescendante(StemsAndBeams hampes, int i) {
    for (final Beam b in hampes.beams) {
      if (b.direction == StemDirection.down && b.noteIndices.contains(i)) {
        return b.ySpaces;
      }
    }
    for (final Stem s in hampes.stems) {
      if (s.noteIndex == i && s.direction == StemDirection.down) {
        return s.tipYSpaces;
      }
    }
    return null;
  }
}
