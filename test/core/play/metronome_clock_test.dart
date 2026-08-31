import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/metronome_clock.dart';

void main() {
  const MetronomeClock a60 = MetronomeClock(tempoBpm: 60);

  group('MetronomeClock', () {
    test('a 60 bpm un temps dure une seconde', () {
      expect(a60.beatDuration, const Duration(seconds: 1));
    });

    test('le temps avance avec le temps ecoule', () {
      expect(a60.beatIndexAt(Duration.zero), 0);
      expect(a60.beatIndexAt(const Duration(milliseconds: 999)), 0);
      expect(a60.beatIndexAt(const Duration(seconds: 1)), 1);
      expect(a60.beatIndexAt(const Duration(seconds: 7)), 7);
    });

    test('la phase parcourt 0 a 1 dans chaque temps', () {
      expect(a60.phaseAt(Duration.zero), 0);
      expect(
          a60.phaseAt(const Duration(milliseconds: 500)), closeTo(0.5, 1e-9));
      expect(a60.phaseAt(const Duration(milliseconds: 999)), lessThan(1));
      expect(a60.phaseAt(const Duration(seconds: 1)), 0, reason: 'elle repart');
    });

    test('avant le depart, rien ne bouge', () {
      expect(a60.beatIndexAt(const Duration(seconds: -3)), 0);
      expect(a60.phaseAt(const Duration(seconds: -3)), 0);
    });

    test('le musicien compte de 1 a 4', () {
      const MetronomeClock c = MetronomeClock(tempoBpm: 60, beatsPerMeasure: 4);
      final List<int> comptes = <int>[
        for (int s = 0; s < 5; s++) c.beatInMeasureAt(Duration(seconds: s)),
      ];
      expect(comptes, <int>[1, 2, 3, 4, 1]);
    });

    test('le premier temps de chaque mesure est un temps fort', () {
      const MetronomeClock c = MetronomeClock(tempoBpm: 60, beatsPerMeasure: 3);
      expect(c.isDownbeatAt(Duration.zero), isTrue);
      expect(c.isDownbeatAt(const Duration(seconds: 1)), isFalse);
      expect(c.isDownbeatAt(const Duration(seconds: 3)), isTrue);
      expect(c.measureIndexAt(const Duration(seconds: 3)), 1);
    });

    test('un tempo non divisible ne derive pas sur une longue seance', () {
      // 92 bpm : un temps vaut 652 173,913... us, qu'aucun entier ne
      // represente. Compter en passant par une duree arrondie decalait le
      // battement d'environ une milliseconde par dix minutes -- ce test
      // echouait avant que le calcul passe au rationnel exact.
      const MetronomeClock c = MetronomeClock(tempoBpm: 92);
      const Duration dixMinutes = Duration(minutes: 10);
      const int attendu = (92 * 10);
      expect(c.beatIndexAt(dixMinutes), attendu);

      // Et le temps juste avant le battement suivant est bien le precedent.
      final Duration justeAvant = dixMinutes - const Duration(microseconds: 1);
      expect(c.beatIndexAt(justeAvant), attendu - 1);
    });

    test('le calcul ne depend que du temps absolu, jamais du chemin suivi', () {
      const MetronomeClock c = MetronomeClock(tempoBpm: 137);
      const Duration t = Duration(milliseconds: 45123);
      // Deux appels identiques, et un appel apres avoir interroge d'autres
      // instants : rien ne doit bouger. C'est ce qu'un compteur accumule ne
      // saurait pas garantir.
      final int premier = c.beatIndexAt(t);
      c.beatIndexAt(const Duration(milliseconds: 1));
      c.beatIndexAt(const Duration(minutes: 3));
      expect(c.beatIndexAt(t), premier);
    });
  });
}
