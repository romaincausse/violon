import 'dart:convert';

/// Les records des jeux (jalon 14) : des donnees qui montent, jamais qui
/// redescendent.
class GameRecords {
  const GameRecords({
    this.echoBest = 0,
    this.longToneBestMs = 0,
    this.pulseBest = 0,
    this.evenBowBestMs = 0,
    this.vibratoBestMs = 0,
  });

  /// Le plus long motif rejoue a l'echo, en notes.
  final int echoBest;

  /// La plus longue note tenue juste, en millisecondes.
  final int longToneBestMs;

  /// Le meilleur score au tempo cache, sur cent.
  final int pulseBest;

  /// Le plus long archet a son egal, en millisecondes (K7).
  final int evenBowBestMs;

  /// La plus longue note vibree regulierement, en millisecondes (K13).
  final int vibratoBestMs;

  static const GameRecords vide = GameRecords();

  /// Un record ne baisse jamais : on garde le plus haut des deux.
  GameRecords merge({
    int? echo,
    int? longToneMs,
    int? pulse,
    int? evenBowMs,
    int? vibratoMs,
  }) =>
      GameRecords(
        echoBest: _max(echoBest, echo),
        longToneBestMs: _max(longToneBestMs, longToneMs),
        pulseBest: _max(pulseBest, pulse),
        evenBowBestMs: _max(evenBowBestMs, evenBowMs),
        vibratoBestMs: _max(vibratoBestMs, vibratoMs),
      );

  static int _max(int a, int? b) => b == null || b < a ? a : b;

  String encode() => jsonEncode(<String, Object?>{
        'echo': echoBest,
        'tenue': longToneBestMs,
        'pulsation': pulseBest,
        'archet': evenBowBestMs,
        'vibrato': vibratoBestMs,
      });

  /// Une memoire abimee se lit comme une memoire vide : un record perdu vaut
  /// mieux qu'une application qui ne s'ouvre pas.
  static GameRecords decode(String? source) {
    if (source == null || source.isEmpty) {
      return vide;
    }
    try {
      final Object? json = jsonDecode(source);
      if (json is! Map<String, Object?>) {
        return vide;
      }
      int lire(String cle) {
        final Object? v = json[cle];
        return v is int && v > 0 ? v : 0;
      }

      return GameRecords(
        echoBest: lire('echo'),
        longToneBestMs: lire('tenue'),
        pulseBest: lire('pulsation'),
        evenBowBestMs: lire('archet'),
        vibratoBestMs: lire('vibrato'),
      );
    } on FormatException {
      return vide;
    }
  }
}

/// La frontiere avec le stockage local des records, comme les autres
/// magasins.
abstract class GameStore {
  Future<GameRecords> load();
  Future<void> save(GameRecords records);
}

class FakeGameStore implements GameStore {
  FakeGameStore([this.records = GameRecords.vide]);

  GameRecords records;

  @override
  Future<GameRecords> load() async => records;

  @override
  Future<void> save(GameRecords r) async => records = r;
}
