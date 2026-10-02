import 'dart:typed_data';

/// La frontiere avec le systeme pour **ranger** un fichier choisi par
/// l'utilisateur (lot T3), comme `DocumentPicker` pour en lire un.
///
/// L'utilisateur choisit le dossier et le nom ; l'application n'ecrit que la.
/// Aucune permission, aucun envoi : c'est un geste volontaire, sur son
/// telephone (`docs/professeur.md`).
abstract class DocumentSaver {
  /// Vrai si le fichier a ete ecrit, faux si l'utilisateur a renonce.
  Future<bool> save(String name, Uint8List bytes);
}

/// Pour les tests : retient ce qu'on lui confie.
class FakeDocumentSaver implements DocumentSaver {
  FakeDocumentSaver({this.accept = true});

  final bool accept;
  final List<(String, Uint8List)> saved = <(String, Uint8List)>[];

  @override
  Future<bool> save(String name, Uint8List bytes) async {
    if (accept) {
      saved.add((name, bytes));
    }
    return accept;
  }
}
