import 'dart:math' as math;

/// Ce que vaut une pulsation tenue seule.
class PulseResult {
  const PulseResult({
    required this.heldBpm,
    required this.driftPercent,
    required this.jitterMs,
    required this.score,
  });

  /// Le tempo reellement tenu, d'apres l'ecart median entre deux attaques.
  final double heldBpm;

  /// De combien il a derive, en pour cent du tempo donne. Positif : il a
  /// presse.
  final double driftPercent;

  /// L'irregularite : l'ecart median d'une attaque a la suivante, autour du
  /// temps tenu.
  final int jitterMs;

  /// Sur cent : 100, c'est le tempo donne et une regularite d'horloge.
  final int score;
}

/// Le tempo cache (jeu G3) : quatre clics, puis le silence, et il continue
/// seul.
///
/// **La pulsation interieure**, que le metronome empeche justement de
/// travailler : avec lui on suit, sans lui on tient. Les clics ne sonnent
/// qu'avant qu'il joue ; le micro ne s'ouvre qu'apres (ADR-008).
///
/// **Juger est strict, comme pour le rythme** (ADR-010), mais sur deux
/// choses seulement : le tempo tenu par rapport a celui donne, et la
/// regularite d'une attaque a l'autre. Les hauteurs ne comptent pas : il
/// peut jouer une corde a vide.
class PulseGame {
  PulseGame({required this.bpm, this.beats = 8, int best = 0}) : _best = best;

  /// Le tempo donne par les clics, a la noire.
  final int bpm;

  /// Combien de temps il joue seul.
  final int beats;

  int _best;

  /// Le meilleur score.
  int get best => _best;

  /// La duree d'un temps, en millisecondes.
  double get beatMs => 60000 / bpm;

  /// Juge les attaques entendues, en millisecondes sur l'horloge du micro.
  /// Rend `null` s'il y en a trop peu pour parler de tempo.
  PulseResult? judge(List<int> onsetsMs) {
    // Deux attaques plus proches qu'un demi-temps sont le meme coup
    // d'archet entendu deux fois.
    final List<int> a = <int>[];
    for (final int t in List<int>.of(onsetsMs)..sort()) {
      if (a.isEmpty || t - a.last >= beatMs / 2) {
        a.add(t);
      }
    }
    if (a.length < 4) {
      return null;
    }
    final List<double> ecarts = <double>[
      for (int i = 1; i < a.length; i++) (a[i] - a[i - 1]).toDouble(),
    ];
    final double ecart = _mediane(ecarts);
    final double tenu = 60000 / ecart;
    final double derive = (tenu - bpm) / bpm * 100;
    final double jitter = _mediane(<double>[
      for (final double e in ecarts) (e - ecart).abs(),
    ]);
    final int score =
        (100 - 2 * derive.abs() - 100 * jitter / ecart).round().clamp(0, 100);
    _best = math.max(_best, score);
    return PulseResult(
      heldBpm: tenu,
      driftPercent: derive,
      jitterMs: jitter.round(),
      score: score,
    );
  }

  static double _mediane(List<double> v) {
    final List<double> s = List<double>.of(v)..sort();
    final int m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }
}
