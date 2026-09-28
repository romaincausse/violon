import 'package:shared_preferences/shared_preferences.dart';

import '../../core/store/piece_store.dart';

/// Les morceaux importes, ranges dans les preferences locales.
///
/// **Une cle a part de la seance**, et une seule pour tous les morceaux : ils
/// s'ecrivent a l'import, rarement, et se relisent d'un bloc.
///
/// Les preferences suffisent : un morceau d'eleve fait quelques dizaines de
/// kilo-octets une fois mis a plat, et un eleve en a quelques-uns. Une base
/// de donnees attendra de savoir ce qu'on veut historiser (lot H2).
class PrefsPieceStore implements PieceStore {
  PrefsPieceStore({SharedPreferencesAsync? preferences})
      : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const String _cle = 'violon.morceaux.v1';

  @override
  Future<PieceLibrary> load() async {
    try {
      return PieceLibrary.decode(await _prefs.getString(_cle));
    } on Exception {
      return PieceLibrary.vide;
    }
  }

  @override
  Future<void> save(PieceLibrary library) async {
    // Contrairement a la seance, un echec ici se dit : l'utilisateur vient
    // d'importer un morceau et s'attend a le retrouver demain.
    await _prefs.setString(_cle, library.encode());
  }
}

/// Fabrique par defaut, injectee depuis `main`.
PieceStore defaultPieceStore() => PrefsPieceStore();
