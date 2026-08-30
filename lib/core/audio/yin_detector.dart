import 'dart:math' as math;
import 'dart:typed_data';

import 'pitch_estimate.dart';

/// Detection de hauteur par l'algorithme YIN.
///
/// Le violon est monophonique : YIN y est tres fiable et suffisamment leger
/// pour tourner en Dart AOT dans un isolate, sur des buffers de 2048
/// echantillons a 44,1 kHz (environ 20 analyses par seconde).
///
/// Reference : de Cheveigne & Kawahara, "YIN, a fundamental frequency
/// estimator for speech and music" (2002).
class YinDetector {
  YinDetector({
    this.sampleRate = 44100,
    this.threshold = 0.15,
    this.minFrequencyHz = 180,
    this.maxFrequencyHz = 3000,
  })  : assert(sampleRate > 0, 'sampleRate doit etre > 0'),
        assert(minFrequencyHz < maxFrequencyHz, 'plage de frequences invalide');

  final int sampleRate;

  /// Seuil d'acceptation YIN. Plus bas = plus exigeant, plus de silences.
  /// 0.15 est un bon compromis sur un violon dans une piece normale.
  final double threshold;

  /// Bornes de recherche. Le sol3 du violon est a 196 Hz ; on descend un peu
  /// en dessous pour tolerer un instrument mal accorde.
  final double minFrequencyHz;
  final double maxFrequencyHz;

  /// Retourne `null` si aucune hauteur fiable n'est trouvee (silence,
  /// changement d'archet, bruit).
  PitchEstimate? detect(Float32List buffer, {int timestampMs = 0}) {
    final int halfSize = buffer.length ~/ 2;
    if (halfSize < 32) {
      return null;
    }

    final Float64List yin = Float64List(halfSize);

    // 1. Fonction de difference.
    for (int tau = 1; tau < halfSize; tau++) {
      double sum = 0;
      for (int i = 0; i < halfSize; i++) {
        final double delta = buffer[i] - buffer[i + tau];
        sum += delta * delta;
      }
      yin[tau] = sum;
    }

    // 2. Normalisation par la moyenne cumulee.
    yin[0] = 1;
    double runningSum = 0;
    for (int tau = 1; tau < halfSize; tau++) {
      runningSum += yin[tau];
      yin[tau] = runningSum == 0 ? 1 : yin[tau] * tau / runningSum;
    }

    // 3. Premier minimum local sous le seuil.
    final int minTau = math.max(2, (sampleRate / maxFrequencyHz).floor());
    final int maxTau =
        math.min(halfSize - 2, (sampleRate / minFrequencyHz).ceil());
    if (minTau >= maxTau) {
      return null;
    }

    int? tauEstimate;
    for (int tau = minTau; tau <= maxTau; tau++) {
      if (yin[tau] < threshold) {
        int candidate = tau;
        while (candidate + 1 <= maxTau && yin[candidate + 1] < yin[candidate]) {
          candidate++;
        }
        tauEstimate = candidate;
        break;
      }
    }
    if (tauEstimate == null) {
      return null;
    }

    // 4. Interpolation parabolique, indispensable pour une precision au cent.
    final double refinedTau = _parabolicInterpolation(yin, tauEstimate);
    if (refinedTau <= 0) {
      return null;
    }

    return PitchEstimate(
      frequencyHz: sampleRate / refinedTau,
      confidence: (1 - yin[tauEstimate]).clamp(0.0, 1.0),
      timestampMs: timestampMs,
    );
  }

  static double _parabolicInterpolation(Float64List yin, int tau) {
    if (tau < 1 || tau >= yin.length - 1) {
      return tau.toDouble();
    }
    final double s0 = yin[tau - 1];
    final double s1 = yin[tau];
    final double s2 = yin[tau + 1];
    final double denominator = 2 * (2 * s1 - s2 - s0);
    if (denominator == 0) {
      return tau.toDouble();
    }
    return tau + (s2 - s0) / denominator;
  }
}
