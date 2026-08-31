import 'dart:typed_data';

import 'pitch_estimate.dart';
import 'yin_detector.dart';

/// Analyse une trame et rend la hauteur qu'elle contient, s'il y en a une.
///
/// Asynchrone parce que l'implementation reelle traverse un isolate. La
/// version directe existe quand meme : les tests et le developpement de
/// l'interface n'ont pas besoin d'un second thread pour analyser trois
/// sinusoides.
abstract class PitchAnalyzer {
  Future<PitchEstimate?> analyze(
    Float32List samples, {
    required int timestampMs,
  });

  Future<void> dispose();
}

/// Analyse sur place, sur l'isolate appelant.
class InlinePitchAnalyzer implements PitchAnalyzer {
  InlinePitchAnalyzer({YinDetector? detector, int sampleRate = 44100})
      : _detector = detector ?? YinDetector(sampleRate: sampleRate);

  final YinDetector _detector;

  @override
  Future<PitchEstimate?> analyze(
    Float32List samples, {
    required int timestampMs,
  }) async =>
      _detector.detect(samples, timestampMs: timestampMs);

  @override
  Future<void> dispose() async {}
}
