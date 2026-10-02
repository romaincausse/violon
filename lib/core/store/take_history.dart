import 'dart:convert';

/// Ce qu'on garde d'une mesure apres une prise.
class MeasureTrace {
  const MeasureTrace({
    required this.measure,
    required this.difficulty,
    this.stops = 0,
    this.restarts = 0,
    this.tempoRatio,
  });

  final int measure;

  /// La difficulte du diagnostic, arrondie (`MeasureReport.difficulty`).
  final int difficulty;
  final int stops;
  final int restarts;
  final double? tempoRatio;

  Map<String, Object?> toJson() => <String, Object?>{
        'm': measure,
        'd': difficulty,
        if (stops != 0) 's': stops,
        if (restarts != 0) 'r': restarts,
        if (tempoRatio != null) 't': (tempoRatio! * 100).round(),
      };

  static MeasureTrace? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? m = json['m'];
    final Object? d = json['d'];
    if (m is! int || d is! int) {
      return null;
    }
    final Object? t = json['t'];
    return MeasureTrace(
      measure: m,
      difficulty: d,
      stops: json['s'] is int ? json['s']! as int : 0,
      restarts: json['r'] is int ? json['r']! as int : 0,
      tempoRatio: t is int ? t / 100 : null,
    );
  }
}

/// Ce qu'on garde d'une note : sa hauteur, sa mesure, et l'ecart median.
class NoteTrace {
  const NoteTrace({
    required this.midi,
    required this.measure,
    required this.cents,
  });

  final int midi;
  final int measure;
  final double cents;

  Map<String, Object?> toJson() => <String, Object?>{
        'n': midi,
        'm': measure,
        'c': (cents * 10).round(),
      };

  static NoteTrace? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? n = json['n'];
    final Object? m = json['m'];
    final Object? c = json['c'];
    if (n is! int || m is! int || c is! int) {
      return null;
    }
    return NoteTrace(midi: n, measure: m, cents: c / 10);
  }
}

/// Une prise, telle qu'on s'en souvient (jalon 9).
///
/// **Compacte, et c'est voulu.** Ni son, ni trame : quelques chiffres par
/// mesure et un ecart par note. Trois cents prises tiennent dans les
/// preferences, sans base de donnees -- qui serait une dependance de plus.
class TakeRecord {
  const TakeRecord({
    required this.atMs,
    required this.key,
    required this.title,
    required this.fromMeasure,
    required this.toMeasure,
    required this.writtenPulseBpm,
    required this.durationMs,
    this.heldPulseBpm,
    this.tuningScore,
    this.rhythmScore,
    this.reachedEnd = false,
    this.measures = const <MeasureTrace>[],
    this.notes = const <NoteTrace>[],
  });

  /// Quand, en millisecondes depuis l'epoque.
  final int atMs;

  /// Ce qu'on travaillait, de facon stable d'un jour a l'autre :
  /// `exo:<id>`, `piece:<id>`, ou `passage:<titre>`.
  final String key;
  final String title;
  final int fromMeasure;
  final int toMeasure;
  final int writtenPulseBpm;
  final int durationMs;
  final int? heldPulseBpm;
  final int? tuningScore;
  final int? rhythmScore;
  final bool reachedEnd;
  final List<MeasureTrace> measures;
  final List<NoteTrace> notes;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  Map<String, Object?> toJson() => <String, Object?>{
        'at': atMs,
        'k': key,
        'ti': title,
        'de': fromMeasure,
        'a': toMeasure,
        'w': writtenPulseBpm,
        'du': durationMs,
        if (heldPulseBpm != null) 'h': heldPulseBpm,
        if (tuningScore != null) 'j': tuningScore,
        if (rhythmScore != null) 'ry': rhythmScore,
        if (reachedEnd) 'fin': true,
        'ms': <Map<String, Object?>>[
          for (final MeasureTrace m in measures) m.toJson(),
        ],
        'no': <Map<String, Object?>>[
          for (final NoteTrace n in notes) n.toJson(),
        ],
      };

