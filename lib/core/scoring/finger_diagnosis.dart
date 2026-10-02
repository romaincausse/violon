import '../store/take_history.dart';

/// Un doigt de la main gauche, et ou il se pose sur la corde.
///
/// **En premiere position**, ce que joue un eleve de quatrieme annee la
/// plupart du temps : de la corde a vide, chaque demi-ton designe un doigt
/// et une place -- le 2e doigt "bas" pour la tierce mineure, "haut" pour la
/// majeure. C'est ainsi que le professeur en parle, et c'est ainsi que la main
/// se trompe : une place mal apprise se retrouve sur toutes les cordes.
enum FingerPlace {
  low1(1, '1er doigt bas'),
  one(2, '1er doigt'),
  low2(3, '2e doigt bas'),
  high2(4, '2e doigt haut'),
  three(5, '3e doigt'),
  high3(6, '3e doigt haut');

  const FingerPlace(this.semitones, this.label);

  /// Demi-tons au-dessus de la corde a vide.
  final int semitones;
  final String label;
}

/// Les quatre cordes, a vide.
enum ViolinString {
  g(55, 'sol'),
  d(62, 're'),
  a(69, 'la'),
  e(76, 'mi');

  const ViolinString(this.openMidi, this.name);

  final int openMidi;
  final String name;
}

/// La corde et le doigt d'une note jouee en premiere position, ou `null`
/// pour une corde a vide ou une note hors de la premiere position.
(ViolinString, FingerPlace)? fingeringOf(int midi) {
  for (final ViolinString s in ViolinString.values.reversed) {
    final int k = midi - s.openMidi;
    if (k >= 0 && k <= 6) {
      if (k == 0) {
        return null;
      }
      return (
        s,
        FingerPlace.values.firstWhere((FingerPlace f) => f.semitones == k)
      );
    }
  }
  return null;
}

/// Ce que la main fait systematiquement d'un doigt.
class FingerFinding {
  const FingerFinding({
    required this.place,
    required this.medianCents,
    required this.samples,
    required this.strings,
  });

  final FingerPlace place;

  /// L'ecart median, toutes cordes confondues : negatif, le doigt tombe bas.
  final double medianCents;
  final int samples;

  /// Les cordes ou on l'a entendu.
  final Set<ViolinString> strings;

  bool get flat => medianCents < 0;
}

/// Les erreurs systematiques de la main gauche (lot H3).
///
/// **Le differenciateur.** Un score par note dit "ce fa# est bas". Le
/// diagnostic par doigt dit **pourquoi** : le 2e doigt haut tombe bas, sur
/// la corde de re comme sur celle de la, dans toutes les mesures. C'est ce
/// qu'un professeur entend apres trois mesures, et qu'aucun accordeur ne sait
/// dire.
///
/// **Systematique veut dire repete** : il faut assez de notes, et sur plus
/// d'une corde ou plus d'une prise, pour parler de la main et pas d'un
/// accident. Les cordes a vide sont ecartees : elles disent l'accord de
/// l'instrument, pas la main.
class FingerDiagnosis {
  FingerDiagnosis._(this.findings);

  /// Les doigts qui derivent, du plus net au moins net.
  final List<FingerFinding> findings;

  /// Il faut au moins ces notes pour parler d'un doigt.
  static const int minSamples = 6;

  /// En dessous, l'ecart median n'est pas un defaut de la main : il tient
  /// dans ce qu'un violon et une oreille d'eleve laissent passer.
  static const double minCents = 12;

  /// Le doigt le plus net, ou `null` si la main tombe juste.
  FingerFinding? get main => findings.isEmpty ? null : findings.first;

  /// Les prises recentes de [history] : les [takes] dernieres.
  static FingerDiagnosis of(TakeHistory history, {int takes = 30}) {
    final List<TakeRecord> recentes = history.takes.length > takes
        ? history.takes.sublist(history.takes.length - takes)
        : history.takes;
    final Map<FingerPlace, List<double>> ecarts = <FingerPlace, List<double>>{};
    final Map<FingerPlace, Set<ViolinString>> cordes =
        <FingerPlace, Set<ViolinString>>{};
    final Map<FingerPlace, Set<int>> prises = <FingerPlace, Set<int>>{};
    for (final TakeRecord t in recentes) {
      for (final NoteTrace n in t.notes) {
        final (ViolinString, FingerPlace)? f = fingeringOf(n.midi);
        if (f == null) {
          continue;
        }
        ecarts.putIfAbsent(f.$2, () => <double>[]).add(n.cents);
        cordes.putIfAbsent(f.$2, () => <ViolinString>{}).add(f.$1);
        prises.putIfAbsent(f.$2, () => <int>{}).add(t.atMs);
      }
    }
    final List<FingerFinding> trouves = <FingerFinding>[];
    for (final MapEntry<FingerPlace, List<double>> e in ecarts.entries) {
      final List<double> v = List<double>.of(e.value)..sort();
      if (v.length < minSamples) {
        continue;
      }
      if (cordes[e.key]!.length < 2 && prises[e.key]!.length < 2) {
        continue;
      }
      final double mediane = v[v.length ~/ 2];
      if (mediane.abs() < minCents) {
        continue;
      }
      trouves.add(
        FingerFinding(
          place: e.key,
          medianCents: mediane,
          samples: v.length,
          strings: cordes[e.key]!,
        ),
      );
    }
    trouves.sort((FingerFinding a, FingerFinding b) =>
        b.medianCents.abs().compareTo(a.medianCents.abs()));
    return FingerDiagnosis._(trouves);
  }
}
