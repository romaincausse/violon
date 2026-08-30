import '../music/pitch_utils.dart';

/// Resultat d'une analyse de hauteur sur un buffer audio.
class PitchEstimate {
  const PitchEstimate({
    required this.frequencyHz,
    required this.confidence,
    required this.timestampMs,
  });

  final double frequencyHz;

  /// Entre 0 et 1. En dessous de ~0.7 sur un violon, on ignore la mesure :
  /// c'est generalement un changement d'archet ou du silence.
  final double confidence;

  final int timestampMs;

  int get nearestMidi => PitchUtils.nearestMidiNote(frequencyHz);
  double get centsOffset => PitchUtils.centsOffset(frequencyHz);
  String get noteName => PitchUtils.noteName(nearestMidi);

  @override
  String toString() =>
      'PitchEstimate($noteName, ${centsOffset.toStringAsFixed(1)} cents, '
      'conf=${confidence.toStringAsFixed(2)})';
}