  /// Relit une prise, ou `null` au moindre champ indispensable manquant.
  static TakeRecord? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? at = json['at'];
    final Object? k = json['k'];
    final Object? ti = json['ti'];
    final Object? de = json['de'];
    final Object? a = json['a'];
    final Object? w = json['w'];
    final Object? du = json['du'];
    if (at is! int ||
        k is! String ||
        ti is! String ||
        de is! int ||
        a is! int ||
        w is! int ||
        du is! int) {
      return null;
    }
    final Object? ms = json['ms'];
    final Object? no = json['no'];
    return TakeRecord(
      atMs: at,
      key: k,
      title: ti,
      fromMeasure: de,
      toMeasure: a,
      writtenPulseBpm: w,
      durationMs: du,
      heldPulseBpm: json['h'] is int ? json['h']! as int : null,
      tuningScore: json['j'] is int ? json['j']! as int : null,
      rhythmScore: json['ry'] is int ? json['ry']! as int : null,
      reachedEnd: json['fin'] == true,
      measures: ms is List<Object?>
          ? <MeasureTrace>[
              for (final Object? m in ms)
                if (MeasureTrace.fromJson(m) case final MeasureTrace t) t,
            ]
          : const <MeasureTrace>[],
      notes: no is List<Object?>
          ? <NoteTrace>[
              for (final Object? n in no)
                if (NoteTrace.fromJson(n) case final NoteTrace t) t,
            ]
          : const <NoteTrace>[],
    );
  }
}

/// L'historique des prises, du plus ancien au plus recent.
class TakeHistory {
  const TakeHistory(this.takes);

  final List<TakeRecord> takes;

  static const TakeHistory vide = TakeHistory(<TakeRecord>[]);

  /// Au-dela, les plus anciennes s'effacent. Trois cents prises font des
  /// semaines de travail quotidien, et une centaine de kilo-octets.
  static const int capacity = 300;

  TakeHistory withTake(TakeRecord take) {
    final List<TakeRecord> toutes = <TakeRecord>[...takes, take];
    return TakeHistory(
      toutes.length > capacity
          ? toutes.sublist(toutes.length - capacity)
          : toutes,
    );
  }

  /// Les prises d'un meme travail, dans l'ordre.
  List<TakeRecord> forKey(String key) => <TakeRecord>[
        for (final TakeRecord t in takes)
          if (t.key == key) t
      ];

  /// Les travaux deja joues, du plus recent au plus ancien.
  List<String> get keys {
    final List<String> vus = <String>[];
    for (final TakeRecord t in takes.reversed) {
      if (!vus.contains(t.key)) {
        vus.add(t.key);
      }
    }
    return vus;
  }

  String encode() => jsonEncode(<String, Object?>{
        'version': 1,
        'prises': <Map<String, Object?>>[
          for (final TakeRecord t in takes) t.toJson(),
        ],
      });

  /// **Ne leve jamais** : une prise illisible est perdue, les autres restent.
  static TakeHistory decode(String? source) {
    if (source == null || source.isEmpty) {
      return vide;
    }
    try {
      final Object? json = jsonDecode(source);
      if (json is! Map<String, Object?>) {
        return vide;
      }
      final Object? prises = json['prises'];
      if (prises is! List<Object?>) {
        return vide;
      }
      return TakeHistory(<TakeRecord>[
        for (final Object? p in prises)
          if (TakeRecord.fromJson(p) case final TakeRecord t) t,
      ]);
    } on FormatException {
      return vide;
    }
  }
}

/// La frontiere avec le stockage de l'historique, comme `PieceStore`.
abstract class HistoryStore {
  Future<TakeHistory> load();
  Future<void> save(TakeHistory history);
}

/// Historique en memoire, pour les tests.
class FakeHistoryStore implements HistoryStore {
  FakeHistoryStore([this.history = TakeHistory.vide]);

  TakeHistory history;
  int saves = 0;

  @override
  Future<TakeHistory> load() async => history;

  @override
  Future<void> save(TakeHistory h) async {
    history = h;
    saves++;
  }
}
