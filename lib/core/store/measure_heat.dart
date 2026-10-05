import 'dart:math' as math;

import 'take_history.dart';

/// Ou ca coince dans un morceau, depuis des semaines (lot H2).
///
/// **Cumulee, et oublieuse.** Chaque prise du morceau ajoute la difficulte de
/// ses mesures ; une prise d'il y a une semaine compte moitie moins qu'une
/// prise d'aujourd'hui. Une mesure difficile il y a un mois et travaillee
/// depuis doit pouvoir palir -- sinon la carte montrerait le passe, et pas ce
/// qu'il reste a faire.
///
/// **La moyenne, pas la somme** : une mesure jouee vingt fois n'est pas vingt
/// fois plus chaude qu'une mesure jouee une fois. On divise par le poids des
/// prises ou elle a ete jouee.
class MeasureHeat {
  MeasureHeat._(this.heat, this.takes);

  /// Chaleur par mesure, entre 0 (tout tient) et 1 (le plus chaud du
  /// morceau... ou au-dela du seuil de tache).
  final Map<int, double> heat;

  /// Prises du morceau prises en compte.
  final int takes;

  /// Une semaine : une prise perd la moitie de son poids.
  static const Duration halfLife = Duration(days: 7);

  /// La difficulte qui vaut une chaleur pleine. Au-dela, tout est rouge ;
  /// en dessous de `TakeReport.taskAbove` (20), une mesure n'est pas une
  /// tache, et sa chaleur reste faible.
  static const double fullHeat = 60;

  /// La chaleur des mesures du morceau [pieceId], vue a l'instant [now].
  static MeasureHeat of(TakeHistory history, String pieceId, DateTime now) {
    final Map<int, double> somme = <int, double>{};
    final Map<int, double> poids = <int, double>{};
    int prises = 0;
    for (final TakeRecord t in history.takes) {
      if (!t.key.startsWith('piece:$pieceId:')) {
        continue;
      }
      prises++;
      final double age = now.difference(t.at).inMinutes / halfLife.inMinutes;
      final double w = math.pow(0.5, math.max(0, age)).toDouble();
      for (final MeasureTrace m in t.measures) {
        somme[m.measure] = (somme[m.measure] ?? 0) + w * m.difficulty;
        poids[m.measure] = (poids[m.measure] ?? 0) + w;
      }
    }
    return MeasureHeat._(<int, double>{
      for (final int m in somme.keys)
        m: math.min(1, somme[m]! / poids[m]! / fullHeat),
    }, prises);
  }

  /// Les mesures les plus chaudes, au plus [count], au-dessus d'un tiers de
  /// chaleur -- en dessous, ce n'est pas la peine de les nommer.
  List<int> hottest({int count = 2}) {
    final List<MapEntry<int, double>> chaudes = <MapEntry<int, double>>[
      for (final MapEntry<int, double> e in heat.entries)
        if (e.value >= 1 / 3) e,
    ]..sort((MapEntry<int, double> a, MapEntry<int, double> b) =>
        b.value.compareTo(a.value));
    return <int>[
      for (final MapEntry<int, double> e in chaudes.take(count)) e.key
    ]..sort();
  }
}

/// Ce qui a le plus progresse dans un morceau (lot V4) : la meme donnee que
/// la chaleur, retournee.
///
/// La carte des mesures qui resistent, cumulee sur des semaines, est une
/// rangee de cases rouges sur son morceau prefere : "voila tout ce que tu as
/// rate", deguise. A l'enfant on montre l'inverse -- **les mesures qui
/// coincaient et qui coincent moins** -- et la carte des resistances ne se
/// montre qu'en mode lecon, ou elle sert a quelqu'un.
///
/// Le progres d'une mesure : sa difficulte moyenne d'il y a une a quatre
/// semaines, moins celle des sept derniers jours, rapportee a la chaleur
/// pleine. Une mesure jamais vue avant cette semaine n'a pas de progres :
/// il n'y a rien a quoi la comparer.
class MeasureProgress {
  MeasureProgress._(this.progress);

  /// Progres par mesure, entre 0 (rien, ou pire) et 1 (de tres dur a propre).
  final Map<int, double> progress;

  static const Duration recent = Duration(days: 7);
  static const Duration horizon = Duration(days: 28);

  /// En dessous, on ne nomme pas : dix points de difficulte.
  static const double seuil = 10 / MeasureHeat.fullHeat;

  static MeasureProgress of(TakeHistory history, String pieceId, DateTime now) {
    final Map<int, List<double>> avant = <int, List<double>>{};
    final Map<int, List<double>> maintenant = <int, List<double>>{};
    for (final TakeRecord t in history.takes) {
      if (!t.key.startsWith('piece:$pieceId:')) {
        continue;
      }
      final Duration age = now.difference(t.at);
      if (age > horizon || age.isNegative) {
        continue;
      }
      final Map<int, List<double>> cible = age <= recent ? maintenant : avant;
      for (final MeasureTrace m in t.measures) {
        cible
            .putIfAbsent(m.measure, () => <double>[])
            .add(m.difficulty.toDouble());
      }
    }
    double moyenne(List<double> v) =>
        v.fold<double>(0, (double s, double x) => s + x) / v.length;
    return MeasureProgress._(<int, double>{
      for (final int m in maintenant.keys)
        if (avant[m] case final List<double> a)
          m: ((moyenne(a) - moyenne(maintenant[m]!)) / MeasureHeat.fullHeat)
              .clamp(0.0, 1.0),
    });
  }

  /// Les mesures qui ont le plus progresse, au plus [count], au-dessus du
  /// seuil, dans l'ordre du morceau.
  List<int> mostImproved({int count = 2}) {
    final List<MapEntry<int, double>> l = <MapEntry<int, double>>[
      for (final MapEntry<int, double> e in progress.entries)
        if (e.value >= seuil) e,
    ]..sort((MapEntry<int, double> a, MapEntry<int, double> b) =>
        b.value.compareTo(a.value));
    return <int>[for (final MapEntry<int, double> e in l.take(count)) e.key]
      ..sort();
  }
}
