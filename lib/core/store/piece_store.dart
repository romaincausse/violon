import 'dart:convert';

import '../import/imported_piece.dart';

/// Les morceaux importes, tels qu'on les range.
///
/// **Une liste, dans l'ordre d'import, le plus recent en tete.** Un eleve a
/// trois ou quatre morceaux en cours, pas une bibliotheque : pas de dossiers,
/// pas de tri, et le dernier arrive est celui qu'on vient chercher.
class PieceLibrary {
  const PieceLibrary(this.pieces);

  final List<ImportedPiece> pieces;

  static const PieceLibrary vide = PieceLibrary(<ImportedPiece>[]);

  ImportedPiece? byId(String id) {
    for (final ImportedPiece p in pieces) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }

  /// Ajoute [piece] en tete. Reimporter le meme morceau le remplace : il
  /// remonte en tete au lieu d'apparaitre deux fois.
  PieceLibrary withPiece(ImportedPiece piece) => PieceLibrary(<ImportedPiece>[
        piece,
        for (final ImportedPiece p in pieces)
          if (p.id != piece.id) p,
      ]);

  PieceLibrary without(String id) => PieceLibrary(<ImportedPiece>[
        for (final ImportedPiece p in pieces)
          if (p.id != id) p,
      ]);

  String encode() => jsonEncode(<String, Object?>{
        'version': 1,
        'morceaux': <Map<String, Object?>>[
          for (final ImportedPiece p in pieces) p.toJson(),
        ],
      });

  /// Relit la bibliotheque. **Ne leve jamais** : un morceau illisible est
  /// perdu, les autres restent, et l'application s'ouvre.
  static PieceLibrary decode(String? source) {
    if (source == null || source.isEmpty) {
      return vide;
    }
    try {
      final Object? json = jsonDecode(source);
      if (json is! Map<String, Object?>) {
        return vide;
      }
      final Object? morceaux = json['morceaux'];
      if (morceaux is! List<Object?>) {
        return vide;
      }
      return PieceLibrary(<ImportedPiece>[
        for (final Object? m in morceaux)
          if (ImportedPiece.fromJson(m) case final ImportedPiece p) p,
      ]);
    } on FormatException {
      return vide;
    }
  }
}

/// La frontiere avec le stockage des morceaux.
///
/// A part de `SessionStore` : une seance pese quelques octets et s'ecrit a
/// chaque exercice, un morceau pese des dizaines de kilo-octets et ne s'ecrit
/// qu'a l'import. Les melanger reecrirait tout le repertoire a chaque note
/// jouee.
abstract class PieceStore {
  Future<PieceLibrary> load();

  Future<void> save(PieceLibrary library);
}

/// Un magasin en memoire, pour les tests et pour le developpement.
class FakePieceStore implements PieceStore {
  FakePieceStore([this._library = PieceLibrary.vide]);

  PieceLibrary _library;
  int saves = 0;

  PieceLibrary get current => _library;

  @override
  Future<PieceLibrary> load() async => _library;

  @override
  Future<void> save(PieceLibrary library) async {
    saves++;
    // Par l'encodage reel, comme `FakeSessionStore` : ce qui ne survit pas a
    // l'aller-retour doit se voir dans les tests.
    _library = PieceLibrary.decode(library.encode());
  }
}
