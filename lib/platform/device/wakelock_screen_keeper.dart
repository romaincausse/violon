import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/device/screen_awake.dart';

/// Le gardien reel de l'ecran, par `wakelock_plus`.
///
/// **La seule classe du projet qui connaisse `wakelock_plus`**, comme
/// `PrefsSessionStore` est la seule a connaitre `shared_preferences`.
///
/// Cote Android le paquet pose `FLAG_KEEP_SCREEN_ON` sur la fenetre de
/// l'activite. Deux consequences qui comptent ici :
///
///  - aucune permission n'est demandee, donc rien a expliquer a l'enfant ;
///  - le drapeau ne vaut que pour une fenetre visible. L'application mise en
///    arriere-plan laisse l'ecran s'eteindre **sans qu'on ait a le demander**,
///    ce qui est exactement ce qu'on veut : le telephone repose sur le pupitre
///    pendant qu'on joue, il ne doit pas veiller toute la nuit parce qu'on a
///    oublie de fermer l'application.
///
/// **Rien ne remonte.** Sur une plateforme ou le greffon n'existe pas -- un
/// test de widget sur la machine de developpement, par exemple -- l'appel leve
/// une `MissingPluginException`. Un ecran qui s'eteint est une gene ; une
/// exception qui traverse l'interface pendant que l'enfant joue est pire.
class WakelockScreenKeeper implements ScreenKeeper {
  const WakelockScreenKeeper();

  @override
  Future<void> toggle({required bool on}) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } on Exception {
      // Tant pis : l'ecran s'eteindra comme d'habitude.
    }
  }
}

ScreenKeeper defaultScreenKeeper() => const WakelockScreenKeeper();
