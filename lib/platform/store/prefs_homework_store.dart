import 'package:shared_preferences/shared_preferences.dart';

import '../../core/store/homework.dart';

/// Les devoirs, dans les preferences locales, sous leur propre cle.
class PrefsHomeworkStore implements HomeworkStore {
  PrefsHomeworkStore({SharedPreferencesAsync? preferences})
      : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const String _cle = 'violon.devoirs.v1';

  @override
  Future<HomeworkList> load() async {
    try {
      return HomeworkList.decode(await _prefs.getString(_cle));
    } on Exception {
      return HomeworkList.vide;
    }
  }

  @override
  Future<void> save(HomeworkList list) => _prefs.setString(_cle, list.encode());
}

/// Fabrique par defaut, injectee depuis `main`.
HomeworkStore defaultHomeworkStore() => PrefsHomeworkStore();
