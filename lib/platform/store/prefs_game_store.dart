import 'package:shared_preferences/shared_preferences.dart';

import '../../core/store/game_records.dart';

/// Les records des jeux, dans les preferences locales, sous leur propre cle.
///
/// **Les preferences ne s'ouvrent qu'au premier record lu**, pas a la
/// construction : le magasin est cree au lancement, et un test qui monte
/// l'application sans jamais ouvrir les jeux n'a pas de preferences a
/// fournir.
class PrefsGameStore implements GameStore {
  PrefsGameStore({SharedPreferencesAsync? preferences})
      : _injectees = preferences;

  final SharedPreferencesAsync? _injectees;
  late final SharedPreferencesAsync _prefs =
      _injectees ?? SharedPreferencesAsync();

  static const String _cle = 'violon.jeux.v1';

  @override
  Future<GameRecords> load() async {
    try {
      return GameRecords.decode(await _prefs.getString(_cle));
    } on Exception {
      return GameRecords.vide;
    }
  }

  @override
  Future<void> save(GameRecords records) =>
      _prefs.setString(_cle, records.encode());
}

/// Fabrique par defaut, injectee depuis `main`.
GameStore defaultGameStore() => PrefsGameStore();
