import 'live_tuning.dart';

/// L'echelle des notes d'un exercice, et ou s'y place une hauteur entendue.
///
/// **Elle ne contient que les notes de l'exercice**, chacune a sa hauteur
/// reelle. Pas un clavier chromatique : sur un motif la-re, deux barreaux, et
/// entre eux le vide qui les separe vraiment. On lit l'intervalle avant de
/// lire les noms.
///
/// **Chaque barreau est un contenant, et la justesse se dessine dedans.** Le
/// ruban d'ecart dit de combien on s'ecarte sans dire de quoi ; ici les deux
/// tiennent dans le meme objet -- la hauteur entendue passe a l'interieur du
/// barreau quand c'est juste, et visiblement ailleurs sinon.
///
/// **C'est du retour, pas une partition.** Un eleve de 4e annee lit son
/// papier ; on ne lui apprend pas a lire sur un piano-roll, on lui montre ce
/// qu'il vient de jouer.
class NoteLadder {
  NoteLadder({
    required Iterable<int> notes,
    this.toleranceCents = LiveTuning.defaultToleranceCents,
    this.marginSemitones = 1,
    this.minSpanSemitones = 3,
  })  : steps = List<int>.unmodifiable(
          (notes.toSet().toList()..sort()).toList(growable: false),
        ),
        assert(toleranceCents > 0, 'une tolerance est strictement positive'),
        assert(marginSemitones >= 0, 'une marge ne se retranche pas');

  /// Les hauteurs de l'exercice, triees et sans doublon.
  final List<int> steps;

  /// Demi-hauteur d'un barreau, en cents.
  ///
  /// La meme que celle du verdict en direct : un barreau qui ne vaudrait pas
  /// le bareme mentirait a l'oeil.
  final double toleranceCents;

  /// Air laisse au-dessus et en dessous, en demi-tons.
  ///
  /// Sans elle, le barreau le plus haut collerait au bord et son contenant
  /// serait coupe en deux.
  final int marginSemitones;

  /// Etendue minimale, en demi-tons.
  ///
  /// Un exercice sur une seule note donnerait une echelle de hauteur nulle,
  /// et une division par zero avec.
  final int minSpanSemitones;

  bool get isEmpty => steps.isEmpty;

  /// Bas de l'echelle, en numero MIDI.
  double get lowMidi => _bornes.$1;

  /// Haut de l'echelle, en numero MIDI.
  double get highMidi => _bornes.$2;

  (double, double) get _bornes {
    if (steps.isEmpty) {
      return (0, minSpanSemitones.toDouble());
    }
    double bas = (steps.first - marginSemitones).toDouble();
    double haut = (steps.last + marginSemitones).toDouble();
    final double manque = minSpanSemitones - (haut - bas);
    if (manque > 0) {
      bas -= manque / 2;
      haut += manque / 2;
    }
    return (bas, haut);
  }

  /// Ou se place [midi] sur l'echelle : 0 en bas, 1 en haut.
  ///
  /// **Borne, et c'est voulu.** Sur une erreur d'octave le trait vient se
  /// coller au bord plutot que de sortir du cadre : on voit d'un coup qu'on
  /// n'est pas du tout sur la note, sans avoir a lire un chiffre.
  double fractionOf(double midi) {
    final (double bas, double haut) = _bornes;
    final double part = (midi - bas) / (haut - bas);
    return part < 0
        ? 0
        : part > 1
            ? 1
            : part;
  }

  /// Le barreau que [midi] atteint, ou `null` s'il n'en atteint aucun.
  ///
  /// Entre deux barreaux, on ne nomme rien : dire "presque un do" serait
  /// inventer une note que personne n'a jouee.
  int? reachedBy(double midi) {
    final int? proche = nearest(midi);
    if (proche == null) {
      return null;
    }
    return (midi - proche).abs() * 100 <= toleranceCents ? proche : null;
  }

  /// Le barreau le plus proche de [midi], atteint ou non.
  int? nearest(double midi) {
    if (steps.isEmpty) {
      return null;
    }
    int meilleur = steps.first;
    double distance = (midi - meilleur).abs();
    for (final int pas in steps) {
      final double d = (midi - pas).abs();
      if (d < distance) {
        distance = d;
        meilleur = pas;
      }
    }
    return meilleur;
  }
}
