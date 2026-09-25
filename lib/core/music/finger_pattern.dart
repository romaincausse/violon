/// Ecartement des doigts dans une position, en demi-tons depuis la corde a vide.
///
/// **Un violon n'a pas de touches.** La main gauche ne connait pas des notes,
/// elle connait des ecarts entre les doigts : la ou tombe le demi-ton dit tout
/// le reste. C'est precisement ce que Sevcik fait travailler dans son op. 1, et
/// c'est ce que decrit cette classe -- les quatre configurations de la premiere
/// position, nommees par la paire de doigts qui se serre.
///
/// Consequence pratique pour l'application : un motif de doigts se **transpose
/// sur les quatre cordes sans rien recalculer**, et c'est ce qui permet de
/// generer le catalogue au lieu de le saisir.
class FingerPattern {
  const FingerPattern({
    required this.id,
    required this.label,
    required this.semitones,
  });

  final String id;

  /// Nom affiche a l'utilisateur, dans le vocabulaire du cours de violon.
  final String label;

  /// Demi-tons depuis la corde a vide, index par doigt : l'index 0 est la
  /// corde a vide, l'index 4 le quatrieme doigt. Toujours cinq valeurs
  /// croissantes -- un test le verifie, faute de pouvoir l'affirmer dans un
  /// constructeur constant.
  final List<int> semitones;

  /// Hauteur obtenue en posant [finger] sur la corde [stringMidi].
  int midiFor({required int stringMidi, required int finger}) {
    assert(finger >= 0 && finger <= 4, 'les doigts vont de 0 a 4');
    return stringMidi + semitones[finger];
  }

  /// 1-2 ton, 2-3 demi-ton, 3-4 ton. Sur la corde de re : re mi fa# sol la.
  ///
  /// C'est la main du mode majeur, et la premiere que l'enfant a apprise.
  static const FingerPattern deuxTroisSerres = FingerPattern(
    id: 'doigts-2-3-serres',
    label: '2-3 serres',
    semitones: <int>[0, 2, 4, 5, 7],
  );

  /// 1-2 demi-ton. Sur la corde de re : re mi fa sol la. La main du mineur.
  static const FingerPattern unDeuxSerres = FingerPattern(
    id: 'doigts-1-2-serres',
    label: '1-2 serres',
    semitones: <int>[0, 2, 3, 5, 7],
  );

  /// 3-4 demi-ton. Sur la corde de re : re mi fa# sol# la.
  ///
  /// Le troisieme doigt monte : c'est l'ecartement que les eleves fuient, et
  /// celui qui fait les fausses notes de la quatrieme annee.
  static const FingerPattern troisQuatreSerres = FingerPattern(
    id: 'doigts-3-4-serres',
    label: '3-4 serres',
    semitones: <int>[0, 2, 4, 6, 7],
  );

  /// 0-1 demi-ton. Sur la corde de re : re mib fa sol la. Premier doigt bas.
  static const FingerPattern zeroUnSerres = FingerPattern(
    id: 'doigts-0-1-serres',
    label: '0-1 serres',
    semitones: <int>[0, 1, 3, 5, 7],
  );

  /// Les quatre ecartements de la premiere position, dans l'ordre ou ils
  /// s'apprennent.
  static const List<FingerPattern> premierePosition = <FingerPattern>[
    deuxTroisSerres,
    unDeuxSerres,
    troisQuatreSerres,
    zeroUnSerres,
  ];
}

/// Une suite de doigts a jouer, independante de la corde et de l'ecartement.
///
/// C'est l'unite de Sevcik : le motif est fixe, on le promene sur les quatre
/// cordes et on change l'ecartement. Deux variables, et la combinatoire fait
/// le reste -- d'ou un catalogue entier a partir de trois motifs.
///
/// **Piege a connaitre : le quatrieme doigt d'une corde donne la meme hauteur
/// que la corde a vide suivante.** Un motif qui finit sur le quatrieme doigt
/// et s'enchaine sur la corde du dessus produit donc deux notes identiques a
/// la suite, et le detecteur d'attaques n'en verra qu'une. Les motifs ci-
/// dessous l'evitent, et un test du catalogue le verifie.
class FingerMotif {
  const FingerMotif({
    required this.id,
    required this.label,
    required this.fingers,
  });

  final String id;
  final String label;

  /// Les doigts, dans l'ordre. 0 vaut corde a vide.
  final List<int> fingers;

  /// Le motif joue sur chaque corde de [strings], dans l'ordre.
  List<int> midis({
    required FingerPattern pattern,
    required List<int> strings,
  }) {
    final List<int> notes = <int>[];
    for (final int corde in strings) {
      for (final int doigt in fingers) {
        notes.add(pattern.midiFor(stringMidi: corde, finger: doigt));
      }
    }
    return notes;
  }

  int noteCount(int stringCount) => fingers.length * stringCount;

  /// La suite des doigts, montee puis descente.
  static const FingerMotif enLigne = FingerMotif(
    id: 'motif-en-ligne',
    label: '0 1 2 3 4 3 2 1',
    fingers: <int>[0, 1, 2, 3, 4, 3, 2, 1],
  );

  /// Chaque doigt, puis la corde a vide.
  ///
  /// **Le seul exercice ou l'application ne peut pas se tromper.** Une corde a
  /// vide ne peut pas etre jouee faux : elle donne donc a l'oreille -- et au
  /// `StringDriftMonitor` -- une reference gratuite toutes les deux notes. Ce
  /// qui est un bon exercice de violon est ici aussi la mesure la plus fiable
  /// dont l'application dispose.
  static const FingerMotif verification = FingerMotif(
    id: 'motif-verification',
    label: '1 0 2 0 3 0 4 0',
    fingers: <int>[1, 0, 2, 0, 3, 0, 4, 0],
  );

  /// Les doigts par tierces brisees.
  static const FingerMotif enTierces = FingerMotif(
    id: 'motif-en-tierces',
    label: '0 2 1 3 2 4 3 1',
    fingers: <int>[0, 2, 1, 3, 2, 4, 3, 1],
  );

  static const List<FingerMotif> all = <FingerMotif>[
    enLigne,
    verification,
    enTierces,
  ];
}
