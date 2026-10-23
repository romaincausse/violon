/// Tiens la note (jeu G2) : une note, juste a dix cents pres, aussi
/// longtemps qu'il peut.
///
/// **L'exercice des sons files, en jeu.** Tenir une note juste et egale est
/// ce que tout professeur fait travailler, et ce qu'un enfant trouve le plus
/// ennuyeux : ici le temps tenu se compte, et le record monte.
///
/// **Sans bourdon** : le micro ecoute, et l'application emet ou ecoute,
/// jamais les deux (ADR-008). La justesse se juge par rapport au la mesure
/// sur le violon, pas a 440 (CLAUDE.md, justesse relative).
///
/// **Un ecart bref ne casse pas la tenue** : un changement d'archet ou une
/// oscillation de vibrato qui sort de la marge moins de [graceMs] est
/// pardonne. Au-dela, la tenue s'arrete, et la suivante repart de zero ; le
/// record, lui, reste.
class LongToneGame {
  LongToneGame({
    required this.targetMidi,
    this.toleranceCents = 10,
    this.graceMs = 200,
    int bestMs = 0,
  }) : _bestMs = bestMs;

  final int targetMidi;
  final double toleranceCents;
  final int graceMs;

  int _bestMs;
  int? _debutMs;
  int? _dernierJusteMs;
  double? _cents;

  /// L'ecart de la derniere hauteur entendue, en cents, ou `null`.
  double? get lastCents => _cents;

  /// La tenue en cours, en millisecondes : zero si elle n'a pas commence.
  int currentMs(int nowMs) {
    final int? d = _debutMs;
    final int? j = _dernierJusteMs;
    if (d == null || j == null || nowMs - j > graceMs) {
      return 0;
    }
    return j - d;
  }

  /// La plus longue tenue.
  int get bestMs => _bestMs;

  bool get holding => _debutMs != null;

  /// Une hauteur entendue a [timeMs], en demi-tons MIDI rapportes a l'accord
  /// reel.
  void hear(double midi, int timeMs) {
    final double c = (midi - targetMidi) * 100;
    _cents = c;
    if (c.abs() <= toleranceCents) {
      _expirer(timeMs);
      _debutMs ??= timeMs;
      _dernierJusteMs = timeMs;
      _retenir();
    } else {
      _expirer(timeMs);
    }
  }

  /// Rien d'entendu a [timeMs] : silence ou archet leve.
  void rest(int timeMs) {
    _cents = null;
    _expirer(timeMs);
  }

  /// La tenue s'arrete si rien de juste depuis plus de [graceMs].
  void _expirer(int timeMs) {
    final int? j = _dernierJusteMs;
    if (j != null && timeMs - j > graceMs) {
      _retenir();
      _debutMs = null;
      _dernierJusteMs = null;
    }
  }

  void _retenir() {
    final int? d = _debutMs;
    final int? j = _dernierJusteMs;
    if (d != null && j != null && j - d > _bestMs) {
      _bestMs = j - d;
    }
  }
}
