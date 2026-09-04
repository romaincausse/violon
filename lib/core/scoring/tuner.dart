import '../audio/pitch_smoother.dart';
import '../music/pitch_utils.dart';

/// Ce que l'accordeur a a dire d'une corde entendue.
class TunerReading {
  const TunerReading({
    required this.frequencyHz,
    required this.stringMidi,
    required this.centsOffset,
    required this.inTune,
    required this.steady,
  });

  final double frequencyHz;

  /// Corde a vide la plus proche : sol3, re4, la4 ou mi5.
  final int stringMidi;

  /// Ecart a cette corde, en cents. Negatif si trop grave.
  final double centsOffset;

  /// L'ecart tient dans la tolerance.
  final bool inTune;

  /// La hauteur est assez stable pour qu'on affiche un chiffre.
  ///
  /// Un archet qui demarre fait varier la hauteur de plusieurs dizaines de
  /// cents : afficher l'aiguille pendant ce temps la ferait danser sans rien
  /// dire d'utile.
  final bool steady;

  String get stringName => PitchUtils.noteName(stringMidi);
}

/// Accordeur des quatre cordes a vide.
///
/// **Utile avant meme de jouer.** C'est la premiere chose qu'on fait en
/// ouvrant un etui, et ca ne demande ni partition ni passage.
///
/// **Il ne s'occupe que des cordes a vide.** Un accordeur chromatique dirait
/// "vous etes sur un fa#" quand l'enfant cherche son sol : sur un instrument
/// a quatre cordes connues, se limiter aux quatre est plus sur et plus clair.
class Tuner {
  Tuner({
    this.a4 = PitchUtils.defaultA4,
    this.toleranceCents = 4,
    this.maxExcursionCents = 25,
    this.minConfidence = 0.7,
    this.maxDistanceCents = 250,
  });

  /// Diapason de reference. 440 par defaut ; beaucoup de conservatoires
  /// francais accordent a 442.
  final double a4;

  /// Au-dela, la corde est dite trop haute ou trop basse.
  ///
  /// Quatre cents, c'est exigeant : l'oreille percoit environ cinq cents de
  /// battement sur deux cordes voisines. Une corde "juste a dix cents pres"
  /// ferait sonner faux tout le reste.
  final double toleranceCents;

  /// Au-dela d'une telle oscillation, on n'affiche pas de chiffre.
  final double maxExcursionCents;

  final double minConfidence;

  /// Au-dela de cet ecart avec toute corde a vide, on ne dit rien : l'enfant
  /// joue autre chose, ou c'est du bruit.
  final double maxDistanceCents;

  /// Lit une hauteur, ou rend `null` si elle ne concerne pas l'accordage.
  TunerReading? read(SmoothedPitch pitch) {
    if (pitch.estimate.confidence < minConfidence) {
      return null;
    }
    final int corde = PitchUtils.nearestOpenString(pitch.frequencyHz, a4: a4);
    final double cents = PitchUtils.centsBetween(
      pitch.frequencyHz,
      PitchUtils.midiToFrequency(corde, a4: a4),
    );
    if (cents.abs() > maxDistanceCents) {
      return null;
    }
    final bool stable = pitch.excursionCents <= maxExcursionCents;
    return TunerReading(
      frequencyHz: pitch.frequencyHz,
      stringMidi: corde,
      centsOffset: cents,
      // Une corde n'est declaree juste que si elle tient : sinon l'aiguille
      // passerait au vert en traversant la cible.
      inTune: stable && cents.abs() <= toleranceCents,
      steady: stable,
    );
  }

  /// Diapason qu'il faudrait retenir si l'on decidait de suivre l'accord reel
  /// de l'instrument plutot qu'une reference absolue.
  ///
  /// Rend `null` tant que le la4 n'a pas ete entendu de facon stable. C'est ce
  /// que demande la regle de justesse relative : juger les doigts par rapport
  /// a l'instrument tel qu'il est accorde, pas par rapport a un chiffre.
  double? measuredA4From(SmoothedPitch pitch) {
    final TunerReading? lecture = read(pitch);
    if (lecture == null ||
        !lecture.steady ||
        lecture.stringMidi != _la4 ||
        lecture.centsOffset.abs() > maxEcartDiapasonCents) {
      return null;
    }
    return lecture.frequencyHz;
  }

  /// La corde de la, celle qui donne le diapason.
  static const int _la4 = 69;

  /// Au-dela, ce n'est plus un diapason different mais une corde a accorder.
  /// Cinquante cents separent deja 427 Hz de 440 : aucun orchestre ne descend
  /// aussi bas.
  static const double maxEcartDiapasonCents = 50;
}
