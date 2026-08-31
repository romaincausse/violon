/// Alteration a dessiner devant une note.
///
/// Pas de bemol : [ScoreNote] ne stocke qu'un numero MIDI, sans orthographe
/// enharmonique, et le reste de l'application n'affiche que des dieses.
/// Introduire le bemol ici demanderait d'ajouter l'orthographe au modele
/// pivot, ce qui deborde de la gravure.
enum Accidental { none, sharp }

/// Geometrie d'une portee en cle de sol.
///
/// Tout est exprime en **espaces de portee** (l'unite SMuFL) : la distance
/// entre deux lignes vaut 1. Le rendu multiplie ensuite par la taille reelle
/// d'un espace. Aucune coordonnee en pixels ne remonte jusqu'ici, ce qui rend
/// la mise en page testable sans widget.
///
/// L'axe des pas (`step`) compte les degres de la gamme, pas les demi-tons :
/// 0 est la ligne du milieu, un pas vaut une ligne ou un interligne. Un do#
/// et un do occupent donc le meme pas, ce qui est exactement ce qu'on veut
/// pour poser une tete de note.
class StaffGeometry {
  const StaffGeometry._();

  /// Si4. En cle de sol, c'est la ligne du milieu, donc le pas 0.
  static const int middleLineMidi = 71;

  /// Lettre de chaque classe de hauteur, en degres depuis do.
  /// Un do# se pose sur do, un fa# sur fa : d'ou les valeurs repetees.
  static const List<int> _letterOfPitchClass = <int>[
    0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5,
    6, // do do# re re# mi fa fa# sol sol# la la# si
  ];

  static const Set<int> _sharpPitchClasses = <int>{1, 3, 6, 8, 10};

  /// Pas le plus grave de la portee : mi4, la ligne du bas.
  static const int bottomLineStep = -4;

  /// Pas le plus aigu de la portee : fa5, la ligne du haut.
  static const int topLineStep = 4;

  /// Degre diatonique absolu, do0 valant 0.
  static int diatonicIndex(int midi) {
    final int octave = (midi ~/ 12) - 1;
    return 7 * octave + _letterOfPitchClass[midi % 12];
  }

  /// Pas sur la portee, 0 sur la ligne du milieu, positif vers l'aigu.
  static int stepOf(int midi) =>
      diatonicIndex(midi) - diatonicIndex(middleLineMidi);

  static Accidental accidentalOf(int midi) =>
      _sharpPitchClasses.contains(midi % 12)
          ? Accidental.sharp
          : Accidental.none;

  /// Un pas pair tombe sur une ligne, un pas impair dans un interligne.
  static bool isOnLine(int step) => step.isEven;

  /// Ordonnee en espaces, positive vers le bas comme a l'ecran.
  /// Un pas vaut un demi-espace.
  static double yInSpaces(int step) => -0.5 * step;

  /// Lignes supplementaires a tracer pour atteindre ce pas.
  ///
  /// Rendues du plus proche de la portee au plus eloigne. Une note posee dans
  /// l'interligne au-dela de la derniere ligne (un sol3 sous la portee) a
  /// besoin des lignes en dessous d'elle, pas d'une ligne a sa hauteur : d'ou
  /// le parcours par pas pairs uniquement.
  static List<int> ledgerSteps(int step) {
    if (step <= bottomLineStep - 2) {
      return <int>[
        for (int s = bottomLineStep - 2; s >= step; s -= 2) s,
      ];
    }
    if (step >= topLineStep + 2) {
      return <int>[
        for (int s = topLineStep + 2; s <= step; s += 2) s,
      ];
    }
    return const <int>[];
  }
}
