import 'take_history.dart';

/// Un point d'une courbe de progression : un jour de travail.
class ProgressPoint {
  const ProgressPoint({
    required this.day,
    required this.takes,
    this.heldPulseBpm,
    this.tuningScore,
    this.rhythmScore,
  });

  /// Le jour, a minuit, heure locale.
  final DateTime day;

  /// Prises ce jour-la.
  final int takes;

  /// Le meilleur tempo tenu ce jour-la sur une prise allee au bout.
  final int? heldPulseBpm;

  /// La meilleure justesse et le meilleur rythme du jour.
  final int? tuningScore;
  final int? rhythmScore;
}

/// La progression d'un travail, jour apres jour (lot H4).
///
/// **Le meilleur du jour, pas la moyenne.** Une soiree de travail commence
/// toujours plus mal qu'elle ne finit ; la moyenne punirait les premieres
/// prises, qui sont justement celles ou l'on travaille. On montre des
/// **donnees qui montent** : ce que la soiree a permis d'atteindre.
class ProgressSeries {
  ProgressSeries._(this.key, this.title, this.points);

  final String key;
  final String title;
  final List<ProgressPoint> points;

  static ProgressSeries of(TakeHistory history, String key) {
    final List<TakeRecord> prises = history.forKey(key);
    final Map<DateTime, List<TakeRecord>> parJour =
        <DateTime, List<TakeRecord>>{};
    for (final TakeRecord t in prises) {
      final DateTime d = t.at;
      parJour
          .putIfAbsent(DateTime(d.year, d.month, d.day), () => <TakeRecord>[])
          .add(t);
    }
    int? meilleur(Iterable<int?> v) {
      int? m;
      for (final int? x in v) {
        if (x != null && (m == null || x > m)) {
          m = x;
        }
      }
      return m;
    }

    final List<DateTime> jours = parJour.keys.toList()..sort();
    return ProgressSeries._(
      key,
      prises.isEmpty ? key : prises.last.title,
      <ProgressPoint>[
        for (final DateTime j in jours)
          ProgressPoint(
            day: j,
            takes: parJour[j]!.length,
            heldPulseBpm: meilleur(<int?>[
              for (final TakeRecord t in parJour[j]!)
                if (t.reachedEnd) t.heldPulseBpm,
            ]),
            tuningScore: meilleur(
                <int?>[for (final TakeRecord t in parJour[j]!) t.tuningScore]),
            rhythmScore: meilleur(
                <int?>[for (final TakeRecord t in parJour[j]!) t.rhythmScore]),
          ),
      ],
    );
  }

  /// Le meilleur tempo jamais tenu au bout du passage : un record qui ne
  /// redescend jamais.
  int? get bestPulseBpm {
    int? m;
    for (final ProgressPoint p in points) {
      final int? h = p.heldPulseBpm;
      if (h != null && (m == null || h > m)) {
        m = h;
      }
    }
    return m;
  }
}

/// Une seance de travail, le journal d'un jour (lot H5).
class DayJournal {
  DayJournal._(this.day, this.takes);

  final DateTime day;
  final List<TakeRecord> takes;

  /// Le journal du jour de [now].
  static DayJournal of(TakeHistory history, DateTime now) {
    final DateTime jour = DateTime(now.year, now.month, now.day);
    return DayJournal._(jour, <TakeRecord>[
      for (final TakeRecord t in history.takes)
        if (DateTime(t.at.year, t.at.month, t.at.day) == jour) t,
    ]);
  }

  /// Temps joue, prise par prise : ce que l'archet a fait, pas le temps passe
  /// devant l'ecran.
  Duration get playing => Duration(
        milliseconds:
            takes.fold<int>(0, (int s, TakeRecord t) => s + t.durationMs),
      );

  /// Les travaux du jour, dans l'ordre ou ils ont ete abordes.
  List<String> get keys {
    final List<String> vus = <String>[];
    for (final TakeRecord t in takes) {
      if (!vus.contains(t.key)) {
        vus.add(t.key);
      }
    }
    return vus;
  }

  /// Ce qui a monte aujourd'hui pour [key] : le meilleur tempo tenu au bout,
  /// s'il bat tout ce qui precedait ce jour. `null` sinon.
  int? recordFor(TakeHistory history, String key) {
    int? avant;
    int? aujourdhui;
    for (final TakeRecord t in history.forKey(key)) {
      final int? h = t.reachedEnd ? t.heldPulseBpm : null;
      if (h == null) {
        continue;
      }
      if (t.at.isBefore(day)) {
        avant = avant == null || h > avant ? h : avant;
      } else if (takes.contains(t)) {
        aujourdhui = aujourdhui == null || h > aujourdhui ? h : aujourdhui;
      }
    }
    if (aujourdhui == null || (avant != null && aujourdhui <= avant)) {
      return null;
    }
    return aujourdhui;
  }
}
