import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/exercises/vibrato_meter.dart';
import 'package:violon/core/follow/performance_features.dart';

/// Une note de [ms] millisecondes autour du la4, vibree a [hz] sur [cents]
/// de part et d'autre, une trame toutes les 23 ms.
List<FeatureFrame> vibree(double hz, double cents, int ms, {int de = 0}) =>
    <FeatureFrame>[
      for (int t = de; t < de + ms; t += 23)
        FeatureFrame(
          timeMs: t,
          midi: 69 + cents / 100 * math.sin(2 * math.pi * hz * (t - de) / 1000),
          rms: 0.05,
          onset: t == de,
        ),
    ];

void main() {
  group('sur des trames', () {
    test('trois oscillations par seconde, sur 25 cents : mesure et record', () {
      final VibratoMeter v = VibratoMeter();
      for (final FeatureFrame f in vibree(3, 25, 4000)) {
        v.hear(f);
      }
      final VibratoReading r = v.current!;
      expect(r.rateHz, closeTo(3, 0.2));
      expect(r.amplitudeCents, closeTo(25, 5));
      expect(r.regular, isTrue);
      expect(r.perBeat(60), closeTo(3, 0.2));
      expect(v.regularMs, greaterThan(2500));
      v.rest();
      expect(v.bestMs, greaterThan(2500));
      expect(v.current, isNull);
    });

    test('une note droite n oscille pas, un vibrato trop etroit non plus', () {
      final VibratoMeter v = VibratoMeter();
      for (final FeatureFrame f in vibree(5, 0, 2000)) {
        v.hear(f);
      }
      expect(v.current, isNull);
      for (final FeatureFrame f in vibree(5, 3, 2000, de: 3000)) {
        v.hear(f);
      }
      expect(v.bestMs, 0);
    });

    test('une oscillation qui traine casse la serie, le record reste', () {
      final VibratoMeter v = VibratoMeter(bestMs: 1500);
      for (final FeatureFrame f in <FeatureFrame>[
        ...vibree(4, 25, 2000),
        // Une demi-seconde a 1,5 par seconde : la main s'est arretee.
        ...vibree(1.5, 25, 700, de: 2000),
      ]) {
        v.hear(f);
      }
      expect(v.bestMs, greaterThanOrEqualTo(1500));
      expect(v.regularMs, lessThan(1000));
    });

    test('changer de note recommence la mesure', () {
      final VibratoMeter v = VibratoMeter();
      for (final FeatureFrame f in vibree(4, 25, 1500)) {
        v.hear(f);
      }
      v.hear(
          const FeatureFrame(timeMs: 1500, midi: 71, rms: 0.05, onset: true));
      expect(v.current, isNull);
      expect(v.bestMs, greaterThan(800));
    });
  });

  group('sur une synthese passee par la vraie chaine', () {
    List<int> mesurer(double hz, double cents) {
      final VibratoMeter v = VibratoMeter();
      VibratoReading? lu;
      for (final FeatureFrame f in PerformanceFeatures.extract(
        ViolinSynth(seed: 4).render(
          <BowedNote>[
            BowedNote(
              start: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 4000),
              midi: 69,
              vibratoCents: cents,
              vibratoHz: hz,
            ),
          ],
          length: const Duration(milliseconds: 4500),
        ),
      )) {
        v.hear(f);
        lu = v.current ?? lu;
      }
      v.rest();
      return <int>[
        ((lu?.rateHz ?? 0) * 10).round(),
        (lu?.amplitudeCents ?? 0).round(),
        v.bestMs,
      ];
    }

    test('2, 3, 4 et 6 par seconde se mesurent, et tiennent la note', () {
      for (final double hz in <double>[2, 3, 4, 6]) {
        final List<int> m = mesurer(hz, 30);
        expect(m[0] / 10, closeTo(hz, hz * 0.1), reason: '$hz Hz : $m');
        expect(m[1], closeTo(30, 8), reason: '$hz Hz : $m');
        expect(m[2], greaterThan(2500), reason: '$hz Hz : $m');
      }
    });

    test('sans vibrato, aucune note vibree', () {
      expect(mesurer(5.5, 0)[2], 0);
    });
  });
}
