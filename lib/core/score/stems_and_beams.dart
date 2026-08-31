import 'staff_layout.dart';

/// Sens de la hampe.
enum StemDirection { up, down }

/// Forme de la tete de note.
enum NoteHead {
  /// Ronde : ovale evide, plus large, sans hampe.
  whole,

  /// Blanche : ovale evide.
  half,

  /// Noire et plus bref : ovale plein.
  filled,
}

/// Une hampe, en espaces de portee.
class Stem {
  const Stem({
    required this.noteIndex,
    required this.direction,
    required this.xSpaces,
    required this.headYSpaces,
    required this.tipYSpaces,
    required this.flagCount,
  });

  final int noteIndex;
  final StemDirection direction;

  /// Abscisse de la hampe : au bord de la tete, pas en son centre.
  final double xSpaces;

  /// Ordonnee de la tete, la ou la hampe s'attache.
  final double headYSpaces;

  /// Ordonnee de l'extremite libre.
  final double tipYSpaces;

  /// Crochets a dessiner. Vaut 0 des que la note est ligaturee.
  final int flagCount;

  double get lengthSpaces => (tipYSpaces - headYSpaces).abs();
}

/// Un groupe de notes reliees par une ou plusieurs ligatures.
class Beam {
  const Beam({
    required this.noteIndices,
    required this.direction,
    required this.beamCount,
    required this.startXSpaces,
    required this.endXSpaces,
    required this.ySpaces,
  });

  final List<int> noteIndices;
  final StemDirection direction;

  /// Nombre de barres : une pour des croches, deux pour des doubles.
  final int beamCount;

  final double startXSpaces;
  final double endXSpaces;

  /// Ordonnee de la ligature. Horizontale : voir la note de conception.
  final double ySpaces;
}

/// Hampes, crochets et ligatures d'une portee monodique.
///
/// **Les ligatures sont horizontales.** Un graveur les incline en suivant le
/// contour melodique. Une ligature horizontale n'est jamais fausse, seulement
/// moins elegante, et elle evite tout le calcul de pente et de collision avec
/// les tetes. Sur deux a quatre mesures c'est un compromis tres favorable ;
/// l'inclinaison pourra s'ajouter sans rien changer au reste.
///
/// **Le groupement se fait par temps.** Deux croches se ligaturent parce
/// qu'elles tombent dans le meme temps, pas parce qu'elles se suivent a
/// l'ecran. C'est ce qui rend le rythme lisible.
class StemsAndBeams {
  const StemsAndBeams._({required this.stems, required this.beams});

  /// Longueur normale d'une hampe, mesuree depuis la tete.
  static const double standardLengthSpaces = 3.5;

  /// Distance entre deux ligatures superposees.
  static const double beamSpacingSpaces = 0.75;

  factory StemsAndBeams.of(StaffLayout layout) {
    final List<List<int>> groups = _groupByBeat(layout);
    final Map<int, int> groupOfNote = <int, int>{};
    for (int g = 0; g < groups.length; g++) {
      for (final int i in groups[g]) {
        groupOfNote[i] = g;
      }
    }

    final List<StemDirection> directions =
        List<StemDirection>.filled(layout.notes.length, StemDirection.down);
    for (int g = 0; g < groups.length; g++) {
      // Un groupe partage un seul sens : celui dicte par la note la plus
      // eloignee de la ligne du milieu. Sinon les hampes partiraient dans
      // deux directions sous la meme ligature.
      final StemDirection d = _directionForGroup(
        groups[g].map((int i) => layout.notes[i].step),
      );
      for (final int i in groups[g]) {
        directions[i] = d;
      }
    }
    for (int i = 0; i < layout.notes.length; i++) {
      if (!groupOfNote.containsKey(i)) {
        directions[i] = _directionForStep(layout.notes[i].step);
      }
    }

    final List<Stem> stems = <Stem>[];
    for (int i = 0; i < layout.notes.length; i++) {
      final PlacedNote placed = layout.notes[i];
      final int flags =
          _flagCount(placed.note.durationTicks, layout.ticksPerBeat);
      if (flags < 0) {
        continue; // Une ronde n'a pas de hampe.
      }
      final StemDirection d = directions[i];
      final double headY = placed.yInSpaces;
      stems.add(
        Stem(
          noteIndex: i,
          direction: d,
          // La hampe s'attache au bord de la tete, pas au centre : montante a
          // droite, descendante a gauche. Une tete fait un espace de large.
          xSpaces: placed.xSpaces + (d == StemDirection.up ? 0.5 : -0.5),
          headYSpaces: headY,
          tipYSpaces: _tipY(headY, placed.step, d),
          flagCount: groupOfNote.containsKey(i) ? 0 : flags,
        ),
      );
    }

    final Map<int, Stem> stemOfNote = <int, Stem>{
      for (final Stem s in stems) s.noteIndex: s,
    };

    final List<Beam> beams = <Beam>[];
    for (final List<int> group in groups) {
      final List<Stem> groupStems = <Stem>[
        for (final int i in group)
          if (stemOfNote.containsKey(i)) stemOfNote[i]!,
      ];
      if (groupStems.length < 2) {
        continue;
      }
      final StemDirection d = groupStems.first.direction;
      // La ligature se pose a l'extremite la plus lointaine du groupe, pour
      // qu'aucune hampe ne soit trop courte.
      final double y = d == StemDirection.up
          ? groupStems
              .map((Stem s) => s.tipYSpaces)
              .reduce((double a, double b) => a < b ? a : b)
          : groupStems
              .map((Stem s) => s.tipYSpaces)
              .reduce((double a, double b) => a > b ? a : b);
      beams.add(
        Beam(
          noteIndices: List<int>.unmodifiable(group),
          direction: d,
          beamCount: group
              .map(
                (int i) => _flagCount(
                  layout.notes[i].note.durationTicks,
                  layout.ticksPerBeat,
                ),
              )
              .reduce((int a, int b) => a > b ? a : b),
          startXSpaces: groupStems.first.xSpaces,
          endXSpaces: groupStems.last.xSpaces,
          ySpaces: y,
        ),
      );
    }

    return StemsAndBeams._(
      stems: List<Stem>.unmodifiable(stems),
      beams: List<Beam>.unmodifiable(beams),
    );
  }

