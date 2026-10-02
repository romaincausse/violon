import 'package:shared_preferences/shared_preferences.dart';

import '../../core/store/take_history.dart';

/// L'historique des prises, dans les preferences locales, sous sa propre cle.
///
/// **Les preferences, et pas une base de donnees** : trois cents prises
/// compactes tiennent dans une centaine de kilo-octets, et une base serait
/// une dependance de plus, a demander (`CLAUDE.md`).
class PrefsHistoryStore implements HistoryStore {
  PrefsHistoryStore({SharedPreferencesAsync? preferences})
      : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const String _cle = 'violon.prises.v1';

  @override
  Future<TakeHistory> load() async {
    try {
      return TakeHistory.decode(await _prefs.getString(_cle));
    } on Exception {
      return TakeHistory.vide;
    }
  }

  @override
  Future<void> save(TakeHistory history) =>
      _prefs.setString(_cle, history.encode());
}

/// Fabrique par defaut, injectee depuis `main`.
HistoryStore defaultHistoryStore() => PrefsHistoryStore();
