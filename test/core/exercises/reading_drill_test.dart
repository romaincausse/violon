import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/reading_drill.dart';

void main() {
  group('ReadingDrill', () {
    test('la meme graine donne la meme suite', () {
      final ReadingDrill a = ReadingDrill(pool: <int>[62, 64, 66, 67], seed: 7);
      final ReadingDrill b = ReadingDrill(pool: <int>[62, 64, 66, 67], seed: 7);
      for (int i = 0; i < 10; i++) {
        expect(a.target, b.target);
        a.hear(a.target.toDouble(), i * 1000);
        a.hear(a.target.toDouble(), i * 1000 + 300);
        b.hear(b.target.toDouble(), i * 1000);
        b.hear(b.target.toDouble(), i * 1000 + 300);
      }
    });

    test('une note est lue quand elle est tenue un quart de seconde', () {
      final ReadingDrill d = ReadingDrill(pool: <int>[62, 64]);
      final int cible = d.target;
      expect(d.hear(cible.toDouble(), 0), ReadingEvent.none);
      expect(d.hear(cible.toDouble(), 100), ReadingEvent.none);
      expect(d.hear(cible.toDouble(), 260), ReadingEvent.read);
      expect(d.read, 1);
      expect(d.target, isNot(cible), reason: 'jamais deux fois la meme');
    });

    test('une mauvaise note ne compte pas, et casse la tenue', () {
      final ReadingDrill d = ReadingDrill(pool: <int>[62, 64, 66]);
      final int cible = d.target;
      final int autre = cible == 62 ? 64 : 62;
      expect(d.hear(cible.toDouble(), 0), ReadingEvent.none);
      expect(d.hear(autre.toDouble(), 100), ReadingEvent.none);
      // La bonne revient : la tenue repart de la.
      expect(d.hear(cible.toDouble(), 200), ReadingEvent.none);
      expect(d.hear(cible.toDouble(), 400), ReadingEvent.none);
      expect(d.hear(cible.toDouble(), 460), ReadingEvent.read);
      expect(d.read, 1);
    });

    test('a un demi-ton pres : un peu bas, c est encore elle', () {
      final ReadingDrill d = ReadingDrill(pool: <int>[62, 64]);
      final double bas = d.target - 0.3;
      d.hear(bas, 0);
      expect(d.hear(bas, 300), ReadingEvent.read);
    });

    test('le silence remet la tenue a zero', () {
      final ReadingDrill d = ReadingDrill(pool: <int>[62, 64]);
      d.hear(d.target.toDouble(), 0);
      d.rest();
      expect(d.hear(d.target.toDouble(), 300), ReadingEvent.none);
    });
  });
}
