import 'dart:convert';
import 'dart:typed_data';

import 'imported_piece.dart';
import 'musicxml_reader.dart';

/// Un fichier choisi par l'utilisateur : son nom et son contenu brut.
class PickedDocument {
  const PickedDocument({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// La frontiere avec le selecteur de fichiers du systeme.
///
/// Comme le micro et le stockage : `lib/core/` dit ce qu'il attend -- un nom
/// et des octets --, `lib/platform/` sait l'obtenir. Rend `null` si
/// l'utilisateur renonce.
abstract class DocumentPicker {
  Future<PickedDocument?> pick();
}

/// Un selecteur qui rend ce qu'on lui a donne, pour les tests.
class FakeDocumentPicker implements DocumentPicker {
  FakeDocumentPicker([this.document]);

  PickedDocument? document;
  int picks = 0;

  @override
  Future<PickedDocument?> pick() async {
    picks++;
    return document;
  }
}

/// Decompresse un flux `deflate` brut, celui d'une archive zip.
///
/// Injectee : la decompression vit dans `dart:io`, que `lib/core/` n'importe
/// pas pour rester lisible sous Flutter Web.
typedef Inflate = List<int> Function(List<int> compressed);

/// Transforme un fichier choisi en morceau.
///
/// **Deux formes du meme format.** MuseScore exporte par defaut en `.mxl`,
/// une archive zip qui contient le MusicXML ; les autres outils ecrivent
/// souvent le `.musicxml` en clair. On reconnait l'archive a sa signature, pas
/// a son extension : un fichier renomme ou un nom perdu en route ne doit pas
/// faire echouer l'import.
class PieceImporter {
  const PieceImporter({required this.inflate});

  final Inflate inflate;

  /// Au-dela, ce n'est pas une partie de violon : c'est une erreur de
  /// fichier, et la lire bloquerait l'ecran pour rien.
  static const int maxBytes = 20 * 1024 * 1024;

  ImportedPiece read(PickedDocument document) {
    final Uint8List octets = document.bytes;
    if (octets.length > maxBytes) {
      throw const ImportException(
        'Ce fichier est bien trop gros pour une partition.',
      );
    }
    final bool archive = octets.length >= 4 &&
        octets[0] == 0x50 &&
        octets[1] == 0x4B &&
        octets[2] == 0x03 &&
        octets[3] == 0x04;
    if (archive) {
      return MusicXmlReader.read(_texte(_partitionDeLArchive(octets)));
    }
    return MusicXmlReader.read(_texte(octets));
  }

  /// La partition principale d'un `.mxl`.
  ///
  /// `META-INF/container.xml` la designe ; a defaut, le premier fichier XML
  /// hors de `META-INF`.
  List<int> _partitionDeLArchive(Uint8List octets) {
    final Map<String, _Entree> entrees;
    try {
      entrees = _lireLeRepertoire(octets);
    } on RangeError {
      throw const ImportException('Cette archive .mxl est abimee.');
    }
    String? principale;
    final _Entree? conteneur = entrees['META-INF/container.xml'];
    if (conteneur != null) {
      final String xml = _texte(_extraire(octets, conteneur));
      principale = RegExp(r'full-path\s*=\s*"([^"]+)"').firstMatch(xml)?[1];
    }
    principale ??= entrees.keys.cast<String?>().firstWhere(
          (String? nom) =>
              !nom!.startsWith('META-INF/') &&
              (nom.endsWith('.xml') || nom.endsWith('.musicxml')),
          orElse: () => null,
        );
    final _Entree? entree = principale == null ? null : entrees[principale];
    if (entree == null) {
      throw const ImportException(
        'Cette archive ne contient pas de partition MusicXML.',
      );
    }
    return _extraire(octets, entree);
  }

  /// Lit le repertoire central d'un zip. On ne fait pas confiance aux
  /// en-tetes locaux seuls : certains outils y laissent les tailles a zero.
  static Map<String, _Entree> _lireLeRepertoire(Uint8List o) {
    final ByteData d = ByteData.sublistView(o);
    // La fin du repertoire central est dans les 22 derniers octets, plus un
    // eventuel commentaire d'au plus 64 Kio.
    int fin = -1;
    for (int i = o.length - 22; i >= 0 && i >= o.length - 22 - 0xFFFF; i--) {
      if (d.getUint32(i, Endian.little) == 0x06054b50) {
        fin = i;
        break;
      }
    }
    if (fin < 0) {
      throw const ImportException('Cette archive .mxl est abimee.');
    }
    final int nombre = d.getUint16(fin + 10, Endian.little);
    int p = d.getUint32(fin + 16, Endian.little);
    final Map<String, _Entree> entrees = <String, _Entree>{};
    for (int k = 0; k < nombre; k++) {
      if (d.getUint32(p, Endian.little) != 0x02014b50) {
        throw const ImportException('Cette archive .mxl est abimee.');
      }
      final int methode = d.getUint16(p + 10, Endian.little);
      final int taille = d.getUint32(p + 20, Endian.little);
      final int lNom = d.getUint16(p + 28, Endian.little);
      final int lExtra = d.getUint16(p + 30, Endian.little);
      final int lCommentaire = d.getUint16(p + 32, Endian.little);
      final int local = d.getUint32(p + 42, Endian.little);
      final String nom = utf8.decode(
        o.sublist(p + 46, p + 46 + lNom),
        allowMalformed: true,
      );
      entrees[nom] = _Entree(methode, taille, local);
      p += 46 + lNom + lExtra + lCommentaire;
    }
    return entrees;
  }

  List<int> _extraire(Uint8List o, _Entree e) {
    final ByteData d = ByteData.sublistView(o);
    if (d.getUint32(e.enTeteLocal, Endian.little) != 0x04034b50) {
      throw const ImportException('Cette archive .mxl est abimee.');
    }
    final int lNom = d.getUint16(e.enTeteLocal + 26, Endian.little);
    final int lExtra = d.getUint16(e.enTeteLocal + 28, Endian.little);
    final int debut = e.enTeteLocal + 30 + lNom + lExtra;
    final List<int> brut = o.sublist(debut, debut + e.tailleCompressee);
    return switch (e.methode) {
      0 => brut,
      8 => inflate(brut),
      _ => throw const ImportException(
          'Cette archive utilise une compression inconnue.',
        ),
    };
  }

  /// Le texte d'un fichier XML : UTF-8 le plus souvent, UTF-16 parfois
  /// (Finale, certains exports Windows), reconnu a sa marque d'ordre.
  static String _texte(List<int> o) {
    if (o.length >= 2 && o[0] == 0xFF && o[1] == 0xFE) {
      return _utf16(o.sublist(2), littleEndian: true);
    }
    if (o.length >= 2 && o[0] == 0xFE && o[1] == 0xFF) {
      return _utf16(o.sublist(2), littleEndian: false);
    }
    return utf8.decode(o, allowMalformed: true);
  }

  static String _utf16(List<int> o, {required bool littleEndian}) {
    final List<int> unites = <int>[
      for (int i = 0; i + 1 < o.length; i += 2)
        littleEndian ? o[i] | (o[i + 1] << 8) : (o[i] << 8) | o[i + 1],
    ];
    return String.fromCharCodes(unites);
  }
}

class _Entree {
  const _Entree(this.methode, this.tailleCompressee, this.enTeteLocal);

  final int methode;
  final int tailleCompressee;
  final int enTeteLocal;
}
