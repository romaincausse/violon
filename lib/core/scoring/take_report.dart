import 'dart:math' as math;

import '../music/passage.dart';
import '../music/score_note.dart';
import 'live_tuning.dart';
import 'measure_scores.dart';
import 'rhythm_judge.dart';

/// Ce qui rend une mesure fragile, du plus revelateur au moins.
enum Weakness {
  /// Il s'y arrete : la lecture ou le doigte casse (B2).
  stops,

  /// Il la reprend encore et encore : elle fait peur (B1).
  restarts,

  /// Il marque un temps avant une note : il n'ose pas l'attaquer (N4).
  hesitations,

  /// Il saute ou ecourte une note : il en doute (B3).
  avoided,

  /// Il y ralentit nettement, sans s'en rendre compte (C1).
  slowing,

  /// Le rythme n'y est pas, au tempo qu'il tient (N3).
  rhythm,

  /// La justesse n'y est pas (N1).
  tuning,
}

/// Tout ce qu'une prise dit d'une mesure (lot N5).
class MeasureReport {
  MeasureReport({required this.measure, required this.noteCount});

  final int measure;
  final int noteCount;

  /// Justesse sur cent, ou `null` si rien n'a ete entendu.
  int? tuningScore;

  /// Rythme sur cent, au tempo tenu, ou `null` si rien ne s'y enchaine.
  int? rhythmScore;

  /// Fois ou il est revenu a cette mesure (B1).
  int restarts = 0;

  /// Arrets de plus d'une seconde avant une note de cette mesure (B2).
  int stops = 0;

  /// Hesitations avant une note de cette mesure (N4).
  int hesitations = 0;

  /// Notes sautees ou ecourtees (B3), par index dans le passage.
  final List<int> avoided = <int>[];

  /// Tempo local rapporte au tempo tenu (C1) : 0,8 y ralentit de 20 %.
  double? tempoRatio;

  /// Au moins une note de la mesure a ete jouee.
  bool heard = false;

  /// Combien cette mesure demande encore de travail, sans unite : sert a
  /// choisir, jamais a afficher.
  ///
  /// **Les arrets et les reprises pesent plus lourd que la justesse** : une
  /// mesure juste qu'on rejoue quatorze fois est une mesure qui fait peur
  /// (B1), et c'est elle qu'un professeur ferait retravailler.
  double get difficulty {
    double d = 0;
    d += stops * 25;
    d += math.max(0, restarts - 1) * 15;
    d += hesitations * 15;
    d += avoided.length * 15;
    final double? r = tempoRatio;
    if (r != null && r < TakeReport.slowingBelow) {
      d += (TakeReport.slowingBelow - r) * 150;
    }
    final int? ry = rhythmScore;
    if (ry != null) {
      d += (100 - ry) * 0.4;
    }
    final int? ju = tuningScore;
    if (ju != null) {
      d += (100 - ju) * 0.4;
    }
    return d;
  }

  /// Ce qui pese le plus dans [difficulty], ou `null` si rien ne pese.
  Weakness? get mainWeakness {
    final Map<Weakness, double> poids = <Weakness, double>{
      Weakness.stops: stops * 25,
      Weakness.restarts: math.max(0, restarts - 1) * 15.0,
      Weakness.hesitations: hesitations * 15.0,
      Weakness.avoided: avoided.length * 15.0,
      Weakness.slowing:
          tempoRatio != null && tempoRatio! < TakeReport.slowingBelow
              ? (TakeReport.slowingBelow - tempoRatio!) * 150
              : 0,
      Weakness.rhythm: rhythmScore == null ? 0 : (100 - rhythmScore!) * 0.4,
      Weakness.tuning: tuningScore == null ? 0 : (100 - tuningScore!) * 0.4,
    };
    Weakness? pire;
    double max = 0;
    for (final MapEntry<Weakness, double> e in poids.entries) {
      if (e.value > max) {
        max = e.value;
        pire = e.key;
      }
    }
    return pire;
  }
}

/// Le diagnostic d'une prise, mesure par mesure (lots B1, B2, B3, C1, N5).
///
/// **Il ne sert pas a dresser la liste des fautes** -- une partition rouge
/// partout est une regression. Il sert a **choisir une tache** : la mesure qui
/// demande le plus de travail, et la raison qu'on peut lui donner
/// ([nextTask]). Le detail reste disponible pour le bilan et le professeur.
class TakeReport {
  TakeReport._(this.passage, this.rhythm, this.measures);

  final Passage passage;
  final RhythmJudge rhythm;
  final List<MeasureReport> measures;

  /// En dessous, une mesure est dite ralentie : 15 % sous le tempo tenu,
  /// au-dela de ce qu'un rubato d'eleve explique.
  static const double slowingBelow = 0.85;

  /// Une note jouee moins longtemps que ca, rapporte a sa duree ecrite au
  /// tempo tenu, a ete ecourtee.
  static const double shortenedBelow = 0.4;

  /// Une mesure moins difficile que ca n'est pas une tache : tout tient.
  static const double taskAbove = 20;

