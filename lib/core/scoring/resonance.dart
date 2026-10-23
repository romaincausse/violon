import '../music/score_note.dart';
import '../store/take_history.dart';
import 'finger_diagnosis.dart';
import 'live_tuning.dart';

/// La resonance (lot K10) : les notes qui sonnent avec une corde a vide.
///
/// **Sol, re, la, mi et leurs octaves.** Justes, elles font vibrer la corde
/// a vide du meme nom : le violon sonne plus fort, plus longtemps, et c'est
/// ainsi qu'un professeur apprend a ecouter sa justesse plutot qu'a la
/// regarder. Fausses de quelques cents, la corde se tait.
///
/// **Les cordes a vide elles-memes ne se jugent pas ici** : elles disent
/// l'accord de l'instrument, pas la main. Ce que la main place -- le re du 3e
/// doigt sur la corde de la, le sol du 3e doigt sur la corde de re -- se juge
/// plus serre que les autres notes ([ToleranceBand.resonant]).
class Resonance {
  const Resonance._();

  /// La corde a vide que [midi] fait vibrer, ou `null`.
  static ViolinString? stringFor(int midi) {
    if (midi < ViolinString.g.openMidi) {
      return null;
    }
    for (final ViolinString s in ViolinString.values) {
      if ((midi - s.openMidi) % 12 == 0) {
        return s;
      }
    }
    return null;
  }

  /// Une note que la main place, et qui doit faire vibrer une corde a vide.
  static bool judged(int midi) =>
      stringFor(midi) != null &&
      !ViolinString.values.any((ViolinString s) => s.openMidi == midi);

  /// La corde a vide que [notes] font taire le plus nettement dans cette
  /// prise -- la note qui devait sonner et sort le plus de sa marge --, ou
  /// `null`.
  static ViolinString? silencedIn(Iterable<ScoreNote> notes, LiveTuning t) {
    ScoreNote? pire;
    double ecart = 0;
    for (final ScoreNote n in notes) {
      if (!judged(n.midi)) {
        continue;
      }
      final TuningVerdict v = t.verdictFor(n.id);
      final double? c = t.medianCentsFor(n.id);
      if (c != null &&
          (v == TuningVerdict.low || v == TuningVerdict.high) &&
          c.abs() > ecart) {
        pire = n;
        ecart = c.abs();
      }
    }
    final ScoreNote? n = pire;
    return n == null ? null : stringFor(n.midi);
  }

  /// Il faut au moins ces notes, sur plus d'une prise, pour parler d'une
  /// habitude et pas d'un soir.
  static const int minSamples = 6;

  /// En dessous, la corde vibre encore : rien a dire.
  static const double minCents = 10;

  /// La corde a vide que la main fait taire le plus nettement, sur les
  /// [takes] dernieres prises, ou `null` si elles sonnent toutes.
  static ResonanceFinding? of(TakeHistory history, {int takes = 30}) {
    final List<TakeRecord> recentes = history.takes.length > takes
        ? history.takes.sublist(history.takes.length - takes)
        : history.takes;
    final Map<ViolinString, List<double>> ecarts =
        <ViolinString, List<double>>{};
    final Map<ViolinString, Set<int>> prises = <ViolinString, Set<int>>{};
    for (final TakeRecord t in recentes) {
      for (final NoteTrace n in t.notes) {
        final ViolinString? s = judged(n.midi) ? stringFor(n.midi) : null;
        if (s == null) {
          continue;
        }
        ecarts.putIfAbsent(s, () => <double>[]).add(n.cents);
        prises.putIfAbsent(s, () => <int>{}).add(t.atMs);
      }
    }
    ResonanceFinding? pire;
    for (final MapEntry<ViolinString, List<double>> e in ecarts.entries) {
      final List<double> v = List<double>.of(e.value)..sort();
      if (v.length < minSamples || prises[e.key]!.length < 2) {
        continue;
      }
      final double mediane = v[v.length ~/ 2];
      if (mediane.abs() < minCents) {
        continue;
      }
      if (pire == null || mediane.abs() > pire.medianCents.abs()) {
        pire = ResonanceFinding(
          string: e.key,
          medianCents: mediane,
          samples: v.length,
        );
      }
    }
    return pire;
  }
}

/// Une corde a vide que la main ne fait pas vibrer.
class ResonanceFinding {
  const ResonanceFinding({
    required this.string,
    required this.medianCents,
    required this.samples,
  });

  final ViolinString string;
  final double medianCents;
  final int samples;

  bool get flat => medianCents < 0;

  /// En une phrase, comme le dirait le professeur.
  String get sentence => resonanceSentence(string, flat: flat);
}

/// "Ton re ne fait pas vibrer la corde de re : il tombe bas."
String resonanceSentence(ViolinString s, {required bool flat}) =>
    'Ton ${s.name} ne fait pas vibrer la corde de ${s.name} : '
    'il tombe ${flat ? 'bas' : 'haut'}.';

/// La meme chose, comme raison d'une tache : "mesure 7 - ton re ne fait pas
/// vibrer la corde de re".
String resonanceReason(ViolinString s) =>
    'ton ${s.name} ne fait pas vibrer la corde de ${s.name}';
