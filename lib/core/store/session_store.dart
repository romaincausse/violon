import 'dart:convert';

import '../exercises/exercise_progress.dart';

/// Ce que l'application se rappelle d'une seance a l'autre.
///
/// **Volontairement maigre.** Pas d'historique, pas de courbes, pas
/// d'enregistrement audio : la progression dans le catalogue, le diapason
/// mesure, et ce qui etait travaille la veille. C'est ce qu'il faut pour
/// qu'une application ouverte le soir reprenne ou on en etait -- le reste
/// (H2, H4) demandera une vraie base, et attendra d'etre utile.
class RememberedSession {
  const RememberedSession({
    this.a4,
    this.exerciseId,
    this.tempoBpm,
    this.bests = const <ExerciseBest>[],
  });

  /// Diapason mesure sur les cordes a vide, ou `null` si jamais mesure.
  final double? a4;

  /// L'exercice travaille en dernier, et a quel tempo.
  final String? exerciseId;
  final int? tempoBpm;

  /// La progression dans le catalogue.
  final List<ExerciseBest> bests;

  static const RememberedSession vide = RememberedSession();

  bool get isEmpty => a4 == null && exerciseId == null && bests.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'version': _version,
        if (a4 != null) 'a4': a4,
        if (exerciseId != null) 'exercice': exerciseId,
        if (tempoBpm != null) 'tempo': tempoBpm,
        'records': <Map<String, Object?>>[
          for (final ExerciseBest best in bests) best.toJson(),
        ],
      };

  String encode() => jsonEncode(toJson());

  /// Numero de format.
  ///
  /// Il ne sert a rien aujourd'hui, et il servira le jour ou la forme
  /// changera : sans lui, la seule facon de relire un ancien enregistrement
  /// serait de le deviner.
  static const int _version = 1;

  /// Relit ce qui a ete range.
  ///
  /// **Ne leve jamais.** Une preference abimee, un format d'une autre version,
  /// une valeur d'un autre type : dans tous ces cas on rend une seance vide et
  /// l'application s'ouvre normalement. Perdre une progression est desagreable ;
  /// ne plus pouvoir ouvrir l'application parce qu'une cle est mal formee
  /// serait pire.
  static RememberedSession decode(String? source) {
    if (source == null || source.isEmpty) {
      return vide;
    }
    try {
      final Object? json = jsonDecode(source);
      if (json is! Map<String, Object?>) {
        return vide;
      }
      final Object? records = json['records'];
      return RememberedSession(
        a4: _double(json['a4']),
        exerciseId:
            json['exercice'] is String ? json['exercice'] as String : null,
        tempoBpm: json['tempo'] is int && (json['tempo'] as int) > 0
            ? json['tempo'] as int
            : null,
        bests: records is List<Object?>
            ? <ExerciseBest>[
                for (final Object? item in records)
                  if (ExerciseBest.fromJson(item) case final ExerciseBest best)
                    best,
              ]
            : const <ExerciseBest>[],
      );
    } on FormatException {
      return vide;
    }
  }

  /// Un diapason plausible, ou rien.
  ///
  /// Les bornes ne sont pas decoratives : une valeur aberrante relue dans les
  /// preferences rendrait toute la justesse fausse, en silence, jusqu'a ce
  /// qu'on comprenne pourquoi l'enfant est declare faux partout.
  static double? _double(Object? value) {
    if (value is! num) {
      return null;
    }
    final double hz = value.toDouble();
    return hz >= 390 && hz <= 490 ? hz : null;
  }
}

/// La frontiere avec le stockage local.
///
/// Comme pour l'audio, `lib/core/` decrit le besoin et `lib/platform/`
/// l'implemente : rien au-dessus ne connait `shared_preferences`, et les tests
/// n'ecrivent nulle part.
abstract class SessionStore {
  Future<RememberedSession> load();

  Future<void> save(RememberedSession session);

  /// Oublie tout. Existe pour les tests et pour un futur "repartir a zero".
  Future<void> clear();
}

/// Un magasin en memoire, pour les tests et pour le developpement.
class FakeSessionStore implements SessionStore {
  FakeSessionStore([this._session = RememberedSession.vide]);

  RememberedSession _session;
  int saves = 0;
  int loads = 0;

  RememberedSession get current => _session;

  @override
  Future<RememberedSession> load() async {
    loads++;
    return _session;
  }

  @override
  Future<void> save(RememberedSession session) async {
    saves++;
    // Passe par l'encodage reel : un magasin factice qui garderait l'objet tel
    // quel ne dirait rien de ce qui survit vraiment a un aller-retour.
    _session = RememberedSession.decode(session.encode());
  }

  @override
  Future<void> clear() async {
    _session = RememberedSession.vide;
  }
}
