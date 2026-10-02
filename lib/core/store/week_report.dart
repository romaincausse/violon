import '../music/pitch_utils.dart';
import '../scoring/finger_diagnosis.dart';
import 'take_history.dart';

/// Ce qu'un travail a donne cette semaine.
class WorkWeek {
  const WorkWeek({
    required this.key,
    required this.title,
    required this.takes,
    this.bestPulseBpm,
    this.previousBestPulseBpm,
    this.bestTuning,
    this.bestRhythm,
  });

  final String key;
  final String title;
  final int takes;

  /// Le meilleur tempo tenu au bout, cette semaine.
  final int? bestPulseBpm;

  /// Le meilleur d'avant cette semaine, pour dire ce qui a monte.
  final int? previousBestPulseBpm;
  final int? bestTuning;
  final int? bestRhythm;

  /// Le tempo a monte cette semaine.
  bool get rose =>
      bestPulseBpm != null &&
      (previousBestPulseBpm == null || bestPulseBpm! > previousBestPulseBpm!);
}

/// Une mesure qui resiste encore.
class ResistingMeasure {
  const ResistingMeasure({
    required this.title,
    required this.measure,
    required this.restarts,
    required this.stops,
  });

  final String title;
  final int measure;

  /// Fois ou il y est revenu cette semaine : souvent plus parlant que le
  /// score (une mesure rejouee quatorze fois fait peur).
  final int restarts;
  final int stops;
}

/// Une note jouee de travers avec constance : un fait, pas un jugement.
class NoteFact {
  const NoteFact({
    required this.midi,
    required this.medianCents,
    required this.off,
    required this.total,
  });

  final int midi;
  final double medianCents;

  /// Prises ou elle est sortie du meme cote, sur [total].
  final int off;
  final int total;
}

/// Le rapport de la semaine, pour le professeur (lot T2).
///
/// **Il se lit comme un progres, jamais comme un releve de surveillance**
/// (`docs/professeur.md`). D'ou trois choix :
///
/// - les jours **joues**, jamais les jours manques -- un jour sans travail
///   n'est pas une absence a justifier ;
/// - **ce qui a monte** en tete : tempos battus, meilleures notes ;
/// - ce qui resiste encore, dit comme un fait et adresse a personne :
///   *"mesure 12, reprise 14 fois"*, *"do#5 bas de 22 cents, 9 prises sur 10"*.
class WeekReport {
  WeekReport._({
    required this.from,
    required this.to,
    required this.days,
    required this.works,
    required this.resisting,
    required this.finger,
    required this.noteFact,
  });

  final DateTime from;
  final DateTime to;

  /// Les jours joues, et les minutes d'archet de chacun.
  final Map<DateTime, Duration> days;
  final List<WorkWeek> works;
  final List<ResistingMeasure> resisting;
  final FingerFinding? finger;
  final NoteFact? noteFact;

  Duration get playing =>
      days.values.fold(Duration.zero, (Duration a, Duration b) => a + b);

  int get takes => works.fold(0, (int n, WorkWeek w) => n + w.takes);

  /// Au-dela de cet ecart, une note est sortie de son cote.
  static const double offCents = 15;

  /// La semaine qui finit a [now] : les sept derniers jours, aujourd'hui
  /// compris.
  static WeekReport of(TakeHistory history, DateTime now) {
    final DateTime fin = DateTime(now.year, now.month, now.day + 1);
    final DateTime debut = fin.subtract(const Duration(days: 7));
    bool cetteSemaine(TakeRecord t) =>
        !t.at.isBefore(debut) && t.at.isBefore(fin);
    final List<TakeRecord> semaine = history.takes.where(cetteSemaine).toList();

    final Map<DateTime, Duration> jours = <DateTime, Duration>{};
    for (final TakeRecord t in semaine) {
      final DateTime j = DateTime(t.at.year, t.at.month, t.at.day);
      jours[j] =
          (jours[j] ?? Duration.zero) + Duration(milliseconds: t.durationMs);
    }

    final List<WorkWeek> travaux = <WorkWeek>[];
    final List<String> cles = <String>[];
    for (final TakeRecord t in semaine) {
      if (!cles.contains(t.key)) {
        cles.add(t.key);
      }
    }
    int? maxi(Iterable<int?> v) {
      int? m;
      for (final int? x in v) {
        if (x != null && (m == null || x > m)) {
          m = x;
        }
      }
      return m;
    }

    for (final String k in cles) {
      final List<TakeRecord> ici =
          semaine.where((TakeRecord t) => t.key == k).toList();
      final List<TakeRecord> avant = history.takes
          .where((TakeRecord t) => t.key == k && t.at.isBefore(debut))
          .toList();
      travaux.add(
        WorkWeek(
          key: k,
          title: ici.last.title,
          takes: ici.length,
          bestPulseBpm: maxi(<int?>[
            for (final TakeRecord t in ici)
              if (t.reachedEnd) t.heldPulseBpm,
          ]),
          previousBestPulseBpm: maxi(<int?>[
            for (final TakeRecord t in avant)
              if (t.reachedEnd) t.heldPulseBpm,
          ]),
          bestTuning:
              maxi(<int?>[for (final TakeRecord t in ici) t.tuningScore]),
          bestRhythm:
              maxi(<int?>[for (final TakeRecord t in ici) t.rhythmScore]),
        ),
      );
    }
    // Ce qui a monte d'abord.
    travaux.sort((WorkWeek a, WorkWeek b) {
      if (a.rose != b.rose) {
        return a.rose ? -1 : 1;
      }
      return b.takes.compareTo(a.takes);
    });

    // Les mesures qui resistent : les reprises d'abord, puis les arrets.
    final Map<(String, int), (int, int)> parMesure =
        <(String, int), (int, int)>{};
    for (final TakeRecord t in semaine) {
      for (final MeasureTrace m in t.measures) {
        final (int r, int s) = parMesure[(t.title, m.measure)] ?? (0, 0);
        parMesure[(t.title, m.measure)] = (r + m.restarts, s + m.stops);
      }
    }
    final List<ResistingMeasure> resistent = <ResistingMeasure>[
      for (final MapEntry<(String, int), (int, int)> e in parMesure.entries)
        if (e.value.$1 >= 3 || e.value.$2 >= 2)
          ResistingMeasure(
            title: e.key.$1,
            measure: e.key.$2,
            restarts: e.value.$1,
            stops: e.value.$2,
          ),
    ]..sort((ResistingMeasure a, ResistingMeasure b) {
        final int c = b.restarts.compareTo(a.restarts);
        return c != 0 ? c : b.stops.compareTo(a.stops);
      });

    return WeekReport._(
      from: debut,
      to: fin.subtract(const Duration(days: 1)),
      days: jours,
      works: travaux,
      resisting: resistent.take(3).toList(),
      finger: FingerDiagnosis.of(TakeHistory(semaine)).main,
      noteFact: _noteLaPlusConstante(semaine),
    );
  }

