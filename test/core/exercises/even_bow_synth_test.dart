import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/exercises/even_bow.dart';
import 'package:violon/core/follow/performance_features.dart';

/// Les archets juges sur un signal de synthese passe par la vraie chaine :
/// extracteur, flux spectral, creux d'energie.
List<BowStroke> juger(Float32List signal) {
  final EvenBow e = EvenBow();
  final List<BowStroke> vus = <BowStroke>[];
  for (final FeatureFrame f in PerformanceFeatures.extract(signal)) {
    final BowStroke? avant = e.last;
    e.hear(f);
    if (e.last != null && !identical(e.last, avant)) {
      vus.add(e.last!);
    }
  }
  e.rest();
  if (e.last != null && (vus.isEmpty || !identical(e.last, vus.last))) {
    vus.add(e.last!);
  }
  return vus;
}

Float32List deuxArchets({double vibrato = 0}) => ViolinSynth(seed: 2).render(
      <BowedNote>[
        BowedNote(
          start: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 3000),
          midi: 69,
          vibratoCents: vibrato,
        ),
        BowedNote(
          start: const Duration(milliseconds: 3200),
          duration: const Duration(milliseconds: 3000),
          midi: 69,
          vibratoCents: vibrato,
        ),
      ],
      length: const Duration(milliseconds: 6600),
    );

void main() {
  test('deux archets egaux, vibres, et le changement d archet les separe', () {
    final List<BowStroke> b = juger(deuxArchets(vibrato: 30));
    expect(b, hasLength(2));
    for (final BowStroke s in b) {
      expect(s.verdict, BowVerdict.even, reason: '${s.spreadDb} dB');
      expect(s.durationMs, closeTo(3000, 150));
    }
  });

  test('le meme archet qui perd dix decibels s eteint', () {
    final Float32List signal = deuxArchets();
    const int sr = 44100;
    // Le second archet s'eteint : de 0 a -10 dB, du debut a la fin.
    for (int i = 3200 * sr ~/ 1000; i < 6200 * sr ~/ 1000; i++) {
      final double x = (i - 3200 * sr / 1000) / (3000 * sr / 1000);
      signal[i] *= math.pow(10, -10 * x / 20).toDouble();
    }
    final List<BowStroke> b = juger(signal);
    expect(b.map((BowStroke s) => s.verdict),
        <BowVerdict>[BowVerdict.even, BowVerdict.fades]);
  });
}
