import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/yin_detector.dart';

/// Genere une sinusoide pure, avec quelques harmoniques optionnelles pour
/// s'approcher d'un timbre de violon.
Float32List synthesize(
  double frequencyHz, {
  int sampleRate = 44100,
  int length = 4096,
  double amplitude = 0.6,
  bool withHarmonics = false,
}) {
  final Float32List buffer = Float32List(length);
  for (int i = 0; i < length; i++) {
    final double t = i / sampleRate;
    double sample = math.sin(2 * math.pi * frequencyHz * t);
    if (withHarmonics) {
      sample += 0.5 * math.sin(2 * math.pi * 2 * frequencyHz * t);
      sample += 0.3 * math.sin(2 * math.pi * 3 * frequencyHz * t);
      sample /= 1.8;
    }
    buffer[i] = amplitude * sample;
  }
  return buffer;
}

void main() {
  final YinDetector detector = YinDetector();

  group('YinDetector', () {
    test('retrouve les quatre cordes a vide a moins de 5 cents', () {
      const Map<String, double> strings = <String, double>{
        'sol3': 196.00,
        're4': 293.66,
        'la4': 440.00,
        'mi5': 659.26,
      };

      strings.forEach((String name, double frequency) {
        final PitchEstimate? estimate = detector.detect(synthesize(frequency));
        expect(estimate, isNotNull, reason: '$name non detecte');
        final double error =
            1200 * (math.log(estimate!.frequencyHz / frequency) / math.ln2);
        expect(error.abs(), lessThan(5), reason: '$name imprecis');
      });
    });

    test('tient sur un timbre riche en harmoniques (pas d\'erreur d\'octave)',
        () {
      final PitchEstimate? estimate =
          detector.detect(synthesize(440, withHarmonics: true));
      expect(estimate, isNotNull);
      expect(estimate!.frequencyHz, closeTo(440, 5));
      expect(estimate.nearestMidi, 69);
    });

    test('renvoie null sur du silence', () {
      expect(detector.detect(Float32List(4096)), isNull);
    });

    test('renvoie null sur un buffer trop court', () {
      expect(detector.detect(synthesize(440, length: 32)), isNull);
    });

    test('ignore les frequences hors plage du violon', () {
      // 80 Hz, sous le sol3 : hors de la plage de recherche.
      final PitchEstimate? estimate = detector.detect(synthesize(80));
      expect(estimate?.frequencyHz ?? 0, lessThan(1000));
    });

    test('donne une confiance elevee sur un signal propre', () {
      final PitchEstimate? estimate = detector.detect(synthesize(440));
      expect(estimate!.confidence, greaterThan(0.8));
    });
  });
}
