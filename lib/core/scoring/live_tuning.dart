import '../audio/pitch_estimate.dart';
import '../music/pitch_utils.dart';
import '../music/score_note.dart';

/// Ce que l'application a a dire d'une note, pendant qu'elle est jouee.
///
/// Trois verdicts et pas un de plus : a ce stade on ne montre aucun chiffre,
/// seulement une couleur. Un ecart mesure en cents viendra au lot N1, une
/// fois l'attaque exclue et le vibrato lisse.
enum TuningVerdict {
  /// Pas encore assez de son pour se prononcer. Ce n'est pas un echec : c'est
  /// l'etat normal au debut de chaque note, et celui d'un silence.
  unknown,

  low,
  inTune,
  high,
}

/// Justesse en direct, note par note.
///
/// **Contre la note attendue, pas contre la note la plus proche.** Comparer a
/// la note temperee voisine dirait "juste" a un enfant qui joue un demi-ton
/// a cote : il serait parfaitement juste sur la mauvaise note.
///
/// **La mediane, pas la moyenne.** Le vibrato fait osciller la hauteur de 20 a
/// 50 cents volontairement. Une moyenne s'en accommode a peu pres, mais
/// l'attaque -- ou la hauteur glisse sur une centaine de cents en quelques
/// dizaines de millisecondes -- la tirerait franchement. La mediane ignore
/// les deux.
class LiveTuning {
  LiveTuning({
    this.toleranceCents = 35,
    this.minConfidence = 0.7,
    this.minSamples = 2,
    this.a4 = PitchUtils.defaultA4,
  })  : assert(toleranceCents > 0, 'une tolerance est strictement positive'),
        assert(minSamples > 0, 'il faut au moins une mesure');

  /// Au-dela, la note est dite basse ou haute.
  ///
  /// Genereux a dessein. Le projet dit qu'une partition rouge partout est une
  /// regression : mieux vaut ne rien dire que decourager sur un ecart qu'une
  /// oreille de professeur laisserait passer.
  final double toleranceCents;

  /// En dessous, YIN n'a probablement pas entendu une note tenue : changement
  /// d'archet, silence, ou bruit de la piece.
  final double minConfidence;

  /// Mesures necessaires avant d'oser un verdict. Deux trames font une
  /// centaine de millisecondes : de quoi laisser passer l'attaque sans
  /// attendre la fin de la note.
  final int minSamples;

  /// Diapason de reference.
  ///
  /// La justesse se juge par rapport a l'accord reel de l'instrument, pas a
  /// une reference absolue : 440 n'est qu'un repli tant que l'accordeur (lot
  /// A6) n'a pas mesure la vraie valeur.
  final double a4;

  final Map<String, List<double>> _ecarts = <String, List<double>>{};

  /// Enregistre ce qui a ete entendu pendant que [note] etait attendue.
  void observe(ScoreNote note, PitchEstimate estimate) {
    if (estimate.confidence < minConfidence) {
      return;
    }
    final double attendue = PitchUtils.midiToFrequency(note.midi, a4: a4);
    _ecarts
        .putIfAbsent(note.id, () => <double>[])
        .add(PitchUtils.centsBetween(estimate.frequencyHz, attendue));
  }

  /// Ecart median a la note attendue, ou `null` faute de mesures.
  double? medianCentsFor(String noteId) {
    final List<double>? mesures = _ecarts[noteId];
    if (mesures == null || mesures.length < minSamples) {
      return null;
    }
    final List<double> triees = List<double>.of(mesures)..sort();
    final int milieu = triees.length ~/ 2;
    return triees.length.isOdd
        ? triees[milieu]
        : (triees[milieu - 1] + triees[milieu]) / 2;
  }

  TuningVerdict verdictFor(String noteId) {
    final double? cents = medianCentsFor(noteId);
    if (cents == null) {
      return TuningVerdict.unknown;
    }
    if (cents.abs() <= toleranceCents) {
      return TuningVerdict.inTune;
    }
    return cents < 0 ? TuningVerdict.low : TuningVerdict.high;
  }

  /// Mesures retenues pour une note. Sert a savoir si elle a ete entendue.
  int sampleCountFor(String noteId) => _ecarts[noteId]?.length ?? 0;

  /// Oublie tout : a appeler a chaque nouveau passage sur le morceau.
  void reset() => _ecarts.clear();
}
