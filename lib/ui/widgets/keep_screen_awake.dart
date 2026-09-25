import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/device/screen_awake.dart';

/// Rend le gardien de l'ecran disponible a toute l'application.
///
/// **Pose au-dessus du `MaterialApp`**, donc au-dessus du `Navigator` : un
/// ecran empile le trouve comme il trouve le theme. C'est ce qui permet a un
/// ecran de reclamer l'ecran allume sans qu'on lui passe quoi que ce soit dans
/// son constructeur -- il n'y a qu'un ecran sur un telephone, le faire
/// traverser sept constructeurs n'apprendrait rien a personne.
class ScreenAwakeScope extends InheritedWidget {
  const ScreenAwakeScope({
    required this.awake,
    required super.child,
    super.key,
  });

  final ScreenAwake awake;

  /// Rend `null` s'il n'y a pas de portee.
  ///
  /// Volontairement tolerant : un test de widget qui monte un seul ecran n'a
  /// pas a installer une portee pour que l'ecran s'affiche. Sans portee,
  /// [KeepScreenAwake] ne fait rien du tout.
  static ScreenAwake? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenAwakeScope>()?.awake;

  @override
  bool updateShouldNotify(ScreenAwakeScope oldWidget) =>
      oldWidget.awake != awake;
}

/// Garde l'ecran allume tant que [actif] est vrai et que ce widget est monte.
///
/// **Pourquoi ce n'est pas l'application entiere.** Le telephone est pose sur
/// un pupitre et l'enfant a les deux mains prises : pendant qu'il joue, il ne
/// peut pas toucher l'ecran pour le reveiller, et un ecran qui s'eteint au
/// milieu d'une gamme est une raison d'arreter de jouer. Mais l'application
/// reste souvent ouverte apres la seance, et un ecran allume deux heures sur
/// un AMOLED coute une batterie -- et marque la dalle. On allume donc pendant
/// qu'on joue, ecran par ecran, et pas une minute de plus.
///
/// La demande est rendue au demontage, y compris quand l'ecran est ferme par
/// le bouton retour : c'est le seul chemin par lequel un ecran de travail se
/// quitte.
class KeepScreenAwake extends StatefulWidget {
  const KeepScreenAwake({
    required this.child,
    this.actif = true,
    super.key,
  });

  final Widget child;

  /// Faux quand cet ecran est ouvert mais que rien ne se passe : un metronome
  /// a l'arret n'a aucune raison de tenir l'ecran allume.
  final bool actif;

  @override
  State<KeepScreenAwake> createState() => _KeepScreenAwakeState();
}

class _KeepScreenAwakeState extends State<KeepScreenAwake> {
  /// Le gardien aupres duquel une demande est posee, s'il y en a une.
  ///
  /// On retient l'objet et pas un booleen : c'est a **celui-la** qu'il faudra
  /// rendre la demande, meme si la portee a change entre-temps.
  ScreenAwake? _tenu;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accorder();
  }

  @override
  void didUpdateWidget(KeepScreenAwake oldWidget) {
    super.didUpdateWidget(oldWidget);
    _accorder();
  }

  void _accorder() {
    final ScreenAwake? portee = ScreenAwakeScope.maybeOf(context);
    // Sans portee, il n'y a rien a reclamer : voulu reste nul et ce widget se
    // contente de passer son enfant.
    final ScreenAwake? voulu = widget.actif ? portee : null;
    final ScreenAwake? tenu = _tenu;
    if (tenu == voulu) {
      return;
    }
    _tenu = voulu;
    if (tenu != null) {
      unawaited(tenu.release());
    }
    if (voulu != null) {
      unawaited(voulu.acquire());
    }
  }

  @override
  void dispose() {
    final ScreenAwake? tenu = _tenu;
    if (tenu != null) {
      _tenu = null;
      unawaited(tenu.release());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
