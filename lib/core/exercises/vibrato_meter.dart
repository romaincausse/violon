import '../follow/performance_features.dart';

/// Ce que le vibrato fait en ce moment : sa vitesse, sa largeur, et s'il est
/// regulier.
class VibratoReading {
  const VibratoReading({
    required this.rateHz,
    required this.amplitudeCents,
    required this.regular,
  });

  /// Oscillations par seconde.
  final double rateHz;

  /// De part et d'autre de la hauteur centrale, en cents.
  final double amplitudeCents;

  /// Les dernieres oscillations ont toutes la meme duree, a
  /// [VibratoMeter.periodTolerance] pres.
  final bool regular;

  /// Oscillations par temps, a [bpm] a la noire.
  double perBeat(int bpm) => rateHz * 60 / bpm;
}

/// Le vibrato (lot K13) : on le mesure sur une note longue -- vitesse,
/// largeur, regularite d'une oscillation a l'autre.
///
/// **Sur les trames du suiveur, pas sur les hauteurs lissees** : une trame
/// toutes les 23 ms voit un vibrato de 7 Hz six fois par oscillation, la ou
/// le lissage, qui en voit trois, sait seulement dire "ca oscille".
///
/// **Autour de la hauteur centrale, pas de la note ecrite** : la justesse est
/// l'affaire d'un autre juge. Un vibrato se mesure par rapport a la hauteur
/// qu'il entoure, prise sur la derniere seconde -- deux oscillations a
/// deux par seconde, assez pour qu'elle ne suive pas le vibrato lui-meme.
///
/// **Le record est la plus longue note vibree regulierement** : des
/// oscillations qui gardent la meme duree, a un quart pres, et une largeur
/// qu'on entend. Une oscillation qui casse la serie la recommence ; le
/// record, lui, reste.
class VibratoMeter {
  VibratoMeter({int bestMs = 0}) : _bestMs = bestMs;

  /// La fenetre de la hauteur centrale.
  static const int centreMs = 1000;

  /// En dessous, l'ecart est du bruit de mesure : on ne change pas de cote.
  static const double hysteresisCents = 4;

  /// Une oscillation plus etroite ne s'entend pas comme un vibrato.
  static const double minAmplitudeCents = 8;

  /// Plus large, c'est un glissando ou une autre note.
  static const double maxAmplitudeCents = 80;

  /// La duree d'une oscillation, rapportee a la mediane des dernieres.
  static const double periodTolerance = 0.25;

  /// Au-dela, ce n'est plus la meme note.
  static const double newNoteCents = 80;

  /// Une serie ne fait un record qu'a partir de trois oscillations.
  ///
  /// **Regle sur le banc** : dans les cinq minutes des prises 01 a 08, sans
  /// vibrato voulu, une hauteur qui ondule lentement fait deux fois une serie
  /// d'une seconde -- deux oscillations a 1,9 par seconde. Trois, elle ne
  /// les tient jamais.
  static const int minCycles = 3;

  int _bestMs;
  final List<(int, double)> _hauteurs = <(int, double)>[];
  double? _centre;
  int _cote = 0;
  double _crete = 0;
  final List<int> _passages = <int>[];
  final List<double> _cretes = <double>[];
  int? _debutRegulier;
  int _demiOscillations = 0;
  int _dernierPassage = 0;

  /// La plus longue note vibree regulierement, en millisecondes.
  int get bestMs => _bestMs;

  /// La serie reguliere en cours, en millisecondes.
  int get regularMs {
    final int? d = _debutRegulier;
    return d == null ? 0 : _dernierPassage - d;
  }

  /// Ce que font les dernieres oscillations, ou `null` s'il n'y en a pas
  /// encore deux.
  VibratoReading? get current {
    final List<int> p = _periodes;
    if (p.length < 2) {
      return null;
    }
    final List<int> dernieres = p.sublist(p.length > 4 ? p.length - 4 : 0);
    final double moyenne =
        dernieres.reduce((int a, int b) => a + b) / dernieres.length;
    final List<double> c = _cretes.sublist(
      _cretes.length > 8 ? _cretes.length - 8 : 0,
    );
    return VibratoReading(
      rateHz: 1000 / moyenne,
      amplitudeCents: c.reduce((double a, double b) => a + b) / c.length,
      regular: regularMs > 0,
    );
  }

  /// Les oscillations entieres, d'un passage au passage de meme sens.
  List<int> get _periodes => <int>[
        for (int i = 2; i < _passages.length; i++)
          _passages[i] - _passages[i - 2],
      ];

  /// Une trame entendue.
  void hear(FeatureFrame f) {
    final double? m = f.midi;
    if (m == null || f.rms < PerformanceFeatures.silenceRms) {
      rest();
      return;
    }
    final double? centre = _centre;
    if (centre != null && (m - centre).abs() * 100 > newNoteCents) {
      rest();
    }
    _hauteurs.add((f.timeMs, m));
    while (_hauteurs.first.$1 < f.timeMs - centreMs) {
      _hauteurs.removeAt(0);
    }
    double somme = 0;
    for (final (int, double) h in _hauteurs) {
      somme += h.$2;
    }
    final double c = somme / _hauteurs.length;
    _centre = c;
    final double ecart = (m - c) * 100;
    if (ecart.abs() > _crete) {
      _crete = ecart.abs();
    }
    final int cote = ecart > hysteresisCents
        ? 1
        : ecart < -hysteresisCents
            ? -1
            : 0;
    if (cote != 0 && cote != _cote) {
      if (_cote != 0) {
        _passage(f.timeMs);
      }
      _cote = cote;
    }
  }

  /// Le vibrato change de cote : une demi-oscillation de plus.
  void _passage(int t) {
    _passages.add(t);
    _cretes.add(_crete);
    _crete = 0;
    _dernierPassage = t;
    final List<int> p = _periodes;
    if (p.isEmpty) {
      return;
    }
    final List<int> recentes =
        List<int>.of(p.sublist(p.length > 5 ? p.length - 5 : 0))..sort();
    final int mediane = recentes[recentes.length ~/ 2];
    final int derniere = p.last;
    final double crete = _cretes.last;
    final bool reguliere =
        (derniere - mediane).abs() <= mediane * periodTolerance &&
            crete >= minAmplitudeCents &&
            crete <= maxAmplitudeCents;
    if (!reguliere) {
      _retenir();
      _debutRegulier = null;
      _demiOscillations = 0;
      return;
    }
    // La serie part du debut de l'oscillation qui vient de se fermer.
    if (_debutRegulier == null) {
      _debutRegulier = _passages[_passages.length - 3];
      _demiOscillations = 2;
    } else {
      _demiOscillations++;
    }
    _retenir();
  }

  void _retenir() {
    if (_demiOscillations >= 2 * minCycles && regularMs > _bestMs) {
      _bestMs = regularMs;
    }
  }

  /// Rien d'entendu, ou une autre note : la note vibree s'arrete.
  void rest() {
    _retenir();
    _hauteurs.clear();
    _centre = null;
    _cote = 0;
    _crete = 0;
    _passages.clear();
    _cretes.clear();
    _debutRegulier = null;
    _demiOscillations = 0;
  }
}
