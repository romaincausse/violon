/// Valeur rythmique d'une note, exprimee en temps (noires).
///
/// Volontairement limitee aux cinq figures qu'un eleve de 4e annee rencontre
/// dans son repertoire. Le point est un modificateur, pas une figure de plus :
/// il multiplie la duree par 1,5, ce qui reste entier pour toutes les valeurs
/// ci-dessous des lors que `ticksPerBeat` est un multiple de 8.
enum NoteValue {
  whole(label: 'Ronde', beats: 4),
  half(label: 'Blanche', beats: 2),
  quarter(label: 'Noire', beats: 1),
  eighth(label: 'Croche', beats: 0.5),
  sixteenth(label: 'Double', beats: 0.25);

  const NoteValue({required this.label, required this.beats});

  /// Nom francais affiche a l'utilisateur.
  final String label;

  /// Duree en temps, un temps valant une noire.
  final double beats;

  /// Initiale de la figure, pour etiqueter une note saisie sans l'allonger :
  /// R, B, N, C, D. Les cinq initiales sont distinctes.
  String get shortLabel => label.substring(0, 1);

  /// Duree en ticks pour une resolution donnee.
  int ticksIn(int ticksPerBeat, {bool dotted = false}) {
    final int plain = (beats * ticksPerBeat).round();
    return dotted ? plain * 3 ~/ 2 : plain;
  }

  /// La figure -- avec ou sans point -- qui vaut **exactement** [ticks].
  ///
  /// Rend `null` si aucune n'y correspond, et c'est tout l'interet de la
  /// fonction. Le modele ne stocke qu'une duree en ticks : c'est le graveur
  /// qui en deduit la tete de note, les crochets et le point. Une duree qui
  /// n'est la duree d'aucune figure se graverait donc quand meme, en affichant
  /// n'importe quoi -- une noire et demie dessinee comme une noire.
  ///
  /// Un generateur d'exercices, qui calcule des durees au lieu de les saisir,
  /// doit donc verifier qu'il tombe sur une figure reelle avant de construire.
  /// Tout se fait en entiers : une tete de note ne doit pas dependre d'un
  /// arrondi.
  static ({NoteValue value, bool dotted})? exactly(
      int ticks, int ticksPerBeat) {
    for (final NoteValue value in NoteValue.values) {
      for (final bool dotted in <bool>[false, true]) {
        if (value.ticksIn(ticksPerBeat, dotted: dotted) == ticks) {
          return (value: value, dotted: dotted);
        }
      }
    }
    return null;
  }
}
