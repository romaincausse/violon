import '../music/passage.dart';
import '../music/score_note.dart';
import 'staff_geometry.dart';

/// Une note posee sur la portee : ou la dessiner, et avec quoi.
class PlacedNote {
  const PlacedNote({
    required this.note,
    required this.step,
    required this.accidental,
    required this.ledgerSteps,
    required this.xSpaces,
  });

  final ScoreNote note;

  /// Pas sur la portee, 0 sur la ligne du milieu.
  final int step;

  final Accidental accidental;

  /// Lignes supplementaires a tracer sous ou sur cette note.
  final List<int> ledgerSteps;

  /// Abscisse du centre de la tete, en espaces de portee.
  final double xSpaces;

  double get yInSpaces => StaffGeometry.yInSpaces(step);
  bool get isOnLine => StaffGeometry.isOnLine(step);
}

/// Mise en page d'un passage sur une portee, en espaces de portee.
///
/// **Espacement proportionnel au temps.** Un graveur professionnel espace de
/// facon non lineaire (une ronde n'occupe pas quatre fois la place d'une
/// noire). Sur deux a quatre mesures monodiques, le proportionnel se lit tres
/// bien et se raisonne en une ligne. C'est un choix assume, pas un oubli.
///
/// **Les barres de mesure viennent des notes, pas d'un chiffrage.** [Passage]
/// ne stocke pas le nombre de temps par mesure, mais chaque [ScoreNote] porte
/// son numero de mesure : un changement de numero est une barre. La mise en
/// page reste donc juste meme si le passage commence sur une levee.
class StaffLayout {
  const StaffLayout._({
    required this.notes,
    required this.barlineXSpaces,
    required this.widthSpaces,
    required this.ticksPerBeat,
  });

  factory StaffLayout.of(
    Passage passage, {
    double spacesPerBeat = 6,
    double leadingSpaces = 9,
    double trailingSpaces = 3,
    double barlineGapSpaces = 2.5,
  }) {
    final List<ScoreNote> source = passage.notes;
    final int firstOnset = source.first.onsetTicks;
    final double perTick = spacesPerBeat / passage.ticksPerBeat;

    final List<PlacedNote> placed = <PlacedNote>[];
    final List<double> barlines = <double>[];
    double offset = 0;

    for (int i = 0; i < source.length; i++) {
      final ScoreNote note = source[i];
      if (i > 0 && note.measure != source[i - 1].measure) {
        // La barre se glisse dans l'espace qu'on vient d'ouvrir, juste avant
        // le premier temps de la mesure suivante.
        final double xAvant =
            leadingSpaces + (note.onsetTicks - firstOnset) * perTick + offset;
        barlines.add(xAvant + barlineGapSpaces / 2);
        offset += barlineGapSpaces;
      }
      final int step = StaffGeometry.stepOf(note.midi);
      placed.add(
        PlacedNote(
          note: note,
          step: step,
          accidental: StaffGeometry.accidentalOf(note.midi),
          ledgerSteps: StaffGeometry.ledgerSteps(step),
          xSpaces:
              leadingSpaces + (note.onsetTicks - firstOnset) * perTick + offset,
        ),
      );
    }

    final ScoreNote last = source.last;
    final double contentEnd =
        leadingSpaces + (last.offsetTicks - firstOnset) * perTick + offset;
    final double width = contentEnd + trailingSpaces;
    // Barre finale, calee sur le bord droit.
    barlines.add(width - trailingSpaces / 2);

    return StaffLayout._(
      notes: List<PlacedNote>.unmodifiable(placed),
      barlineXSpaces: List<double>.unmodifiable(barlines),
      widthSpaces: width,
      ticksPerBeat: passage.ticksPerBeat,
    );
  }

  final List<PlacedNote> notes;

  /// Abscisses des barres de mesure, la derniere etant la barre finale.
  final List<double> barlineXSpaces;

  final double widthSpaces;

  /// Resolution du passage d'origine. Conservee ici parce que les hampes et
  /// les ligatures raisonnent en temps : une croche se ligature avec ses
  /// voisines du meme temps, pas avec ses voisines de l'ecran.
  final int ticksPerBeat;

  /// Pas le plus grave atteint, lignes supplementaires comprises. Sert a
  /// dimensionner la zone de dessin sans rogner les notes hors portee.
  int get lowestStep => notes
      .map((PlacedNote p) => p.step)
      .fold(StaffGeometry.bottomLineStep, (int a, int b) => a < b ? a : b);

  int get highestStep => notes
      .map((PlacedNote p) => p.step)
      .fold(StaffGeometry.topLineStep, (int a, int b) => a > b ? a : b);
}
