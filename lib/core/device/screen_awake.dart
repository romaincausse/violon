/// La frontiere avec l'ecran du telephone : le garder allume, ou le laisser
/// s'eteindre.
///
/// Une seule methode, comme `AudioEngine` n'en expose que deux : tenir l'ecran
/// allume est un etat booleen, et tout ce qui ressemble a une politique --
/// quand, pendant combien de temps, a la demande de qui -- est du ressort de
/// [ScreenAwake], qui est du Dart pur et donc testable.
///
/// **Une implementation ne leve pas.** Un ecran qui s'eteint est une gene ;
/// une exception remontee jusqu'a l'interface pendant que l'enfant joue est un
/// ecran noir avec du rouge dessus. La couche `lib/platform/` avale ce que le
/// systeme lui renvoie.
abstract class ScreenKeeper {
  Future<void> toggle({required bool on});
}

typedef ScreenKeeperFactory = ScreenKeeper Function();

/// Garde l'ecran allume tant qu'au moins un ecran le demande.
///
/// **Pourquoi compter, et pas un simple booleen.** Les ecrans de
/// l'application s'empilent : on accorde par-dessus une prise en cours, on
/// ouvre le bourdon par-dessus l'accordeur. Si chacun posait et retirait un
/// booleen, le premier qui se ferme eteindrait l'ecran alors que celui du
/// dessous le reclame encore. Le compte regle ca sans que personne ait a
/// savoir qui d'autre est ouvert.
///
/// Le materiel n'est touche qu'aux transitions, de zero a un et de un a zero :
/// dix ecrans ouverts ne font pas dix appels.
class ScreenAwake {
  ScreenAwake(this._keeper);

  final ScreenKeeper _keeper;

  int _demandes = 0;

  /// Combien d'ecrans reclament l'ecran allume en ce moment.
  int get demandes => _demandes;

  /// Ce qui a ete demande au materiel en dernier.
  bool get pose => _pose;
  bool _pose = false;

  Future<void> acquire() {
    _demandes++;
    return _viser();
  }

  /// Rend une demande.
  ///
  /// **Tolere un relachement de trop** et ne descend jamais sous zero : un
  /// widget demonte deux fois -- ca arrive, au gre des reconstructions -- ne
  /// doit pas rendre le compte negatif, sans quoi l'ecran suivant qui
  /// demanderait ne rallumerait rien.
  Future<void> release() {
    if (_demandes > 0) {
      _demandes--;
    }
    return _viser();
  }

  Future<void> _viser() {
    final bool voulu = _demandes > 0;
    if (voulu == _pose) {
      return Future<void>.value();
    }
    _pose = voulu;
    return _keeper.toggle(on: voulu);
  }
}

/// Faux gardien, pour les tests : il note ce qu'on lui demande.
class FakeScreenKeeper implements ScreenKeeper {
  final List<bool> toggles = <bool>[];

  bool get on => toggles.isNotEmpty && toggles.last;

  @override
  Future<void> toggle({required bool on}) async => toggles.add(on);
}
