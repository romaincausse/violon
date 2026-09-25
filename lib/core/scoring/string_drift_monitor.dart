import '../audio/pitch_smoother.dart';
import '../music/pitch_utils.dart';
import 'tuner.dart';

/// Une corde a vide qui a bouge depuis le debut de la seance.
class StringDrift {
  const StringDrift({
    required this.stringMidi,
    required this.centsOffset,
    required this.readings,
  });

  /// Corde concernee : sol3, re4, la4 ou mi5.
  final int stringMidi;

  /// Ecart median a la hauteur attendue, en cents. Negatif si trop grave.
  final double centsOffset;

  /// Nombre de mesures sur lesquelles le verdict repose.
  final int readings;

  /// La corde a baisse. C'est le cas courant : une corde monte rarement
  /// toute seule.
  bool get flat => centsOffset < 0;

  String get stringName => PitchUtils.noteName(stringMidi);
}

/// Surveille l'accord de l'instrument **pendant** qu'on joue.
///
/// **Le probleme qu'il resout.** Un violon se desaccorde en jouant : cordes
/// neuves, chauffage, chevilles qui glissent. Si le mi descend de quinze cents
/// au milieu d'une seance, l'application reproche a l'enfant, pendant une
/// demi-heure, une faute qui appartient a l'instrument. C'est exactement ce
/// que la definition of done interdit.
///
/// **Le materiau est gratuit.** Chaque corde a vide jouee dans le passage est
/// une mesure de l'accord reel, offerte au milieu du morceau, sans rien
/// demander a l'enfant.
///
/// **Le piege est le faux positif, pas la mesure.** Un re joue au quatrieme
/// doigt sur la corde de sol tombe exactement sur la frequence du re a vide.
/// Entendre "un re un peu bas" ne dit donc pas si la corde est fausse ou si
/// le doigt est mal pose -- et se tromper ici serait pire que se taire :
/// l'application enverrait accorder un instrument juste.
///
/// D'ou le discriminant, qui tient en une phrase : **une corde a vide ne peut
/// pas etre jouee faux.** Sa hauteur est mecaniquement fixe, donc elle est
/// identique a chaque fois. Un doigt, lui, se pose un peu differemment a
/// chaque occurrence. On n'accepte donc un verdict que sur une serie
/// **nombreuse et groupee** : une corde desaccordee donne toujours le meme
/// ecart, une main non.
///
/// Deuxieme discriminant, gratuit lui aussi : **on ne fait pas de vibrato sur
/// une corde a vide.** Une mesure qui oscille est ecartee.
class StringDriftMonitor {
  StringDriftMonitor({
    Tuner? tuner,
    this.minReadings = 5,
    this.spreadCents = 8,
    this.alertCents = 15,
    this.windowSize = 12,
  })  : _tuner = tuner ?? Tuner(),
        assert(minReadings > 1, 'une seule mesure ne prouve rien'),
        assert(spreadCents > 0, 'la dispersion doit etre positive'),
        assert(alertCents > 0, 'le seuil d alerte doit etre positif'),
        assert(windowSize >= minReadings, 'la fenetre doit contenir la serie');

  final Tuner _tuner;

  /// Mesures exigees sur une meme corde avant d'oser un verdict.
  final int minReadings;

  /// Dispersion maximale toleree dans la serie.
  ///
  /// C'est le coeur du discriminant. Huit cents, c'est plus serre que ce
  /// qu'une main produit d'une occurrence a l'autre, et plus large que le
  /// bruit de mesure sur une corde tenue.
  final double spreadCents;

  /// Ecart a partir duquel on previent.
  ///
  /// Quinze cents, la ou l'accordeur exige quatre. **Le seuil n'a pas le meme
  /// role dans les deux cas** : on accorde pour etre juste, on previent en
  /// cours de seance pour ne pas interrompre l'enfant pour rien. Un outil qui
  /// envoie accorder toutes les trois minutes ne sera plus ecoute.
  final double alertCents;

  /// Mesures conservees par corde. Au-dela, les plus anciennes sortent : un
  /// accordage en cours de seance doit effacer ce qui precede.
  final int windowSize;

  final Map<int, List<double>> _mesures = <int, List<double>>{};
  final Set<int> _dejaSignalees = <int>{};

  /// Lit une hauteur, et rend une derive **au moment ou elle se confirme**.
  ///
  /// Rend `null` le reste du temps, y compris quand la derive est deja connue :
  /// c'est un evenement, pas un etat. L'etat se lit avec [driftFor].
  StringDrift? observe(SmoothedPitch pitch) {
    if (pitch.vibrato) {
      return null;
    }
    final TunerReading? lecture = _tuner.read(pitch);
    if (lecture == null || !lecture.steady) {
      return null;
    }
    final List<double> serie = _mesures.putIfAbsent(
        lecture.stringMidi, () => <double>[])
      ..add(lecture.centsOffset);
    if (serie.length > windowSize) {
      serie.removeAt(0);
    }

    final StringDrift? derive = driftFor(lecture.stringMidi);
    if (derive == null) {
      // La corde est revenue dans les clous -- on vient sans doute de
      // l'accorder. On pourra donc re-signaler si elle redescend.
      _dejaSignalees.remove(lecture.stringMidi);
      return null;
    }
    if (!_dejaSignalees.add(lecture.stringMidi)) {
      return null;
    }
    return derive;
  }

  /// Derive actuellement etablie sur une corde, ou `null`.
  StringDrift? driftFor(int stringMidi) {
    final List<double>? serie = _mesures[stringMidi];
    if (serie == null || serie.length < minReadings) {
      return null;
    }
    // Seules les dernieres mesures comptent : si la corde a ete accordee en
    // cours de route, ce qui precede ne decrit plus l'instrument.
    final List<double> recentes =
        serie.sublist(serie.length - minReadings, serie.length);
    final double etendue = recentes.reduce(_max) - recentes.reduce(_min);
    if (etendue > spreadCents) {
      return null;
    }
    final double median = _mediane(recentes);
    if (median.abs() < alertCents) {
      return null;
    }
    return StringDrift(
      stringMidi: stringMidi,
      centsOffset: median,
      readings: recentes.length,
    );
  }

  /// Toutes les derives etablies, de la plus grande a la plus petite.
  List<StringDrift> get drifts {
    final List<StringDrift> toutes = <StringDrift>[
      for (final int corde in _mesures.keys)
        if (driftFor(corde) != null) driftFor(corde)!,
    ];
    toutes.sort((StringDrift a, StringDrift b) =>
        b.centsOffset.abs().compareTo(a.centsOffset.abs()));
    return toutes;
  }

  /// Oublie tout : a appeler apres un accordage, ou entre deux seances.
  void reset() {
    _mesures.clear();
    _dejaSignalees.clear();
  }

  static double _max(double a, double b) => a > b ? a : b;
  static double _min(double a, double b) => a < b ? a : b;

  static double _mediane(List<double> valeurs) {
    final List<double> triees = List<double>.of(valeurs)..sort();
    final int milieu = triees.length ~/ 2;
    return triees.length.isOdd
        ? triees[milieu]
        : (triees[milieu - 1] + triees[milieu]) / 2;
  }
}
