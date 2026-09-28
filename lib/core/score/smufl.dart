import 'staff_geometry.dart';
import 'stems_and_beams.dart';

/// Table des glyphes SMuFL utilises, et la seule metrique qui compte.
///
/// SMuFL (Standard Music Font Layout) fixe un point de code par symbole
/// musical, dans la zone privee Unicode. Bravura le respecte, comme toutes
/// les polices musicales serieuses : si un jour on en change, seul l'asset
/// bouge, pas cette table.
///
/// **Volontairement minuscule.** Bravura compte plus de 3000 glyphes. On en
/// declare une dizaine, ceux que le rendu monodique de l'ADR-007 sait poser.
/// Ajouter un glyphe ici sans savoir ou le placer ne sert a rien.
///
/// Ce fichier est du Dart pur : il ne connait ni `TextStyle` ni `Canvas`. Il
/// dit quel caractere dessiner et a quelle taille, le widget s'occupe du
/// reste.
class Smufl {
  const Smufl._();

  /// Nom de famille declare dans `pubspec.yaml`.
  static const String fontFamily = 'Bravura';

  /// **La metrique fondatrice.** Une police SMuFL est dessinee pour qu'un
  /// cadratin vaille la hauteur d'une portee, soit quatre espaces. Poser la
  /// taille de police a quatre fois l'interligne suffit donc a mettre tous
  /// les glyphes a l'echelle : aucune table de metriques a embarquer.
  static const double spacesPerEm = 4;

  /// Taille de police correspondant a un interligne donne.
  static double fontSizeForSpace(double spaceSize) => spaceSize * spacesPerEm;

  /// Cle de sol. Sa ligne de base se pose sur la ligne du sol4, celle
  /// qu'enroule la boucle du glyphe.
  static const String gClef = '\uE050';

  /// Pas de la ligne enroulee par la cle de sol : sol4, 2e ligne en partant
  /// du bas, soit deux pas sous la ligne du milieu.
  static const int gClefLineStep = -2;

  static const String noteheadWhole = '\uE0A2';
  static const String noteheadHalf = '\uE0A3';
  static const String noteheadBlack = '\uE0A4';

  static const String accidentalFlat = '\uE260';
  static const String accidentalNatural = '\uE261';
  static const String accidentalSharp = '\uE262';

  /// Glyphe d'une alteration, ou `null` s'il n'y en a pas a graver.
  static String? accidentalFor(Accidental accidental) => switch (accidental) {
        Accidental.sharp => accidentalSharp,
        Accidental.flat => accidentalFlat,
        Accidental.natural => accidentalNatural,
        Accidental.none => null,
      };

  /// Silences. Leur ligne de base se pose sur la ligne du milieu, sauf la
  /// pause, qui pend sous la quatrieme ligne : voir [restBaselineStep].
  static const String restWhole = '\uE4E3';
  static const String restHalf = '\uE4E4';
  static const String restQuarter = '\uE4E5';
  static const String rest8th = '\uE4E6';
  static const String rest16th = '\uE4E7';

  /// Le silence d'une duree, a la noire pres ; le point se retrouve a part,
  /// comme pour les notes.
  static String restFor(int durationTicks, int ticksPerBeat) {
    final double temps = durationTicks / ticksPerBeat;
    if (temps >= 4) {
      return restWhole;
    }
    if (temps >= 2) {
      return restHalf;
    }
    if (temps >= 1) {
      return restQuarter;
    }
    if (temps >= 0.5) {
      return rest8th;
    }
    return rest16th;
  }

  /// Pas ou se pose la ligne de base d'un silence : la pause pend sous la
  /// quatrieme ligne, tous les autres se centrent sur la ligne du milieu.
  static int restBaselineStep(String glyph) => glyph == restWhole ? 2 : 0;

  /// Chiffres du chiffrage, de 0 a 9. Chaque chiffre se centre sur sa ligne
  /// de base : le numerateur sur la quatrieme ligne, le denominateur sur la
  /// deuxieme.
  static String timeSigDigits(int value) => String.fromCharCodes(<int>[
        for (final int c in '$value'.codeUnits) 0xE080 + c - 0x30,
      ]);

  /// Point d'allongement. Le modele ne stocke qu'une duree en ticks : c'est
  /// [StemsAndBeams.isDotted] qui retrouve le point, pas un drapeau porte par
  /// la note.
  static const String augmentationDot = '\uE1E7';

  static const String flag8thUp = '\uE240';
  static const String flag8thDown = '\uE241';
  static const String flag16thUp = '\uE242';
  static const String flag16thDown = '\uE243';
  static const String flag32ndUp = '\uE244';
  static const String flag32ndDown = '\uE245';

  /// Tete de note correspondant a une figure.
  static String noteheadFor(NoteHead head) => switch (head) {
        NoteHead.whole => noteheadWhole,
        NoteHead.half => noteheadHalf,
        NoteHead.filled => noteheadBlack,
      };

  /// Crochet d'une hampe, ou `null` si la note n'en porte pas.
  ///
  /// Un seul glyphe porte tous les crochets d'une figure : le glyphe de la
  /// double croche dessine deja ses deux crochets. On ne les empile donc pas,
  /// contrairement aux ligatures.
  static String? flagFor(int flagCount, StemDirection direction) {
    final bool up = direction == StemDirection.up;
    return switch (flagCount) {
      1 => up ? flag8thUp : flag8thDown,
      2 => up ? flag16thUp : flag16thDown,
      >= 3 => up ? flag32ndUp : flag32ndDown,
      _ => null,
    };
  }
}
