import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/open_string_fifths.dart';

const int sol3 = 55;
const int re4 = 62;
const int la4 = 69;
const int mi5 = 76;

/// Frequence de la corde [midi], decalee de [cents].
double corde(int midi, [double cents = 0]) =>
    PitchUtils.midiToFrequency(midi) * math.pow(2, cents / 1200).toDouble();

void main() {
  group('OpenStringFifths', () {
    test('la reference est la quinte JUSTE, pas la temperee', () {
      // Un violon s'accorde sur le rapport 3:2. Le piano rabote ses quintes a
      // 700 pour que les douze tonalites tiennent ; utiliser 700 ici
      // declarerait fausses des cordes accordees exactement comme il faut.
      expect(OpenStringFifths.pureFifthCents, closeTo(701.955, 0.01));
      expect(OpenStringFifths.pureFifthCents - 700, greaterThan(1.9));
    });

    test('un violon accorde en quintes justes est declare juste', () {
      // Chaque corde est une quinte juste au-dessus de la precedente : les
      // ecarts au tempere s'accumulent, +2, +4, +6 cents.
      final Map<int, double> mesure = <int, double>{
        sol3: corde(sol3),
        re4: corde(re4, 1.955),
        la4: corde(la4, 3.910),
        mi5: corde(mi5, 5.865),
      };
      final List<StringFifth> quintes = OpenStringFifths.from(mesure);

      expect(quintes, hasLength(3));
      for (final StringFifth q in quintes) {
        expect(OpenStringFifths.isInTune(q), isTrue, reason: q.name);
        expect(q.centsFromPure, closeTo(0, 0.1));
      }
    });

    test('un violon accorde au tempere sonne trop etroit', () {
      // C'est le piege exact que ce lot evite : accorder chaque corde sur son
      // temperament donne trois quintes fausses de deux cents chacune, ce
      // qu'un violoniste entend en double corde.
      final List<StringFifth> quintes = OpenStringFifths.from(<int, double>{
        sol3: corde(sol3),
        re4: corde(re4),
        la4: corde(la4),
        mi5: corde(mi5),
      });
      for (final StringFifth q in quintes) {
        expect(q.centsFromPure, closeTo(-1.955, 0.01), reason: q.name);
        expect(q.tooWide, isFalse);
      }
    });

    test('une corde trop haute elargit la quinte du dessous', () {
      final List<StringFifth> quintes = OpenStringFifths.from(<int, double>{
        sol3: corde(sol3),
        re4: corde(re4, 1.955 + 15),
      });
      expect(quintes, hasLength(1));
      expect(quintes.single.centsFromPure, closeTo(15, 0.1));
      expect(quintes.single.tooWide, isTrue);
      expect(OpenStringFifths.isInTune(quintes.single), isFalse);
    });

    test('une corde qu on n a pas entendue ne donne pas de quinte', () {
      // On ne devine pas une corde : deux quintes sur trois valent mieux
      // qu'une troisieme inventee.
      final List<StringFifth> quintes = OpenStringFifths.from(<int, double>{
        sol3: corde(sol3),
        la4: corde(la4, 3.910),
        mi5: corde(mi5, 5.865),
      });
      expect(quintes.map((StringFifth q) => q.name), <String>['La4-Mi5']);
    });

    test('sans rien entendre, il n y a aucune quinte', () {
      expect(OpenStringFifths.from(const <int, double>{}), isEmpty);
    });

    test('les quintes sont nommees comme on les dit', () {
      final List<StringFifth> quintes = OpenStringFifths.from(<int, double>{
        sol3: corde(sol3),
        re4: corde(re4, 1.955),
        la4: corde(la4, 3.910),
        mi5: corde(mi5, 5.865),
      });
      expect(
        quintes.map((StringFifth q) => q.name),
        <String>['Sol3-Re4', 'Re4-La4', 'La4-Mi5'],
      );
    });

    test('un ecart sous le seuil ne fait pas recommencer l accordage', () {
      final List<StringFifth> quintes = OpenStringFifths.from(<int, double>{
        sol3: corde(sol3),
        re4: corde(re4, 1.955 + 3),
      });
      expect(OpenStringFifths.isInTune(quintes.single), isTrue);
    });
  });
}
