import '../music/meter.dart';
import '../music/passage.dart';
import '../music/score_note.dart';
import 'imported_piece.dart';
import 'xml_reader.dart';

/// Un fichier qu'on ne sait pas lire comme une partition.
///
/// Le message s'adresse a l'utilisateur : il dit quoi faire, pas ce qui a
/// casse.
class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lit une partition MusicXML (`score-partwise`) et en tire un morceau.
///
/// **L'application ne lit pas les photos.** La reconnaissance optique reste
/// hors d'elle (plan, lot H6) : une lecture a 95 % n'est pas utile a 95 %, elle
/// est nuisible, car l'application reprocherait a l'enfant une faute qu'elle
/// aurait inventee. MuseScore, Audiveris ou PlayScore font la lecture, un
/// adulte la corrige, et c'est le MusicXML corrige qui arrive ici.
///
/// **Une ligne, une voix.** Le graveur et le suiveur ne connaissent qu'une
/// ligne monodique (ADR-007). Ce qui n'y tient pas est reduit, et **dit** :
///
/// - plusieurs parties : seule la premiere est lue ;
/// - une double corde : seule la note aigue est gardee, c'est la melodie ;
/// - une seconde voix, une seconde portee : ignorees ;
/// - une appoggiature, une petite note : ignoree, elle n'a pas de duree ;
/// - une note liee a la suivante de meme hauteur ne fait qu'un son, donc
///   qu'une note.
///
/// Les reprises ne sont pas deroulees : le morceau reste dans l'ordre du
/// papier. Rejouer une reprise, c'est revenir en arriere, et revenir en
/// arriere est ce que le suiveur sait faire (ADR-009).
class MusicXmlReader {
  MusicXmlReader._();

  /// Resolution interne, a la noire. 480 se divise par 3 et par 16 : un
  /// triolet de croches et une quadruple croche tombent sur des entiers.
  static const int ticksPerBeat = 480;

  static const int _tempoParDefaut = 80;

  /// Plus grave que le sol de la corde a vide, un violon ne sait pas.
  static const int _solGrave = 55;

  static ImportedPiece read(String source) {
    final XmlElement racine;
    try {
      racine = XmlReader.parse(source);
    } on FormatException {
      throw const ImportException(
        'Ce fichier est abime ou n est pas une partition MusicXML.',
      );
    }
    if (racine.name == 'score-timewise') {
      throw const ImportException(
        'Cette partition est en MusicXML "timewise". Reexporte-la depuis '
        'MuseScore en MusicXML ordinaire.',
      );
    }
    if (racine.name != 'score-partwise') {
      throw const ImportException(
        'Ce fichier n est pas une partition MusicXML.',
      );
    }
    return MusicXmlReader._()._lire(racine);
  }

  final List<ScoreNote> _notes = <ScoreNote>[];
  final List<Bar> _mesures = <Bar>[];
  final Set<String> _liees = <String>{};

  /// Mesures ou quelque chose a ete reduit, par motif.
  final Map<String, Set<int>> _reduit = <String, Set<int>>{};
  final List<String> _avertissements = <String>[];

  int _divisions = 1;
  Meter? _chiffrage;
  int? _armure;
  int? _tempo;
  String? _voix;

  /// Liaisons ouvertes, par numero : une note jouee pendant qu'une liaison est
  /// ouverte est dans le meme archet que la precedente.
  final Set<String> _liaisonsOuvertes = <String>{};

  ImportedPiece _lire(XmlElement racine) {
    final String titre = _titre(racine);
    final String? compositeur = _compositeur(racine);

    final List<XmlElement> parties = racine.childrenNamed('part').toList();
    if (parties.isEmpty) {
      throw const ImportException('Cette partition ne contient aucune partie.');
    }
    if (parties.length > 1) {
      final String nom = _nomDePartie(racine, parties.first) ?? 'la premiere';
      _avertissements.add(
        'La partition contient ${parties.length} parties : seule "$nom" '
        'est lue.',
      );
    }

    int debutMesure = 0;
    int? numeroPrecedent;
    for (final XmlElement mesure in parties.first.childrenNamed('measure')) {
      final int numero = _numero(mesure, numeroPrecedent);
      numeroPrecedent = numero;
      final int duree = _lireMesure(mesure, numero, debutMesure);
      _mesures.add(
        Bar(number: numero, startTicks: debutMesure, durationTicks: duree),
      );
      debutMesure += duree;
    }

    if (_notes.isEmpty) {
      throw const ImportException(
        'Aucune note lisible dans la premiere partie de cette partition.',
      );
    }
    _signalerLesReductions();

    final List<ScoreNote> numerotees = <ScoreNote>[];
    final Set<String> liees = <String>{};
    for (int i = 0; i < _notes.length; i++) {
      final ScoreNote n = _notes[i];
      final String id = 'n${i + 1}';
      if (_liees.contains(n.id)) {
        liees.add(id);
      }
      numerotees.add(n.copyWith(id: id));
    }

    final Passage passage = Passage(
      title: titre,
      notes: numerotees,
      ticksPerBeat: ticksPerBeat,
      writtenTempoBpm: _tempo ?? _tempoParDefaut,
      meter: _chiffrage,
      keyFifths: _armure,
      bars: _mesures,
    );
    return ImportedPiece(
      id: _identifiant(titre, numerotees),
      title: titre,
      composer: compositeur,
      passage: passage,
      slurredInto: liees,
      warnings: List<String>.unmodifiable(_avertissements),
    );
  }

