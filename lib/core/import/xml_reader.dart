/// Un element XML : son nom, ses attributs, ses enfants et son texte.
///
/// **Un arbre, pas un flux.** Un fichier MusicXML de morceau d'eleve pese
/// quelques centaines de kilo-octets au plus ; le lire en entier puis le
/// parcourir est plus simple a raisonner qu'un lecteur evenementiel, et le
/// cout ne se voit pas.
class XmlElement {
  XmlElement(this.name, this.attributes);

  final String name;
  final Map<String, String> attributes;
  final List<XmlElement> children = <XmlElement>[];
  final StringBuffer _text = StringBuffer();

  /// Le texte porte directement par l'element, sans celui de ses enfants,
  /// debarrasse des blancs de mise en forme.
  String get text => _text.toString().trim();

  /// Le premier enfant de ce nom, ou `null`.
  XmlElement? child(String name) {
    for (final XmlElement c in children) {
      if (c.name == name) {
        return c;
      }
    }
    return null;
  }

  /// Tous les enfants de ce nom, dans l'ordre du document.
  Iterable<XmlElement> childrenNamed(String name) =>
      children.where((XmlElement c) => c.name == name);

  /// Le texte d'un enfant, ou `null` s'il n'existe pas.
  String? childText(String name) => child(name)?.text;

  /// Suit un chemin d'enfants, `'pitch/step'` par exemple.
  XmlElement? path(String chemin) {
    XmlElement? courant = this;
    for (final String etape in chemin.split('/')) {
      courant = courant?.child(etape);
      if (courant == null) {
        return null;
      }
    }
    return courant;
  }

  @override
  String toString() => '<$name>';
}

/// Lecteur XML minimal, en Dart pur.
///
/// **Pourquoi pas un paquet.** `lib/core/` n'en importe aucun (regle 1 du
/// CLAUDE.md), et MusicXML n'utilise qu'un sous-ensemble sage de XML :
/// elements, attributs, texte, entites predefinies et numeriques,
/// commentaires, `CDATA`, un prologue et une declaration `DOCTYPE`. Les
/// espaces de noms, les entites declarees dans une DTD interne et la
/// validation n'y servent pas : les ignorer est un choix, pas un oubli.
///
/// Leve une [FormatException] sur un document mal forme, avec la position :
/// un fichier corrompu doit dire ou, pas planter plus loin.
class XmlReader {
  XmlReader._(this._s);

  final String _s;
  int _i = 0;

  /// Lit [source] et rend l'element racine.
  static XmlElement parse(String source) {
    final XmlReader r = XmlReader._(source);
    return r._document();
  }

  XmlElement _document() {
    // Un BOM en tete est courant dans les fichiers exportes sous Windows.
    if (_s.startsWith('﻿')) {
      _i = 1;
    }
    _prologue();
    if (_i >= _s.length || _s[_i] != '<') {
      throw _erreur('element racine attendu');
    }
    final XmlElement racine = _element();
    _prologue();
    if (_i < _s.length) {
      throw _erreur('contenu apres l element racine');
    }
    return racine;
  }

  /// Blancs, declaration XML, instructions, commentaires et DOCTYPE.
  void _prologue() {
    while (true) {
      _blancs();
      if (_commence('<?')) {
        _jusqua('?>');
      } else if (_commence('<!--')) {
        _jusqua('-->');
      } else if (_commence('<!DOCTYPE')) {
        _doctype();
      } else {
        return;
      }
    }
  }

  /// Saute une declaration DOCTYPE, sous-ensemble interne compris : MusicXML
  /// en porte une, et son contenu ne nous apprend rien.
  void _doctype() {
    int profondeur = 0;
    while (_i < _s.length) {
      final String c = _s[_i++];
      if (c == '[') {
        profondeur++;
      } else if (c == ']') {
        profondeur--;
      } else if (c == '>' && profondeur <= 0) {
        return;
      }
    }
    throw _erreur('DOCTYPE non termine');
  }

