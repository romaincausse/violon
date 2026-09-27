import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/fingerboard.dart';

void main() {
  group('Fingerboard', () {
    test('le sillet est a zero', () {
      expect(Fingerboard.fraction(0), 0);
    });

    test('l octave tombe exactement au milieu de la corde', () {
      // C'est la definition meme de l'octave : la moitie de la corde.
      expect(Fingerboard.fraction(12), closeTo(0.5, 1e-9));
    });

    test('les doigts se resserrent en montant', () {
      // **C'est tout l'interet du calcul.** Des ecarts egaux donneraient un
      // manche de guitare, et un schema faux est pire que pas de schema.
      double precedent = Fingerboard.fraction(1) - Fingerboard.fraction(0);
      for (int n = 2; n <= Fingerboard.drawnSemitones; n++) {
        final double ecart =
            Fingerboard.fraction(n) - Fingerboard.fraction(n - 1);
        expect(ecart, lessThan(precedent));
        precedent = ecart;
      }
    });

    test('un demi-ton vaut environ 5,6 % de la corde', () {
      expect(Fingerboard.fraction(1), closeTo(0.056, 0.001));
    });

    test('les quatre cordes sont en quintes, du grave a l aigu', () {
      for (int i = 1; i < Fingerboard.strings.length; i++) {
        expect(Fingerboard.strings[i] - Fingerboard.strings[i - 1], 7);
      }
    });
  });
}
