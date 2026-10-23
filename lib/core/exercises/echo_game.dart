/// L'echo (jeu G1) : l'application joue un motif, il le rejoue d'oreille.
///
/// **Le motif grandit d'une note a chaque reussite**, comme un jeu de
/// memoire, mais au violon : c'est l'oreille et la main qui travaillent, pas
/// un ecran a toucher. **Une erreur ne remet jamais a zero** : le motif
/// raccourcit d'une seule note, et le record, lui, ne redescend pas.
///
/// **Toujours le meme motif qui s'allonge**, tire d'une graine : on retrouve
/// le debut qu'on connait deja, et seule la derniere note est nouvelle.
/// Deux notes de suite ne sont jamais les memes -- elles ne se
/// distingueraient que par le coup d'archet -- et un intervalle ne depasse
/// pas la quinte : un motif chantable, pas une devinette.
class EchoGame {
  EchoGame({
    required List<int> pool,
    int seed = 1,
    this.startLength = 2,
    this.maxLength = 12,
    int best = 0,
  })  : assert(pool.length >= 3, 'il faut au moins trois notes'),
        pool = List<int>.unmodifiable(pool),
        _best = best,
        _length = startLength,
        _etat = seed & 0x7FFFFFFF {
    _suite.add(this.pool[_tirer() % this.pool.length]);
    while (_suite.length < maxLength) {
      final int avant = _suite.last;
      final List<int> voisines = <int>[
        for (final int p in this.pool)
          if (p != avant && (p - avant).abs() <= 7) p,
      ];
      final List<int> choix = voisines.isEmpty
          ? <int>[
              for (final int p in this.pool)
                if (p != avant) p
            ]
          : voisines;
      _suite.add(choix[_tirer() % choix.length]);
    }
  }

  /// Les notes parmi lesquelles le motif est tire.
  final List<int> pool;
  final int startLength;
  final int maxLength;

  final List<int> _suite = <int>[];
  int _length;
  int _best;
  int _etat;

  /// Combien de notes dans le motif en cours.
  int get length => _length;

  /// Le plus long motif rejoue juste.
  int get best => _best;

  /// Le motif a rejouer.
  List<int> get motif => List<int>.unmodifiable(_suite.sublist(0, _length));

  /// Combien des premieres notes jouees sont justes : ce qu'on lui dit,
  /// plutot que "faux".
  int matchedPrefix(List<int> played) {
    final List<int> m = motif;
    int k = 0;
    while (k < m.length && k < played.length && played[k] == m[k]) {
      k++;
    }
    return k;
  }

  /// Ce qu'il a joue. Rend vrai s'il a rejoue le motif.
  bool judge(List<int> played) {
    final bool juste =
        played.length == _length && matchedPrefix(played) == _length;
    if (juste) {
      if (_length > _best) {
        _best = _length;
      }
      if (_length < maxLength) {
        _length++;
      }
    } else if (_length > startLength) {
      _length--;
    }
    return juste;
  }

  int _tirer() {
    _etat = (_etat * 1103515245 + 12345) & 0x7FFFFFFF;
    return _etat >> 8;
  }
}

/// Les notes entendues, une par une, a partir des hauteurs du micro.
///
/// **Une note compte quand elle est tenue** un instant, a un demi-ton pres :
/// un glissando entre deux notes n'en ajoute pas une troisieme. Deux notes
/// de suite a la meme hauteur n'en font qu'une -- le motif n'en contient
/// jamais.
class HeardNotes {
  HeardNotes({this.holdMs = 150, this.toleranceCents = 50});

  final int holdMs;
  final double toleranceCents;

  final List<int> _notes = <int>[];
  int? _candidate;
  int? _depuisMs;
  int? _derniereMs;

  List<int> get notes => List<int>.unmodifiable(_notes);

  /// Le dernier instant ou une note a ete entendue, ou `null`.
  int? get lastHeardMs => _derniereMs;

  /// Une hauteur entendue a [timeMs], en demi-tons MIDI (fractionnaire).
  void hear(double midi, int timeMs) {
    final int proche = midi.round();
    if ((midi - proche).abs() * 100 > toleranceCents) {
      _candidate = null;
      return;
    }
    if (proche != _candidate) {
      _candidate = proche;
      _depuisMs = timeMs;
    }
    _derniereMs = timeMs;
    if (timeMs - _depuisMs! >= holdMs &&
        (_notes.isEmpty || _notes.last != proche)) {
      _notes.add(proche);
    }
  }

  /// Le silence entre deux notes : la note suivante repart de zero.
  void rest() => _candidate = null;
}