  XmlElement _element() {
    _attendre('<');
    final String nom = _nom();
    final Map<String, String> attributs = <String, String>{};
    while (true) {
      _blancs();
      if (_commence('/>')) {
        return XmlElement(nom, attributs);
      }
      if (_commence('>')) {
        break;
      }
      final String cle = _nom();
      _blancs();
      _attendre('=');
      _blancs();
      attributs[cle] = _valeur();
    }

    final XmlElement element = XmlElement(nom, attributs);
    while (true) {
      if (_i >= _s.length) {
        throw _erreur('<$nom> non ferme');
      }
      if (_commence('</')) {
        final String fin = _nom();
        if (fin != nom) {
          throw _erreur('</$fin> ferme <$nom>');
        }
        _blancs();
        _attendre('>');
        return element;
      }
      if (_commence('<!--')) {
        _jusqua('-->');
      } else if (_commence('<![CDATA[')) {
        final int debut = _i;
        _jusqua(']]>');
        element._text.write(_s.substring(debut, _i - 3));
      } else if (_commence('<?')) {
        _jusqua('?>');
      } else if (_s[_i] == '<') {
        element.children.add(_element());
      } else {
        final int debut = _i;
        while (_i < _s.length && _s[_i] != '<') {
          _i++;
        }
        element._text.write(_entites(_s.substring(debut, _i)));
      }
    }
  }

  String _valeur() {
    if (_i >= _s.length) {
      throw _erreur('valeur d attribut attendue');
    }
    final String guillemet = _s[_i];
    if (guillemet != '"' && guillemet != "'") {
      throw _erreur('guillemet attendu');
    }
    _i++;
    final int fin = _s.indexOf(guillemet, _i);
    if (fin < 0) {
      throw _erreur('attribut non termine');
    }
    final String brut = _s.substring(_i, fin);
    _i = fin + 1;
    return _entites(brut);
  }

  String _nom() {
    final int debut = _i;
    while (_i < _s.length && !_estSeparateur(_s.codeUnitAt(_i))) {
      _i++;
    }
    if (_i == debut) {
      throw _erreur('nom attendu');
    }
    return _s.substring(debut, _i);
  }

  static bool _estSeparateur(int c) =>
      c == 0x20 || // espace
      c == 0x09 ||
      c == 0x0A ||
      c == 0x0D ||
      c == 0x3C || // <
      c == 0x3E || // >
      c == 0x2F || // /
      c == 0x3D; // =

  void _blancs() {
    while (_i < _s.length && ' \t\r\n'.contains(_s[_i])) {
      _i++;
    }
  }

  bool _commence(String motif) {
    if (_s.startsWith(motif, _i)) {
      _i += motif.length;
      return true;
    }
    return false;
  }

  void _attendre(String motif) {
    if (!_commence(motif)) {
      throw _erreur('"$motif" attendu');
    }
  }

  /// Avance juste apres la prochaine occurrence de [motif].
  void _jusqua(String motif) {
    final int fin = _s.indexOf(motif, _i);
    if (fin < 0) {
      throw _erreur('"$motif" attendu avant la fin');
    }
    _i = fin + motif.length;
  }

  static final RegExp _entite = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|\w+);');

  static String _entites(String brut) {
    if (!brut.contains('&')) {
      return brut;
    }
    return brut.replaceAllMapped(_entite, (Match m) {
      final String e = m.group(1)!;
      if (e.startsWith('#x')) {
        return String.fromCharCode(int.parse(e.substring(2), radix: 16));
      }
      if (e.startsWith('#')) {
        return String.fromCharCode(int.parse(e.substring(1)));
      }
      return switch (e) {
        'lt' => '<',
        'gt' => '>',
        'amp' => '&',
        'quot' => '"',
        'apos' => "'",
        // Une entite inconnue viendrait d'une DTD qu'on ne lit pas : on la
        // laisse telle quelle plutot que d'echouer sur un titre.
        _ => m.group(0)!,
      };
    });
  }

  FormatException _erreur(String message) {
    final int ligne =
        '\n'.allMatches(_s.substring(0, _i.clamp(0, _s.length))).length + 1;
    return FormatException('XML ligne $ligne : $message');
  }
}