  /// Lit une mesure et rend sa duree, en ticks.
  int _lireMesure(XmlElement mesure, int numero, int debut) {
    // Position dans la mesure, en divisions du fichier. `backup` et `forward`
    // la deplacent : c'est ainsi que MusicXML ecrit plusieurs voix.
    int curseur = 0;
    int fin = 0;
    for (final XmlElement e in mesure.children) {
      switch (e.name) {
        case 'attributes':
          _lireAttributs(e, numero);
        case 'direction':
          _lireTempo(e);
        case 'sound':
          _tempoDuSon(e);
        case 'backup':
          curseur -= _duree(e);
        case 'forward':
          curseur += _duree(e);
        case 'note':
          curseur = _lireNote(e, numero, debut, curseur);
      }
      if (curseur > fin) {
        fin = curseur;
      }
    }
    final int ticks = _enTicks(fin, numero);
    if (ticks > 0) {
      return ticks;
    }
    // Une mesure vide, sans meme un silence ecrit : on lui rend la duree que
    // son chiffrage lui donne, pour ne pas la faire disparaitre.
    return (_chiffrage ?? const Meter(4, 4)).ticksPerMeasure(ticksPerBeat);
  }

  void _lireAttributs(XmlElement attributs, int numero) {
    final int? divisions = int.tryParse(attributs.childText('divisions') ?? '');
    if (divisions != null && divisions > 0) {
      _divisions = divisions;
    }
    final int? quintes = int.tryParse(attributs.path('key/fifths')?.text ?? '');
    if (quintes != null) {
      if (_armure == null) {
        _armure = quintes;
      } else if (quintes != _armure) {
        _avertissements.add(
          'Changement d armure mesure $numero : la partition garde celle du '
          'debut, les alterations restent justes.',
        );
      }
    }
    final XmlElement? temps = attributs.child('time');
    if (temps != null) {
      final int? b = int.tryParse(temps.childText('beats') ?? '');
      final int? t = int.tryParse(temps.childText('beat-type') ?? '');
      if (b != null && t != null && b > 0 && t > 0) {
        final Meter lu = Meter(b, t);
        if (_chiffrage == null) {
          _chiffrage = lu;
        } else if (lu != _chiffrage) {
          _avertissements.add(
            'Changement de mesure mesure $numero ($lu) : la partition garde '
            '$_chiffrage pour grouper les croches.',
          );
        }
      }
    }
  }

  /// Le tempo ecrit : l'attribut `sound/@tempo` s'il existe, sinon le
  /// metronome imprime. Seul le premier compte, c'est le tempo du morceau.
  void _lireTempo(XmlElement direction) {
    if (_tempo != null) {
      return;
    }
    final XmlElement? son = direction.child('sound');
    if (son != null) {
      _tempoDuSon(son);
      if (_tempo != null) {
        return;
      }
    }
    final XmlElement? metronome = direction.path('direction-type/metronome');
    if (metronome == null) {
      return;
    }
    final double? parMinute =
        double.tryParse(metronome.childText('per-minute') ?? '');
    final double? valeur = switch (metronome.childText('beat-unit')) {
      'whole' => 4,
      'half' => 2,
      'quarter' => 1,
      'eighth' => 0.5,
      '16th' => 0.25,
      _ => null,
    };
    if (parMinute == null || valeur == null) {
      return;
    }
    // Un point allonge l'unite de moitie : noire pointee = 94 vaut 141 a la
    // noire, ce qui est la seule unite que le reste de l'application connait.
    final bool pointe = metronome.child('beat-unit-dot') != null;
    _tempo = (parMinute * valeur * (pointe ? 1.5 : 1)).round();
  }

