import 'dart:math' as math;

import '../music/passage.dart';
import '../music/score_note.dart';
import 'staff_geometry.dart';
import 'staff_layout.dart';
import 'stems_and_beams.dart';

/// Un systeme : une ligne de portee, avec sa cle et ses mesures.
///
/// Un systeme n'est rien d'autre qu'une [StaffLayout] posee sur un morceau du
/// passage. Tout ce qui etait deja calcule et teste -- espacement, barres,
/// lignes supplementaires -- sert tel quel : passer a la ligne ne change pas
/// la gravure, seulement son decoupage.
class StaffSystem {
  const StaffSystem({required this.layout, required this.index});

  final StaffLayout layout;

  /// Rang du systeme, 0 pour le premier.
  final int index;

  List<PlacedNote> get notes => layout.notes;
  List<double> get barlineXSpaces => layout.barlineXSpaces;
  double get widthSpaces => layout.widthSpaces;

  /// Premier instant porte par ce systeme.
  int get firstTick => layout.firstOnsetTicks;

  /// Fin de la derniere note du systeme.
  int get endTick => layout.lastOffsetTicks;

  bool contains(int tick) => tick >= firstTick && tick < endTick;

  double xForTick(int tick) => layout.xForTick(tick);
}

/// Mise en page d'un passage sur plusieurs systemes.
///
/// **On ne coupe qu'aux barres de mesure.** Couper au milieu d'une mesure
/// serait une faute de gravure, et surtout illisible pour un enfant qui suit
/// la pulsation : une mesure commencee doit finir sur la meme ligne.
///
/// **Le decoupage est glouton, et c'est suffisant.** Un graveur equilibre les
/// systemes pour qu'ils aient a peu pres la meme longueur. Sur deux a huit
/// mesures, remplir chaque ligne au maximum donne le meme resultat neuf fois
/// sur dix, et se raisonne en dix lignes au lieu de cent.
class ScoreLayout {
  const ScoreLayout._({required this.systems, required this.passage});

  /// Repartit [passage] sur autant de systemes qu'il en faut pour qu'aucun ne
  /// depasse [maxWidthSpaces].
  ///
  /// [maxSystems] plafonne le nombre de lignes. Au-dela, les mesures
  /// continuent de s'empiler sur le dernier systeme, quitte a ce qu'il
  /// deborde : mieux vaut une ligne trop longue qu'une mesure escamotee.
  factory ScoreLayout.of(
    Passage passage, {
    required double maxWidthSpaces,
    int? maxSystems,
  }) {
    final List<List<ScoreNote>> mesures = _parMesure(passage.notes);
    final List<List<ScoreNote>> groupes = <List<ScoreNote>>[];
    List<ScoreNote> courant = <ScoreNote>[];

    for (final List<ScoreNote> mesure in mesures) {
      final bool plafondAtteint =
          maxSystems != null && groupes.length + 1 >= maxSystems;
      if (courant.isEmpty || plafondAtteint) {
        courant = <ScoreNote>[...courant, ...mesure];
        continue;
      }
      final List<ScoreNote> essai = <ScoreNote>[...courant, ...mesure];
      if (_largeurDe(passage, essai) > maxWidthSpaces) {
        groupes.add(courant);
        courant = mesure;
      } else {
        courant = essai;
      }
    }
    groupes.add(courant);

    return ScoreLayout._(
      systems: List<StaffSystem>.unmodifiable(<StaffSystem>[
        for (int i = 0; i < groupes.length; i++)
          StaffSystem(
            layout: StaffLayout.of(_sousPassage(passage, groupes[i])),
            index: i,
          ),
      ]),
      passage: passage,
    );
  }

  final List<StaffSystem> systems;
  final Passage passage;

  int get systemCount => systems.length;

  /// Largeur du plus large systeme. C'est elle qui dimensionne la zone de
  /// dessin : les systemes plus courts sont simplement moins remplis.
  double get widthSpaces => systems
      .map((StaffSystem s) => s.widthSpaces)
      .reduce((double a, double b) => a > b ? a : b);