  final List<Stem> stems;
  final List<Beam> beams;

  /// Forme de la tete pour une duree donnee.
  static NoteHead headFor(int durationTicks, int ticksPerBeat) {
    final double beats = durationTicks / ticksPerBeat;
    if (beats >= 4) {
      return NoteHead.whole;
    }
    if (beats >= 2) {
      return NoteHead.half;
    }
    return NoteHead.filled;
  }

  /// Crochets d'une duree : -1 pour une ronde, 0 pour blanche et noire,
  /// 1 pour une croche, 2 pour une double.
  ///
  /// Le calcul part du rapport a la noire, ce qui traite les notes pointees
  /// sans cas particulier : une croche pointee vaut 0,75 temps et tombe donc
  /// dans la meme tranche qu'une croche, ce qui est correct.
  static int flagsFor(int durationTicks, int ticksPerBeat) =>
      _flagCount(durationTicks, ticksPerBeat);

  /// La note porte-t-elle un point d'allongement ?
  ///
  /// Le modele ne stocke qu'une duree en ticks, pas de drapeau : le point se
  /// retrouve donc par le calcul. Une note est pointee si retirer la moitie
  /// ajoutee retombe exactement sur une figure simple. Tout se fait en
  /// entiers, pour ne pas faire dependre une tete de note d'un arrondi.
  static bool isDotted(int durationTicks, int ticksPerBeat) {
    if (durationTicks * 2 % 3 != 0) {
      return false;
    }
    return _isPlainValue(durationTicks * 2 ~/ 3, ticksPerBeat);
  }

  /// Duree d'une figure simple, de la ronde a la double croche.
  static bool _isPlainValue(int ticks, int ticksPerBeat) =>
      ticks == ticksPerBeat * 4 ||
      ticks == ticksPerBeat * 2 ||
      ticks == ticksPerBeat ||
      ticks * 2 == ticksPerBeat ||
      ticks * 4 == ticksPerBeat;

  static int _flagCount(int durationTicks, int ticksPerBeat) {
    final double beats = durationTicks / ticksPerBeat;
    if (beats >= 4) {
      return -1;
    }
    if (beats >= 1) {
      return 0;
    }
    if (beats >= 0.5) {
      return 1;
    }
    if (beats >= 0.25) {
      return 2;
    }
    return 3;
  }

  static StemDirection _directionForStep(int step) =>
      step >= 0 ? StemDirection.down : StemDirection.up;

  static StemDirection _directionForGroup(Iterable<int> steps) {
    int extreme = 0;
    for (final int step in steps) {
      if (step.abs() > extreme.abs() ||
          (step.abs() == extreme.abs() && step > extreme)) {
        extreme = step;
      }
    }
    return _directionForStep(extreme);
  }

  /// Une hampe fait 3,5 espaces, mais elle s'allonge pour atteindre la ligne
  /// du milieu quand la note est loin hors de la portee : sans ca, un sol3
  /// porterait une hampe flottante, detachee de la portee.
  static double _tipY(double headY, int step, StemDirection direction) {
    const double milieu = 0;
    if (direction == StemDirection.up) {
      final double normale = headY - standardLengthSpaces;
      return normale < milieu ? normale : milieu;
    }
    final double normale = headY + standardLengthSpaces;
    return normale > milieu ? normale : milieu;
  }

  /// Regroupe les notes a crochet par temps, sans franchir de barre.
  static List<List<int>> _groupByBeat(StaffLayout layout) {
    final List<List<int>> groups = <List<int>>[];
    List<int> current = <int>[];
    int? currentBeat;
    int? currentMeasure;

    void flush() {
      if (current.length > 1) {
        groups.add(List<int>.unmodifiable(current));
      }
      current = <int>[];
    }

    for (int i = 0; i < layout.notes.length; i++) {
      final PlacedNote placed = layout.notes[i];
      final int flags = _flagCount(
        placed.note.durationTicks,
        layout.ticksPerBeat,
      );
      if (flags < 1) {
        flush();
        currentBeat = null;
        currentMeasure = null;
        continue;
      }
      final int beat = placed.note.onsetTicks ~/ layout.ticksPerBeat;
      if (beat != currentBeat || placed.note.measure != currentMeasure) {
        flush();
        currentBeat = beat;
        currentMeasure = placed.note.measure;
      }
      current.add(i);
    }
    flush();
    return groups;
  }
}
