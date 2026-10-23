import 'dart:math' as math;

import '../follow/performance_features.dart';

/// Ce qu'un archet a fait du son, du point de vue d'un professeur.
enum BowVerdict {
  /// L'energie n'a pas bouge de plus de [EvenBow.maxSpreadDb].
  even,

  /// Le son s'eteint en route : le poids ou la vitesse lache vers la fin.
  fades,

  /// Le son grossit en route : il appuie de plus en plus.
  swells,

  /// Ni l'un ni l'autre, mais il bouge : la vitesse d'archet varie.
  uneven,
}

/// Un archet entendu, du changement d'archet (ou du silence) au suivant.
class BowStroke {
  const BowStroke({
    required this.startMs,
    required this.endMs,
    required this.spreadDb,
    required this.trendDb,
  });

  final int startMs;
  final int endMs;

  /// L'ecart entre le son fort et le son faible du corps de l'archet, en
  /// decibels : du dixieme au neuvieme decile, pour qu'une trame isolee ne
  /// decide pas.
  final double spreadDb;

  /// Le dernier tiers moins le premier, en decibels : negatif quand le son
  /// s'eteint.
  final double trendDb;

  int get durationMs => endMs - startMs;

  BowVerdict get verdict {
    if (spreadDb <= EvenBow.maxSpreadDb) {
      return BowVerdict.even;
    }
    if (trendDb <= -EvenBow.driftDb) {
      return BowVerdict.fades;
    }
    if (trendDb >= EvenBow.driftDb) {
      return BowVerdict.swells;
    }
    return BowVerdict.uneven;
  }
}

/// Le son file (lot K7) : un archet entier, a son egal.
///
/// **On compare l'archet a lui-meme.** Un micro a soixante-dix centimetres ne
/// donne pas de decibels absolus, mais il dit sans faute si le son de la fin
/// de l'archet est plus faible que celui du debut. C'est le seul jugement que
/// l'on porte : ni la hauteur, ni le timbre.
///
/// **Le debut et la fin ne comptent pas** : l'archet qui se met en route et
/// celui qui change de sens font varier l'energie, et c'est normal. On juge
/// le corps de l'archet.
///
/// **Un archet se termine** sur un silence ou sur une attaque -- le creux
/// d'energie d'un changement d'archet en est une (P4).
class EvenBow {
  EvenBow({int bestMs = 0}) : _bestMs = bestMs;

  /// Ce qui ne compte pas au debut de l'archet.
  static const int attackMs = 150;

  /// Ce qui ne compte pas a la fin : le changement d'archet s'annonce.
  static const int releaseMs = 100;

  /// En dessous, ce n'est pas un archet file : pas de verdict.
  static const int minBowMs = 1000;

  /// Au-dela, le son n'est plus egal.
  ///
  /// **Regle sur le banc** : les quarante archets de plus d'une seconde des
  /// prises 01 a 08 vont de 1,7 a 17 dB, mediane 5,9. La moitie passe sous 5 :
  /// un archet d'une seconde est egal des le premier soir, et le record
  /// pousse vers des archets plus longs, ou tenir 5 dB devient difficile.
  static const double maxSpreadDb = 5;

  /// Ce qui fait dire que le son s'eteint ou grossit.
  static const double driftDb = 3;

  int _bestMs;
  int? _debutMs;
  int _dernierMs = 0;
  final List<int> _temps = <int>[];
  final List<double> _niveaux = <double>[];
  BowStroke? _dernier;

  /// Le plus long archet egal, en millisecondes.
  int get bestMs => _bestMs;

  /// Le dernier archet assez long pour etre juge, ou `null`.
  BowStroke? get last => _dernier;

  /// L'archet en cours, en millisecondes : zero au silence.
  int get currentMs {
    final int? d = _debutMs;
    return d == null ? 0 : _dernierMs - d;
  }

  /// Une trame entendue.
  void hear(FeatureFrame f) {
    if (f.rms < PerformanceFeatures.silenceRms) {
      rest();
      return;
    }
    final int? d = _debutMs;
    // Une attaque pendant que l'archet se met en route est la sienne.
    if (f.onset && d != null && f.timeMs - d > attackMs) {
      _finir();
    }
    _debutMs ??= f.timeMs;
    _dernierMs = f.timeMs;
    _temps.add(f.timeMs);
    _niveaux.add(20 * math.log(f.rms) / math.ln10);
  }

  /// Rien d'entendu : l'archet s'arrete.
  void rest() => _finir();

  void _finir() {
    final int? d = _debutMs;
    _debutMs = null;
    if (d != null) {
      final BowStroke? b = _juger(d, _dernierMs);
      if (b != null) {
        _dernier = b;
        if (b.verdict == BowVerdict.even && b.durationMs > _bestMs) {
          _bestMs = b.durationMs;
        }
      }
    }
    _temps.clear();
    _niveaux.clear();
  }

  BowStroke? _juger(int debut, int fin) {
    if (fin - debut < minBowMs) {
      return null;
    }
    final List<double> corps = <double>[
      for (int i = 0; i < _temps.length; i++)
        if (_temps[i] >= debut + attackMs && _temps[i] <= fin - releaseMs)
          _niveaux[i],
    ];
    if (corps.length < 6) {
      return null;
    }
    final List<double> tries = List<double>.of(corps)..sort();
    final double p10 = tries[(tries.length * 0.1).floor()];
    final double p90 = tries[(tries.length * 0.9).floor()];
    final int tiers = corps.length ~/ 3;
    double moyenne(Iterable<double> x) =>
        x.reduce((double a, double b) => a + b) / x.length;
    return BowStroke(
      startMs: debut,
      endMs: fin,
      spreadDb: p90 - p10,
      trendDb: moyenne(corps.skip(corps.length - tiers)) -
          moyenne(corps.take(tiers)),
    );
  }
}