  /// Systeme et abscisse d'un instant quelconque.
  ///
  /// Avant le debut, on rend le tout premier point ; apres la fin, le tout
  /// dernier. Le curseur ne disparait donc jamais de l'ecran.
  (int, double) positionOfTick(int tick) {
    for (final StaffSystem system in systems) {
      if (system.contains(tick)) {
        return (system.index, system.xForTick(tick));
      }
    }
    if (tick < systems.first.firstTick) {
      return (0, systems.first.xForTick(systems.first.firstTick));
    }
    final StaffSystem dernier = systems.last;
    return (dernier.index, dernier.xForTick(dernier.endTick));
  }

  /// Pas le plus grave et le plus aigu de **tout** le passage.
  ///
  /// La reserve verticale se calcule une fois pour toutes et vaut pour chaque
  /// systeme : sinon les portees n'auraient pas la meme hauteur et le regard
  /// sauterait d'une ligne a l'autre.
  int get lowestStep => systems
      .map((StaffSystem s) => s.layout.lowestStep)
      .reduce((int a, int b) => a < b ? a : b);

  int get highestStep => systems
      .map((StaffSystem s) => s.layout.highestStep)
      .reduce((int a, int b) => a > b ? a : b);

  static List<List<ScoreNote>> _parMesure(List<ScoreNote> notes) {
    final List<List<ScoreNote>> mesures = <List<ScoreNote>>[];
    for (final ScoreNote note in notes) {
      if (mesures.isEmpty || mesures.last.first.measure != note.measure) {
        mesures.add(<ScoreNote>[note]);
      } else {
        mesures.last.add(note);
      }
    }
    return mesures;
  }

  static double _largeurDe(Passage passage, List<ScoreNote> notes) =>
      StaffLayout.of(_sousPassage(passage, notes)).widthSpaces;

  static Passage _sousPassage(Passage passage, List<ScoreNote> notes) =>
      Passage(
        title: passage.title,
        notes: notes,
        ticksPerBeat: passage.ticksPerBeat,
        writtenTempoBpm: passage.writtenTempoBpm,
      );
}

/// Reserve verticale d'un systeme, en espaces de portee.
///
/// **La meme pour tous les systemes d'un passage.** Elle se calcule sur la
/// note la plus grave et la plus aigue de l'ensemble : des portees de hauteurs
/// differentes feraient sauter le regard d'une ligne a l'autre.
///
/// En Dart pur, comme le reste de la mise en page : c'est de la geometrie, et
/// le widget n'a qu'a multiplier par la taille d'un interligne.
class SystemMetrics {
  const SystemMetrics({required this.topSpaces, required this.bottomSpaces});

  factory SystemMetrics.of(ScoreLayout layout) {
    // Une marge d'un espace et demi au-dela de l'element le plus extreme, pour
    // ne rogner ni les lignes supplementaires ni les hampes. La cle de sol
    // deborde moins qu'une hampe pleine longueur : la reserve la contient.
    final double haut = math.min(
          StaffGeometry.yInSpaces(layout.highestStep),
          -2.0 - StemsAndBeams.standardLengthSpaces,
        ) -
        1.5;
    final double bas = math.max(
          StaffGeometry.yInSpaces(layout.lowestStep),
          2.0 + StemsAndBeams.standardLengthSpaces,
        ) +
        1.5;
    return SystemMetrics(topSpaces: haut, bottomSpaces: bas);
  }

  final double topSpaces;
  final double bottomSpaces;

  double get heightSpaces => bottomSpaces - topSpaces;

  /// Blanc laisse entre deux systemes.
  static const double gapSpaces = 2;

  /// Hauteur totale de [count] systemes empiles.
  double stackHeightSpaces(int count) =>
      count * heightSpaces + (count - 1) * gapSpaces;

  /// Ordonnee du milieu de portee du systeme [index], en espaces, depuis le
  /// haut de la zone de dessin.
  double originOfSystem(int index) =>
      index * (heightSpaces + gapSpaces) - topSpaces;
}