  void _tempoDuSon(XmlElement son) {
    // MusicXML definit `tempo` en noires par minute, quel que soit le
    // chiffrage.
    final double? tempo = double.tryParse(son.attributes['tempo'] ?? '');
    if (_tempo == null && tempo != null && tempo > 0) {
      _tempo = tempo.round();
    }
  }

  /// Lit une note et rend la nouvelle position du curseur.
  int _lireNote(XmlElement note, int numero, int debutMesure, int curseur) {
    if (note.child('grace') != null) {
      _reduire('grace', numero);
      return curseur;
    }
    if (note.child('cue') != null) {
      return curseur;
    }
    final int duree = _duree(note);
    final bool accord = note.child('chord') != null;
    final int apres = accord ? curseur : curseur + duree;

    final String voix = note.childText('voice') ?? '1';
    final String portee = note.childText('staff') ?? '1';
    if (portee != '1') {
      _reduire('portee', numero);
      return apres;
    }
    if (note.child('rest') != null) {
      return apres;
    }
    _voix ??= voix;
    if (voix != _voix) {
      _reduire('voix', numero);
      return apres;
    }
    final int? midi = _hauteur(note.child('pitch'));
    if (midi == null) {
      // Une note sans hauteur (percussion, note non pitchee) ne se joue pas
      // au violon. Elle occupe sa place, rien de plus.
      return apres;
    }
    if (midi < _solGrave) {
      _reduire('grave', numero);
    }

    // Un accord partage la position de la note qui le precede : `curseur`
    // pointe deja apres elle.
    final int debutNote = accord ? curseur - _dureeDeLaDerniere : curseur;
    final int onset = debutMesure + _enTicks(debutNote, numero);
    final int ticks = _enTicks(duree, numero);
    if (ticks <= 0) {
      return apres;
    }

    if (accord) {
      _reduire('accord', numero);
      if (_notes.isNotEmpty &&
          _notes.last.onsetTicks == onset &&
          midi > _notes.last.midi) {
        // La note aigue d'une double corde est la melodie : c'est elle que
        // l'enfant suit des yeux, et c'est elle que YIN entendra le mieux.
        _notes[_notes.length - 1] = _notes.last.copyWith(midi: midi);
      }
      return apres;
    }
    _dureeDeLaDerniere = duree;

    final bool prolonge = note
        .childrenNamed('tie')
        .any((XmlElement t) => t.attributes['type'] == 'stop');
    final ScoreNote? precedente = _notes.isEmpty ? null : _notes.last;
    if (prolonge &&
        precedente != null &&
        precedente.midi == midi &&
        precedente.offsetTicks == onset) {
      // Une tenue ne fait qu'un son : pour l'oreille, et donc pour le suiveur,
      // ce n'est pas une note de plus.
      _notes[_notes.length - 1] =
          precedente.copyWith(durationTicks: precedente.durationTicks + ticks);
      _lireLiaisons(note, null);
      return apres;
    }

    final String id = 'brut${_notes.length}';
    _notes.add(
      ScoreNote(
        id: id,
        midi: midi,
        onsetTicks: onset,
        durationTicks: ticks,
        measure: numero,
      ),
    );
    _lireLiaisons(note, id);
    return apres;
  }

  /// Duree en divisions de la derniere note posee, pour placer un accord.
  int _dureeDeLaDerniere = 0;

  void _lireLiaisons(XmlElement note, String? id) {
    if (id != null && _liaisonsOuvertes.isNotEmpty) {
      _liees.add(id);
    }
    for (final XmlElement notations in note.childrenNamed('notations')) {
      for (final XmlElement l in notations.childrenNamed('slur')) {
        final String numero = l.attributes['number'] ?? '1';
        switch (l.attributes['type']) {
          case 'start':
            _liaisonsOuvertes.add(numero);
          case 'stop':
            _liaisonsOuvertes.remove(numero);
        }
      }
    }
  }

  static const Map<String, int> _degres = <String, int>{
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };

  int? _hauteur(XmlElement? pitch) {
    if (pitch == null) {
      return null;
    }
    final int? degre = _degres[pitch.childText('step')];
    final int? octave = int.tryParse(pitch.childText('octave') ?? '');
    if (degre == null || octave == null) {
      return null;
    }
    // Une alteration peut etre fractionnaire (quart de ton) : on arrondit au
    // demi-ton, le seul grain que la partition sache ecrire.
    final double alteration =
        double.tryParse(pitch.childText('alter') ?? '') ?? 0;
    return (octave + 1) * 12 + degre + alteration.round();
  }

