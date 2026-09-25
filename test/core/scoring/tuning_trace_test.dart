import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/scoring/tuning_trace.dart';

void main() {
  group('TuningTrace', () {
    test('un trace neuf est vide', () {
      final TuningTrace t = TuningTrace();
      expect(t.isEmpty, isTrue);
      expect(t.latestMs, isNull);
    });

    test('les points sortent dans l ordre ou ils entrent', () {
      final TuningTrace t = TuningTrace();
      t.add(0, -10);
      t.add(50, 5);
      t.add(100, 20);

      expect(t.points.map((TracePoint p) => p.cents), <double>[-10, 5, 20]);
      expect(t.latestMs, 100);
    });

    test('ce qui sort de la fenetre est oublie', () {
      // La fenetre est relative au point le plus recent : a 1200 ms, elle
      // commence a 200 ms. Le point a 0 ms en sort, celui a 500 ms y reste.
      final TuningTrace t = TuningTrace(windowMs: 1000);
      t.add(0, 1);
      t.add(500, 2);
      t.add(1200, 3);

      expect(t.points.map((TracePoint p) => p.cents), <double>[2, 3]);
    });

    test('la fenetre borne le temps, pas le nombre de points', () {
      // Garder les N derniers points parait plus simple, mais le micro perd
      // des trames sous charge : le trace se dilaterait et se contracterait
      // sans que rien n'ait change dans le jeu.
      final TuningTrace dense = TuningTrace(windowMs: 1000);
      final TuningTrace clairseme = TuningTrace(windowMs: 1000);
      for (int ms = 0; ms <= 1000; ms += 20) {
        dense.add(ms, 0);
      }
      for (int ms = 0; ms <= 1000; ms += 200) {
        clairseme.add(ms, 0);
      }

      expect(dense.points.length, greaterThan(clairseme.points.length));
      for (final TuningTrace t in <TuningTrace>[dense, clairseme]) {
        final int etendue =
            t.points.last.timestampMs - t.points.first.timestampMs;
        expect(etendue, lessThanOrEqualTo(1000));
      }
    });

    test('un garde-fou empeche le trace de grossir sans fin', () {
      final TuningTrace t = TuningTrace(windowMs: 1000000, maxPoints: 10);
      for (int i = 0; i < 100; i++) {
        t.add(i, i.toDouble());
      }
      expect(t.points, hasLength(10));
      expect(t.points.last.cents, 99);
    });

    test('un horodatage qui recule repart de zero', () {
      // Une nouvelle prise remet l'horloge du micro a zero. Garder l'ancien
      // trace dessinerait un aller-retour dans le temps.
      final TuningTrace t = TuningTrace();
      t.add(3000, 10);
      t.add(3050, 12);
      t.add(0, -5);

      expect(t.points, hasLength(1));
      expect(t.points.single.cents, -5);
    });

    test('un point isole subsiste, meme vieux', () {
      // Elaguer jusqu'au vide ferait clignoter le ruban entre deux notes.
      final TuningTrace t = TuningTrace(windowMs: 100);
      t.add(0, 7);
      t.add(5000, 9);
      expect(t.points, hasLength(1));
      expect(t.points.single.cents, 9);
    });

    test('remettre a zero efface le trace', () {
      final TuningTrace t = TuningTrace();
      t.add(0, 1);
      t.reset();
      expect(t.isEmpty, isTrue);
    });
  });
}
