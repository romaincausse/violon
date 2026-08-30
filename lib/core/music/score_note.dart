/// Une note du modele interne, decouplee de tout moteur de rendu.
///
/// C'est la structure pivot de l'application : le generateur de variations,
/// le moteur de notation et la heatmap travaillent tous dessus. Le rendu
/// (Verovio pre-genere aujourd'hui, autre chose demain) reste interchangeable.
class ScoreNote {
  const ScoreNote({
    required this.id,
    required this.midi,
    required this.onsetTicks,
    required this.durationTicks,
    required this.measure,
    this.fingering,
    this.bowing,
  });

  /// Identifiant stable, aligne sur l'id du glyphe dans le SVG Verovio.
  final String id;

  /// Hauteur MIDI. 76 = mi5, corde a vide aigue du violon.
  final int midi;

  /// Position dans le temps, en ticks depuis le debut du morceau.
  final int onsetTicks;

  final int durationTicks;

  /// Numero de mesure, base 1.
  final int measure;

  /// Doigte annote par le professeur, ex. "3".
  final String? fingering;

  /// Coup d'archet, ex. "tire" ou "pousse".
  final String? bowing;

  int get offsetTicks => onsetTicks + durationTicks;

  ScoreNote copyWith({
    String? id,
    int? midi,
    int? onsetTicks,
    int? durationTicks,
    int? measure,
    String? fingering,
    String? bowing,
  }) {
    return ScoreNote(
      id: id ?? this.id,
      midi: midi ?? this.midi,
      onsetTicks: onsetTicks ?? this.onsetTicks,
      durationTicks: durationTicks ?? this.durationTicks,
      measure: measure ?? this.measure,
      fingering: fingering ?? this.fingering,
      bowing: bowing ?? this.bowing,
    );
  }

  @override
  String toString() => 'ScoreNote($id, midi=$midi, m=$measure)';
}
