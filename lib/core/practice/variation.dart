/// Famille de variation de travail.
enum VariationKind {
  /// Rythme modifie : pointe, groupes. Le classique du travail violonistique.
  rhythm,

  /// Coup d'archet : legato, detache, staccato, martele.
  articulation,

  /// Meme passage, tempo different.
  tempo,

  /// Une partie du passage seulement, en avant ou par la fin.
  segmentation,

  /// Memes notes, consigne d'ecoute ou de geste differente.
  attention,

  /// Isolation technique : corde a vide, main gauche seule.
  technique,
}

/// Une facon de rejouer le meme passage.
///
/// L'idee : dix repetitions identiques fatiguent ; dix repetitions
/// differentes du meme passage entretiennent l'attention et fixent mieux.
class Variation {
  const Variation({
    required this.id,
    required this.kind,
    required this.label,
    required this.instruction,
    this.tempoFactor = 1.0,
    this.durationPattern,
    this.noteStart,
    this.noteCount,
  });

  final String id;
  final VariationKind kind;

  /// Titre court affiche en grand, ex. "Rythme pointe".
  final String label;

  /// Consigne d'une ligne, ex. "Long-court, long-court".
  final String instruction;

  /// Multiplicateur applique au tempo de travail.
  final double tempoFactor;

  /// Multiplicateurs de duree appliques cycliquement aux notes.
  /// `[1.5, 0.5]` transforme des croches egales en rythme pointe.
  final List<double>? durationPattern;

  /// Bornes du sous-segment, pour les variations de segmentation.
  final int? noteStart;
  final int? noteCount;

  bool get isPartial => noteStart != null && noteCount != null;

  @override
  String toString() => 'Variation($id)';
}
