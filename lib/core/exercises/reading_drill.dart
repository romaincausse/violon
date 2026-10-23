/// Ce que la lecture rend a chaque hauteur entendue.
enum ReadingEvent {
  /// Rien a dire : pas encore tenu, ou pas encore la bonne.
  none,

  /// La note est lue : on passe a la suivante.
  read,
}

/// Lire une note sur la portee et repondre en la jouant (lot L1).
///
/// Le solfege a sa place sur le violon, pas sur un clavier : l'application
/// grave une note, l'eleve la joue, le micro l'entend. **Une note est lue
/// quand elle est tenue** : la bonne hauteur, a un demi-ton pres, pendant un
/// quart de seconde. Une mauvaise note n'est pas comptee contre lui -- il
/// cherche, c'est le but -- elle ne fait simplement pas avancer.
///
/// **Deterministe** : la suite des notes vient d'une graine, jamais du
/// hasard. Deux notes de suite ne sont jamais la meme.
class ReadingDrill {
  ReadingDrill({
    required List<int> pool,
    int seed = 1,
    this.holdMs = 250,
    this.toleranceCents = 50,
  })  : assert(pool.length >= 2, 'il faut au moins deux notes a lire'),
        pool = List<int>.unmodifiable(pool),
        _etat = seed & 0x7FFFFFFF {
    _suivante();
  }

  /// Les hauteurs MIDI parmi lesquelles tirer.
  final List<int> pool;

  /// Tenue exigee, en millisecondes.
  final int holdMs;

  /// A moins de ca de la note ecrite, c'est elle.
  final double toleranceCents;

  int _etat;
  late int _cible;
  int _lues = 0;
  int? _depuisMs;

  /// La note a lire.
  int get target => _cible;

  /// Combien ont ete lues depuis le debut.
  int get read => _lues;

  /// Une hauteur entendue a [timeMs], en demi-tons MIDI (fractionnaire).
  ReadingEvent hear(double midi, int timeMs) {
    final double ecart = (midi - _cible).abs() * 100;
    if (ecart > toleranceCents) {
      _depuisMs = null;
      return ReadingEvent.none;
    }
    _depuisMs ??= timeMs;
    if (timeMs - _depuisMs! < holdMs) {
      return ReadingEvent.none;
    }
    _lues++;
    _depuisMs = null;
    _suivante();
    return ReadingEvent.read;
  }

  /// Le silence : la tenue repart de zero.
  void rest() => _depuisMs = null;

  /// Un generateur congruentiel, qui suffit a tirer des notes et tient en
  /// une ligne : ce n'est pas de la cryptographie.
  int _tirer() {
    _etat = (_etat * 1103515245 + 12345) & 0x7FFFFFFF;
    return _etat >> 8;
  }

  void _suivante() {
    int n = pool[_tirer() % pool.length];
    int garde = 0;
    while (_lues > 0 && n == _cible && garde++ < 8) {
      n = pool[_tirer() % pool.length];
    }
    _cible = n;
  }
}
