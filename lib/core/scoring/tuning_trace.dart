/// Un point du trace : un ecart a la note attendue, a un instant donne.
class TracePoint {
  const TracePoint({
    required this.timestampMs,
    required this.cents,
    this.midi,
  });

  final int timestampMs;

  /// Ecart a la note attendue. Negatif si trop grave.
  final double cents;

  /// La hauteur reellement entendue, en numero MIDI fractionnaire.
  ///
  /// **Facultative, parce que le trace sait vivre sans.** Le ruban d'ecart
  /// ne dessine qu'un ecart : savoir de quelle note on s'ecarte ne lui sert a
  /// rien. C'est l'echelle des notes qui en a besoin, pour poser le trait
  /// entre deux noms plutot qu'autour d'un axe.
  final double? midi;
}

/// Les dernieres secondes de justesse, pour etre dessinees.
///
/// **Ce que le score ne raconte pas.** Une note vaut quatre-vingt-dix ; on ne
/// sait pas si elle a ete posee juste et tenue, ou attaquee basse puis
/// rattrapee. C'est pourtant deux gestes differents, et le second est celui
/// qu'un professeur corrige. Le trace le montre d'un coup d'oeil.
///
/// **Fenetre glissante sur le temps, pas sur le nombre de points.** Garder les
/// N dernieres mesures paraitrait plus simple, mais le micro perd des trames
/// sous charge : le trace se dilaterait et se contracterait sans que rien
/// n'ait change dans le jeu. On borne donc par la duree, et le nombre de
/// points sert seulement de garde-fou memoire.
class TuningTrace {
  TuningTrace({this.windowMs = 4000, this.maxPoints = 400})
      : assert(windowMs > 0, 'une fenetre dure un temps positif'),
        assert(maxPoints > 1, 'il faut de quoi tracer une ligne');

  /// Duree affichee, en millisecondes.
  final int windowMs;

  /// Garde-fou : au-dela, les plus anciens points sortent meme s'ils sont
  /// dans la fenetre.
  final int maxPoints;

  final List<TracePoint> _points = <TracePoint>[];

  /// Les points retenus, du plus ancien au plus recent.
  List<TracePoint> get points => List<TracePoint>.unmodifiable(_points);

  bool get isEmpty => _points.isEmpty;

  /// Instant du point le plus recent, ou `null`.
  int? get latestMs => _points.isEmpty ? null : _points.last.timestampMs;

  void add(int timestampMs, double cents, {double? midi}) {
    // Un horodatage qui recule signale une nouvelle prise : le micro
    // recommence a zero. Garder l'ancien trace dessinerait un aller-retour
    // dans le temps.
    if (_points.isNotEmpty && timestampMs < _points.last.timestampMs) {
      _points.clear();
    }
    _points.add(
      TracePoint(timestampMs: timestampMs, cents: cents, midi: midi),
    );
    _elaguer();
  }

  void _elaguer() {
    final int limite = _points.last.timestampMs - windowMs;
    while (_points.length > 1 && _points.first.timestampMs < limite) {
      _points.removeAt(0);
    }
    while (_points.length > maxPoints) {
      _points.removeAt(0);
    }
  }

  void reset() => _points.clear();
}
