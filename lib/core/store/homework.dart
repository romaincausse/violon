import 'dart:convert';

import 'take_history.dart';

/// Un devoir pose par le professeur (lot T1) : un passage, un tempo vise, et
/// un mot s'il en a un.
///
/// **Ca remplace la ligne du cahier que personne ne relit**
/// (`docs/professeur.md`) : l'enfant ouvre l'application chez lui et le
/// travail est deja la, sans "je croyais que c'etait jusqu'a la 20".
class Homework {
  const Homework({
    required this.workKey,
    required this.title,
    required this.targetPulseBpm,
    required this.createdAtMs,
    this.exerciseId,
    this.pieceId,
    this.fromMeasure,
    this.toMeasure,
    this.note,
  });

  /// La meme cle que l'historique : `exo:<id>`, `piece:<id>:<de>-<a>`, ...
  /// C'est elle qui relie le devoir aux prises qui l'avancent.
  final String workKey;
  final String title;
  final int targetPulseBpm;
  final int createdAtMs;

  /// D'ou rouvrir le passage : un exercice du catalogue, ou des mesures d'un
  /// morceau importe.
  final String? exerciseId;
  final String? pieceId;
  final int? fromMeasure;
  final int? toMeasure;

  /// Le mot du professeur, tel quel.
  final String? note;

  /// Le meilleur tempo tenu au bout depuis que le devoir est pose, ou `null`.
  int? bestSince(TakeHistory history) {
    int? m;
    for (final TakeRecord t in history.forKey(workKey)) {
      final int? h = t.reachedEnd ? t.heldPulseBpm : null;
      if (h != null && t.atMs >= createdAtMs && (m == null || h > m)) {
        m = h;
      }
    }
    return m;
  }

  /// Le tempo vise est atteint : une donnee qui monte, et un devoir fait.
  bool doneIn(TakeHistory history) =>
      (bestSince(history) ?? 0) >= targetPulseBpm;

  Map<String, Object?> toJson() => <String, Object?>{
        'k': workKey,
        'ti': title,
        'v': targetPulseBpm,
        'at': createdAtMs,
        if (exerciseId != null) 'exo': exerciseId,
        if (pieceId != null) 'mo': pieceId,
        if (fromMeasure != null) 'de': fromMeasure,
        if (toMeasure != null) 'a': toMeasure,
        if (note != null) 'mot': note,
      };

  static Homework? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? k = json['k'];
    final Object? ti = json['ti'];
    final Object? v = json['v'];
    final Object? at = json['at'];
    if (k is! String || ti is! String || v is! int || at is! int) {
      return null;
    }
    T? ou<T>(String c) => json[c] is T ? json[c] as T : null;
    return Homework(
      workKey: k,
      title: ti,
      targetPulseBpm: v,
      createdAtMs: at,
      exerciseId: ou<String>('exo'),
      pieceId: ou<String>('mo'),
      fromMeasure: ou<int>('de'),
      toMeasure: ou<int>('a'),
      note: ou<String>('mot'),
    );
  }
}

/// Les devoirs en cours, dans l'ordre ou ils ont ete poses.
class HomeworkList {
  const HomeworkList(this.items);

  final List<Homework> items;

  static const HomeworkList vide = HomeworkList(<Homework>[]);

  /// Poser un devoir sur un passage qui en avait deja un le remplace : le
  /// professeur a change d'avis, il n'y a pas deux objectifs.
  HomeworkList withHomework(Homework h) => HomeworkList(<Homework>[
        for (final Homework x in items)
          if (x.workKey != h.workKey) x,
        h,
      ]);

  HomeworkList without(String workKey) => HomeworkList(<Homework>[
        for (final Homework x in items)
          if (x.workKey != workKey) x,
      ]);

  String encode() => jsonEncode(<String, Object?>{
        'version': 1,
        'devoirs': <Map<String, Object?>>[
          for (final Homework h in items) h.toJson(),
        ],
      });

  /// **Ne leve jamais.**
  static HomeworkList decode(String? source) {
    if (source == null || source.isEmpty) {
      return vide;
    }
    try {
      final Object? json = jsonDecode(source);
      final Object? d = json is Map<String, Object?> ? json['devoirs'] : null;
      if (d is! List<Object?>) {
        return vide;
      }
      return HomeworkList(<Homework>[
        for (final Object? x in d)
          if (Homework.fromJson(x) case final Homework h) h,
      ]);
    } on FormatException {
      return vide;
    }
  }
}

/// La frontiere avec le stockage des devoirs, comme `HistoryStore`.
abstract class HomeworkStore {
  Future<HomeworkList> load();
  Future<void> save(HomeworkList list);
}

class FakeHomeworkStore implements HomeworkStore {
  FakeHomeworkStore([this.list = HomeworkList.vide]);

  HomeworkList list;

  @override
  Future<HomeworkList> load() async => list;

  @override
  Future<void> save(HomeworkList l) async => list = l;
}