  int _duree(XmlElement e) => int.tryParse(e.childText('duration') ?? '') ?? 0;

  int _enTicks(int divisions, int numero) {
    final int produit = divisions * ticksPerBeat;
    if (produit % _divisions != 0) {
      _reduire('arrondi', numero);
    }
    return (produit / _divisions).round();
  }

  void _reduire(String motif, int numero) {
    (_reduit[motif] ??= <int>{}).add(numero);
  }

  void _signalerLesReductions() {
    const Map<String, String> messages = <String, String>{
      'accord': 'Doubles cordes : seule la note aigue est suivie',
      'voix': 'Seconde voix ignoree',
      'portee': 'Seconde portee ignoree',
      'grace': 'Petites notes ignorees',
      'arrondi': 'Rythmes arrondis',
      'grave': 'Notes plus graves que le sol a vide : est-ce bien une partie '
          'de violon ?',
    };
    for (final MapEntry<String, String> m in messages.entries) {
      final Set<int>? mesures = _reduit[m.key];
      if (mesures == null || mesures.isEmpty) {
        continue;
      }
      final List<int> triees = mesures.toList()..sort();
      final String liste = triees.length > 6
          ? '${triees.take(6).join(', ')}...'
          : triees.join(', ');
      _avertissements.add(
        '${m.value} (mesure${triees.length > 1 ? 's' : ''} $liste).',
      );
    }
  }

  /// Le numero imprime, ou le suivant du precedent s'il n'est pas un entier
  /// (MuseScore numerote "X1" une mesure coupee en deux).
  static int _numero(XmlElement mesure, int? precedent) {
    final int? lu = int.tryParse(mesure.attributes['number'] ?? '');
    if (lu != null && (precedent == null || lu > precedent)) {
      return lu;
    }
    return (precedent ?? 0) + 1;
  }

  static String _titre(XmlElement racine) {
    final String? oeuvre = racine.path('work/work-title')?.text;
    if (oeuvre != null && oeuvre.isNotEmpty) {
      return oeuvre;
    }
    final String? mouvement = racine.childText('movement-title');
    if (mouvement != null && mouvement.isNotEmpty) {
      return mouvement;
    }
    for (final XmlElement credit in racine.childrenNamed('credit')) {
      final String? type = credit.childText('credit-type');
      final String? mots = credit.childText('credit-words');
      if ((type == null || type == 'title') &&
          mots != null &&
          mots.isNotEmpty) {
        return mots;
      }
    }
    return 'Morceau importe';
  }

  static String? _compositeur(XmlElement racine) {
    final XmlElement? identification = racine.child('identification');
    if (identification == null) {
      return null;
    }
    for (final XmlElement c in identification.childrenNamed('creator')) {
      if (c.attributes['type'] == 'composer' && c.text.isNotEmpty) {
        return c.text;
      }
    }
    return null;
  }

  static String? _nomDePartie(XmlElement racine, XmlElement partie) {
    final String? id = partie.attributes['id'];
    final XmlElement? liste = racine.child('part-list');
    if (id == null || liste == null) {
      return null;
    }
    for (final XmlElement p in liste.childrenNamed('score-part')) {
      if (p.attributes['id'] == id) {
        final String? nom = p.childText('part-name');
        return nom == null || nom.isEmpty ? null : nom;
      }
    }
    return null;
  }

  /// Un identifiant tire du titre et des notes : le meme fichier donne le
  /// meme identifiant, un autre morceau du meme nom un autre.
  static String _identifiant(String titre, List<ScoreNote> notes) {
    // FNV-1a sur 32 bits : deterministe, sans dependance, et bien assez pour
    // distinguer les quelques morceaux d'un eleve.
    int h = 0x811c9dc5;
    void melanger(int v) {
      h = ((h ^ (v & 0xff)) * 0x01000193) & 0xffffffff;
      h = ((h ^ ((v >> 8) & 0xff)) * 0x01000193) & 0xffffffff;
    }

    for (final int c in titre.codeUnits) {
      melanger(c);
    }
    for (final ScoreNote n in notes) {
      melanger(n.midi);
      melanger(n.onsetTicks);
      melanger(n.durationTicks);
    }
    final String nom = titre
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final String court = nom.length > 32 ? nom.substring(0, 32) : nom;
    return '${court.isEmpty ? 'morceau' : court}-'
        '${h.toRadixString(16).padLeft(8, '0')}';
  }
}
