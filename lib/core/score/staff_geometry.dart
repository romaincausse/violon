/// Alteration a dessiner devant une note.
///
/// **L'orthographe vient de l'armure, pas du modele.** [ScoreNote] ne stocke
/// qu'un numero MIDI. Sans armure connue, tout s'ecrit en dieses, comme
/// toujours ; avec une armure, une touche noire s'ecrit comme la tonalite
/// l'ecrit -- si bemol en fa majeur, pas la diese -- et le becarre apparait
/// quand une note quitte l'armure.
enum Accidental { none, sharp, flat, natural }

/// Une hauteur ecrite : sa lettre, son octave et son alteration.
class SpelledPitch {
  const SpelledPitch({
    required this.letter,
    required this.octave,
    required this.alter,
  });

  /// Degre depuis do : 0 pour do, 6 pour si.
  final int letter;
  final int octave;

  /// -1 bemol, 0 naturel, +1 diese.
  final int alter;

  /// Pas sur la portee, 0 sur la ligne du milieu.
  int get step =>
      7 * octave +
      letter -
      StaffGeometry.diatonicIndex(StaffGeometry.middleLineMidi);
}

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

  /// Classe de hauteur de chaque lettre naturelle, de do a si.
  static const List<int> _naturelle = <int>[0, 2, 4, 5, 7, 9, 11];

  /// Ordre des dieses et des bemols a l'armure, en lettres.
  static const List<int> _ordreDesDieses = <int>[3, 0, 4, 1, 5, 2, 6];
  static const List<int> _ordreDesBemols = <int>[6, 2, 5, 1, 4, 0, 3];

  /// Alteration que l'armure donne a chaque lettre.
  static List<int> keyAlterations(int keyFifths) {
    final List<int> alterations = List<int>.filled(7, 0);
    final int n = keyFifths.abs().clamp(0, 7);
    for (int i = 0; i < n; i++) {
      if (keyFifths > 0) {
        alterations[_ordreDesDieses[i]] = 1;
      } else {
        alterations[_ordreDesBemols[i]] = -1;
      }
    }
    return alterations;
  }

  /// Pas des alterations de l'armure, dans l'ordre ou on les grave.
  ///
  /// Les positions sont celles de la cle de sol : le fa# sur la ligne du
  /// haut, le si bemol sur la ligne du milieu.
  static List<int> keySignatureSteps(int keyFifths) {
    const List<int> dieses = <int>[4, 1, 5, 2, -1, 3, 0];
    const List<int> bemols = <int>[0, 3, -1, 2, -2, 1, -3];
    final int n = keyFifths.abs().clamp(0, 7);
    return (keyFifths >= 0 ? dieses : bemols).take(n).toList();
  }

  /// Ecrit [midi] comme la tonalite l'ecrit.
  ///
  /// Une note de la gamme prend l'orthographe de l'armure. Une note etrangere
  /// prend un diese en tonalite a dieses, un bemol en tonalite a bemols, et
  /// reste naturelle si c'est une touche blanche -- ce que ferait un graveur
  /// sur une partition d'eleve. Sans armure, tout s'ecrit en dieses.
  static SpelledPitch spell(int midi, {int? keyFifths}) {
    final int pc = midi % 12;
    final List<int> armure = keyAlterations(keyFifths ?? 0);
    int? lettre;
    int alteration = 0;
    for (int l = 0; l < 7; l++) {
      if ((_naturelle[l] + armure[l]) % 12 == pc) {
        lettre = l;
        alteration = armure[l];
        break;
      }
    }
    if (lettre == null) {
      final int blanche = _naturelle.indexOf(pc);
      if (blanche >= 0) {
        lettre = blanche;
        alteration = 0;
      } else if ((keyFifths ?? 0) < 0) {
        lettre = _naturelle.indexOf((pc + 1) % 12);
        alteration = -1;
      } else {
        lettre = _naturelle.indexOf((pc + 11) % 12);
        alteration = 1;
      }
    }
    return SpelledPitch(
      letter: lettre,
      octave: (midi - alteration) ~/ 12 - 1,
      alter: alteration,
    );
  }

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