  /// La note la plus constamment sortie du meme cote : au moins quatre
  /// prises, et dans trois sur quatre au moins.
  static NoteFact? _noteLaPlusConstante(List<TakeRecord> semaine) {
    final Map<int, List<double>> parNote = <int, List<double>>{};
    for (final TakeRecord t in semaine) {
      // Une valeur par prise et par note : c'est "9 prises sur 10", pas
      // "40 croches sur 41".
      final Map<int, List<double>> ici = <int, List<double>>{};
      for (final NoteTrace n in t.notes) {
        ici.putIfAbsent(n.midi, () => <double>[]).add(n.cents);
      }
      for (final MapEntry<int, List<double>> e in ici.entries) {
        final List<double> v = e.value..sort();
        parNote.putIfAbsent(e.key, () => <double>[]).add(v[v.length ~/ 2]);
      }
    }
    NoteFact? meilleure;
    for (final MapEntry<int, List<double>> e in parNote.entries) {
      final List<double> v = List<double>.of(e.value)..sort();
      if (v.length < 4) {
        continue;
      }
      final double mediane = v[v.length ~/ 2];
      if (mediane.abs() < offCents) {
        continue;
      }
      final int meme = v
          .where((double c) => mediane < 0 ? c <= -offCents : c >= offCents)
          .length;
      if (meme * 4 < v.length * 3) {
        continue;
      }
      if (meilleure == null ||
          meme / v.length > meilleure.off / meilleure.total) {
        meilleure = NoteFact(
          midi: e.key,
          medianCents: mediane,
          off: meme,
          total: v.length,
        );
      }
    }
    return meilleure;
  }

  /// Le rapport en texte, pour le copier ou l'enregistrer (lot T3).
  String toText() {
    String jour(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final StringBuffer b = StringBuffer()
      ..writeln('Ma semaine de violon, du ${jour(from)} au ${jour(to)}')
      ..writeln();
    if (days.isEmpty) {
      b.writeln('Pas encore de prise suivie cette semaine.');
      return b.toString();
    }
    b
      ..writeln('${days.length} jour${days.length > 1 ? 's' : ''} de travail, '
          '${playing.inMinutes} min d archet, $takes prise${takes > 1 ? 's' : ''}.')
      ..writeln();
    for (final WorkWeek w in works) {
      final List<String> d = <String>[
        '${w.takes} prise${w.takes > 1 ? 's' : ''}',
        if (w.bestPulseBpm != null)
          w.rose && w.previousBestPulseBpm != null
              ? 'tempo ${w.previousBestPulseBpm} -> ${w.bestPulseBpm}'
              : 'tempo tenu ${w.bestPulseBpm}',
        if (w.bestTuning != null) 'justesse ${w.bestTuning}',
        if (w.bestRhythm != null) 'rythme ${w.bestRhythm}',
      ];
      b.writeln('- ${w.title} : ${d.join(', ')}');
    }
    if (resisting.isNotEmpty || finger != null || noteFact != null) {
      b
        ..writeln()
        ..writeln('Ce qui resiste encore :');
      for (final ResistingMeasure r in resisting) {
        b.writeln('- ${r.title}, mesure ${r.measure} : '
            '${<String>[
          if (r.restarts > 0) 'reprise ${r.restarts} fois',
          if (r.stops > 0) '${r.stops} arret${r.stops > 1 ? 's' : ''}',
        ].join(', ')}');
      }
      final FingerFinding? f = finger;
      if (f != null) {
        b.writeln('- ${f.place.label} : ${f.flat ? 'bas' : 'haut'} de '
            '${f.medianCents.abs().round()} cents, sur ${f.strings.length} '
            'corde${f.strings.length > 1 ? 's' : ''}');
      }
      final NoteFact? n = noteFact;
      if (n != null) {
        b.writeln('- ${PitchUtils.noteName(n.midi)} : '
            '${n.medianCents < 0 ? 'bas' : 'haut'} de '
            '${n.medianCents.abs().round()} cents, ${n.off} prises sur '
            '${n.total}');
      }
    }
    return b.toString();
  }
}
