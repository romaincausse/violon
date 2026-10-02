import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/accompaniment_plan.dart';
import 'package:violon/core/play/humanize.dart';

void main() {
  TimedNote note(int midi, int ms, {double velocity = 0.5}) => TimedNote(
        at: Duration(milliseconds: ms),
        duration: const Duration(milliseconds: 400),
        midi: midi,
        velocity: velocity,
      );

  group('Humanizer', () {
    const Humanizer main = Humanizer();

    test('une note seule garde son instant exact', () {
      final List<TimedNote> n = main.apply(<TimedNote>[note(43, 1000)]);
      expect(n.single.at, const Duration(milliseconds: 1000));
      expect(n.single.midi, 43);
    });

    test('un accord s egrene de bas en haut, de quelques millisecondes', () {
      final List<TimedNote> n = main.apply(<TimedNote>[
        note(67, 2000),
        note(60, 2000),
        note(64, 2000),
      ]);
      expect(n.map((TimedNote x) => x.midi), <int>[60, 64, 67]);
      expect(n[0].at, const Duration(milliseconds: 2000));
      expect(n[1].at, const Duration(milliseconds: 2006));
      expect(n[2].at, const Duration(milliseconds: 2012));
    });

    test('l egrenage est borne, meme a six notes', () {
      final List<TimedNote> n = main.apply(<TimedNote>[
        for (int m = 48; m < 72; m += 4) note(m, 0),
      ]);
      expect(n.last.at, const Duration(milliseconds: 18));
    });

    test('la force varie a peine, et toujours pareil', () {
      final List<TimedNote> a = main.apply(<TimedNote>[
        note(60, 0),
        note(60, 500),
        note(60, 1000),
      ]);
      final List<TimedNote> b = main.apply(<TimedNote>[
        note(60, 0),
        note(60, 500),
        note(60, 1000),
      ]);
      for (int i = 0; i < a.length; i++) {
        expect(a[i].velocity, b[i].velocity, reason: 'deterministe');
        expect(a[i].velocity, inInclusiveRange(0.47, 0.53));
      }
      // Trois notes identiques ne sortent pas toutes a la meme force.
      expect(a.map((TimedNote x) => x.velocity).toSet().length, greaterThan(1));
    });

    test('la force reste entre zero et un', () {
      final List<TimedNote> n = main.apply(<TimedNote>[
        note(60, 0, velocity: 1),
        note(64, 0, velocity: 1),
        note(67, 0, velocity: 1),
      ]);
      for (final TimedNote x in n) {
        expect(x.velocity, lessThanOrEqualTo(1));
      }
    });

    test('la sortie est triee par instant', () {
      final List<TimedNote> n = main.apply(<TimedNote>[
        note(60, 1000),
        note(72, 0),
        note(64, 1000),
        note(55, 500),
      ]);
      for (int i = 1; i < n.length; i++) {
        expect(n[i].at >= n[i - 1].at, isTrue);
      }
    });
  });
}
