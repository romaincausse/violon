/// Les formules de gammes et d'arpeges, en demi-tons depuis la tonique.
///
/// **Ce sont des formules, pas des exercices.** Une formule ne connait ni
/// tonalite ni rythme : elle dit seulement quels degres se suivent. La
/// tonique, le nombre d'octaves et les figures arrivent dans
/// `lib/core/exercises/`, ou un exercice se declare.
///
/// L'interet de cette separation est celui du jalon entier : une gamme **se
/// genere** a partir de trois parametres, alors qu'un morceau doit etre saisi
/// note par note. C'est ce qui rend l'application utile tous les jours sans
/// rien preparer.
enum ScalePattern {
  majeur('Majeur', <int>[0, 2, 4, 5, 7, 9, 11]),
  mineurNaturel('Mineur naturel', <int>[0, 2, 3, 5, 7, 8, 10]),
  mineurHarmonique('Mineur harmonique', <int>[0, 2, 3, 5, 7, 8, 11]),

  /// Montant par la formule melodique, descendant par le mineur naturel.
  ///
  /// **Ce n'est pas une subtilite de theoricien.** C'est ainsi qu'une gamme
  /// mineure melodique se joue et se travaille, chez Hrimaly comme partout
  /// ailleurs : la sixte et la septieme montent, puis redescendent. Faire
  /// redescendre la formule montante afficherait deux notes que le professeur
  /// n'a pas demandees -- et l'enfant, qui joue ce qu'on lui a appris, se
  /// verrait compter faux ce qu'il joue juste. C'est exactement la faute que
  /// la definition of done interdit d'imputer a l'eleve.
  mineurMelodique(
    'Mineur melodique',
    <int>[0, 2, 3, 5, 7, 9, 11],
    descente: <int>[0, 2, 3, 5, 7, 8, 10],
  ),

  arpegeMajeur('Arpege majeur', <int>[0, 4, 7]),
  arpegeMineur('Arpege mineur', <int>[0, 3, 7]);

  const ScalePattern(this.label, this.montee, {List<int>? descente})
      : _descente = descente;

  /// Nom francais affiche a l'utilisateur.
  final String label;

  /// Degres de la formule montante, sur une octave, tonique comprise et
  /// octave exclue : c'est [midis] qui referme l'octave.
  final List<int> montee;

  final List<int>? _descente;

  /// Degres de la formule descendante. Identiques a la montee, sauf pour le
  /// mineur melodique.
  List<int> get descente => _descente ?? montee;

  /// Vrai si la formule ne se descend pas comme elle se monte.
  bool get asymetrique => _descente != null;

  /// Les hauteurs de la gamme, en MIDI.
  ///
  /// La note la plus aigue n'est jouee qu'une fois : une gamme qui repeterait
  /// sa tonique au sommet donnerait deux notes de meme hauteur a la suite, et
  /// le detecteur d'attaques n'en verrait qu'une (voir `OnsetDetector`).
  List<int> midis({
    required int tonicMidi,
    int octaves = 1,
    bool retour = true,
  }) {
    assert(octaves >= 1, 'une gamme fait au moins une octave');
    final List<int> montant = _empiler(montee, tonicMidi, octaves);
    if (!retour) {
      return montant;
    }
    final List<int> descendant = _empiler(descente, tonicMidi, octaves)
        .reversed
        .skip(1)
        .toList(growable: false);
    return <int>[...montant, ...descendant];
  }

  /// Nombre de notes rendues par [midis], sans les construire.
  int noteCount({int octaves = 1, bool retour = true}) {
    final int montant = montee.length * octaves + 1;
    return retour ? montant + descente.length * octaves : montant;
  }

  static List<int> _empiler(List<int> degres, int tonique, int octaves) {
    final List<int> notes = <int>[];
    for (int octave = 0; octave < octaves; octave++) {
      for (final int degre in degres) {
        notes.add(tonique + 12 * octave + degre);
      }
    }
    notes.add(tonique + 12 * octaves);
    return notes;
  }
}
