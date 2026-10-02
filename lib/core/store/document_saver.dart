import 'dart:typed_data';

/// La frontiere avec le systeme pour **ranger** un fichier choisi par
/// l'utilisateur (lot T3), comme `DocumentPicker` pour en lire un.
///
/// L'utilisateur choisit le dossier et le nom ; l'application n'ecrit que la.
/// Aucune permission, aucun envoi : c'est un geste volontaire, sur son
/// telephone (`docs/professeur.md`).
abstract class DocumentSaver {
  /// Vrai si le fichier a ete ecrit, faux si l'utilisateur a renonce.
  ///
  /// [mimeType] dit au systeme ce qu'il range : un rapport est du texte, une
  /// prise de concert (ADR-018) un son.
  Future<bool> save(
    String name,
    Uint8List bytes, {
    String mimeType = 'text/plain',
  });
}

/// Pour les tests : retient ce qu'on lui confie.
class FakeDocumentSaver implements DocumentSaver {
  FakeDocumentSaver({this.accept = true});

  final bool accept;
  final List<(String, Uint8List)> saved = <(String, Uint8List)>[];
  final List<String> mimeTypes = <String>[];

  @override
  Future<bool> save(
    String name,
    Uint8List bytes, {
    String mimeType = 'text/plain',
  }) async {
    if (accept) {
      saved.add((name, bytes));
      mimeTypes.add(mimeType);
    }
    return accept;
  }
}