  static TakeReport of(
    Passage passage,
    RhythmJudge rhythm,
    LiveTuning tuning,
  ) {
    final Map<int, MeasureReport> parMesure = <int, MeasureReport>{};
    for (final ScoreNote n in passage.notes) {
      parMesure.putIfAbsent(
        n.measure,
        () => MeasureReport(
          measure: n.measure,
          noteCount: passage.notes
              .where((ScoreNote x) => x.measure == n.measure)
              .length,
        ),
      );
    }
    MeasureReport de(int noteIndex) =>
        parMesure[passage.notes[noteIndex].measure]!;

    for (final MeasureScore m in scoreByMeasure(passage, tuning)) {
      parMesure[m.measure]?.tuningScore = m.score;
    }

    final List<PlayedEvent> e = rhythm.events;
    final double? noire = rhythm.quarterBpm;
    for (int k = 0; k < e.length; k++) {
      de(e[k].noteIndex).heard = true;
      if (k == 0) {
        continue;
      }
      final PlayedEvent avant = e[k - 1];
      final PlayedEvent ici = e[k];
      final bool arret = ici.startMs - avant.endMs >= RhythmJudge.stopMs;
      if (arret) {
        de(ici.noteIndex).stops++;
      }
      // B1 : revenir en arriere, ou rejouer la meme note, c'est reprendre.
      if (ici.noteIndex <= avant.noteIndex) {
        de(ici.noteIndex).restarts++;
      } else if (!arret &&
          ici.noteIndex - avant.noteIndex >= 2 &&
          ici.noteIndex - avant.noteIndex <= 3) {
        // B3 : une ou deux notes sautees en chemin.
        for (int s = avant.noteIndex + 1; s < ici.noteIndex; s++) {
          de(s).avoided.add(s);
        }
      }
      // B3 : ecourtee, quand elle s'enchaine sur la suivante.
      if (noire != null && !arret && ici.noteIndex == avant.noteIndex + 1) {
        final double ecrit = passage.notes[avant.noteIndex].durationTicks *
            60000 /
            noire /
            passage.ticksPerBeat;
        if (ecrit >= 200 &&
            avant.durationMs < ecrit * shortenedBelow &&
            !de(avant.noteIndex).avoided.contains(avant.noteIndex)) {
          de(avant.noteIndex).avoided.add(avant.noteIndex);
        }
      }
    }

    for (final ScoreNote n in rhythm.hesitations) {
      parMesure[n.measure]!.hesitations++;
    }

    // N3 et C1 : rythme et tempo local, mesure par mesure.
    final Map<int, List<int>> scores = <int, List<int>>{};
    final Map<int, List<double>> tempos = <int, List<double>>{};
    for (final RhythmVerdict v in rhythm.verdicts) {
      final int m = passage.notes[v.noteIndex].measure;
      if (v.score != null) {
        scores.putIfAbsent(m, () => <int>[]).add(v.score!);
        // Un ratio de duree de 1,25 est un tempo local de 0,8.
        tempos.putIfAbsent(m, () => <double>[]).add(1 / v.ratio);
      }
    }
    for (final MeasureReport r in parMesure.values) {
      final List<int>? s = scores[r.measure];
      if (s != null && s.isNotEmpty) {
        r.rhythmScore = (s.reduce((int a, int b) => a + b) / s.length).round();
      }
      final List<double>? t = tempos[r.measure];
      if (t != null && t.length >= 2) {
        final List<double> tries = List<double>.of(t)..sort();
        r.tempoRatio = tries[tries.length ~/ 2];
      }
    }

    final List<MeasureReport> mesures = parMesure.values.toList()
      ..sort(
          (MeasureReport a, MeasureReport b) => a.measure.compareTo(b.measure));
    return TakeReport._(passage, rhythm, mesures);
  }

  /// Les notes sorties de leur marge, dans l'ordre du passage : le detail
  /// pour le professeur (lot T4). Une note par identifiant, avec son ecart
  /// median.
  ///
  /// **A la maison, on ne le montre pas** : le bilan y designe une tache, pas
  /// la liste des fautes. En cours, avec le professeur, le detail redevient
  /// utile -- et il est adresse a personne.
  List<(ScoreNote, double)> notesOff(LiveTuning tuning) =>
      <(ScoreNote, double)>[
        for (final ScoreNote n in passage.notes)
          if (tuning.verdictFor(n.id) == TuningVerdict.low ||
              tuning.verdictFor(n.id) == TuningVerdict.high)
            (n, tuning.medianCentsFor(n.id)!),
      ];

  MeasureReport? byMeasure(int measure) =>
      measures.where((MeasureReport m) => m.measure == measure).firstOrNull;

  /// **La** mesure a retravailler, ou `null` si tout tient.
  ///
  /// Une seule : *"voila ta prochaine tache"*, jamais *"voila tout ce que tu
  /// as rate"*. A difficulte egale, la premiere dans le morceau -- c'est par
  /// la qu'on passe pour aller aux autres.
  MeasureReport? get nextTask {
    MeasureReport? choix;
    for (final MeasureReport m in measures) {
      if (!m.heard || m.difficulty <= taskAbove) {
        continue;
      }
      if (choix == null || m.difficulty > choix.difficulty) {
        choix = m;
      }
    }
    return choix;
  }
}
