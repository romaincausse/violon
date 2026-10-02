import 'dart:typed_data';

/// La frontiere avec le systeme pour **envoyer** une prise a quelqu'un (mode
/// concert, ADR-018) : le partage du telephone, et c'est l'enfant qui choisit
/// a qui.
///
/// Comme `DocumentSaver`, c'est un geste volontaire : rien ne part tout seul,
/// et l'application ne garde pas ce qu'elle a envoye. Le fichier remis au
/// systeme ne survit ni au concert suivant ni au lancement suivant.
abstract class TakeSharer {
  /// Propose [wav] au partage, sous le nom [name]. Vrai si le selecteur du
  /// systeme a pu s'ouvrir -- ce qu'il en advient ensuite appartient a
  /// l'enfant et au telephone.
  Future<bool> share(String name, Uint8List wav);
}

/// Pour les tests : retient ce qu'on lui a confie.
class FakeTakeSharer implements TakeSharer {
  FakeTakeSharer({this.accept = true});

  final bool accept;
  final List<(String, Uint8List)> shared = <(String, Uint8List)>[];

  @override
  Future<bool> share(String name, Uint8List wav) async {
    if (accept) {
      shared.add((name, wav));
    }
    return accept;
  }
}
