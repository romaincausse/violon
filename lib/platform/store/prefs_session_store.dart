import 'package:shared_preferences/shared_preferences.dart';

import '../../core/store/session_store.dart';

/// La memoire de l'application, rangee dans les preferences locales.
///
/// **La seule classe du projet qui connaisse `shared_preferences`**, comme
/// `RecordAudioCapture` est la seule a connaitre `record` et
/// `SoloudAudioEngine` la seule a connaitre `flutter_soloud`.
///
/// **Tout tient dans une seule cle**, un objet JSON. Eparpiller la progression
/// sur dix-neuf cles rendrait une lecture partielle possible -- la moitie d'une
/// progression relue est pire qu'une progression perdue, parce qu'elle a l'air
/// juste.
///
/// **Aucune ecriture ne fait echouer quoi que ce soit.** Si le rangement rate,
/// la seance continue : on perd la memoire d'un soir, pas la seance en cours.
class PrefsSessionStore implements SessionStore {
  PrefsSessionStore({SharedPreferencesAsync? preferences})
      : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const String _cle = 'violon.seance.v1';

  @override
  Future<RememberedSession> load() async {
    try {
      return RememberedSession.decode(await _prefs.getString(_cle));
    } on Exception {
      // Une preference illisible n'empeche pas d'ouvrir l'application.
      return RememberedSession.vide;
    }
  }

  @override
  Future<void> save(RememberedSession session) async {
    try {
      await _prefs.setString(_cle, session.encode());
    } on Exception {
      // Rien a faire, et surtout rien a dire : l'enfant est en train de
      // jouer.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _prefs.remove(_cle);
    } on Exception {
      return;
    }
  }
}

/// Fabrique par defaut, injectee depuis `main`.
SessionStore defaultSessionStore() => PrefsSessionStore();
