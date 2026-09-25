import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/count_in.dart';

Duration ms(int n) => Duration(milliseconds: n);

void main() {
  group('CountIn', () {
    // A 120 bpm un temps dure exactement 500 ms.
    const CountIn a120 = CountIn(tempoBpm: 120);

    test('il dure une mesure entiere', () {
      expect(a120.duration, ms(2000));
      expect(const CountIn(tempoBpm: 120, beats: 2).duration, ms(1000));
    });

    test('on compte en montant, comme un chef', () {
      // "Un, deux, trois, quatre" est ce qu'il entend en cours et en
      // orchestre. Un compte a rebours serait clair pour une fusee.
      expect(a120.beatAt(Duration.zero), 1);
      expect(a120.beatAt(ms(600)), 2);
      expect(a120.beatAt(ms(1100)), 3);
      expect(a120.beatAt(ms(1600)), 4);
    });

    test('le decompte finit, et le dit', () {
      expect(a120.isFinishedAt(ms(1999)), isFalse);
      expect(a120.beatAt(ms(1999)), 4);
      expect(a120.isFinishedAt(ms(2000)), isTrue);
      expect(a120.beatAt(ms(2000)), isNull);
    });

    test('il ne reste pas coince sur son dernier temps', () {
      // A 92 bpm, aucune duree entiere de microseconde ne represente un
      // temps. Une division tronquee ferait tomber la fin juste avant, et le
      // decompte n'arriverait jamais a son terme.
      for (final int bpm in <int>[60, 76, 92, 108, 132]) {
        final CountIn c = CountIn(tempoBpm: bpm);
        expect(c.isFinishedAt(c.duration), isTrue, reason: '$bpm bpm');
        expect(c.beatAt(c.duration), isNull, reason: '$bpm bpm');
      }
    });

    test('la derniere valeur affichee est bien le dernier temps', () {
      for (final int bpm in <int>[60, 92, 132]) {
        final CountIn c = CountIn(tempoBpm: bpm);
        final Duration juste = c.duration - const Duration(microseconds: 1);
        expect(c.beatAt(juste), c.beats, reason: '$bpm bpm');
      }
    });

    test('un temps negatif ne casse rien', () {
      expect(a120.beatAt(ms(-500)), 1);
      expect(a120.phaseAt(ms(-500)), 0);
    });

    test('la phase avance dans le temps puis retombe', () {
      expect(a120.phaseAt(ms(250)), closeTo(0.5, 0.01));
      expect(a120.phaseAt(ms(499)), greaterThan(0.9));
      expect(a120.phaseAt(ms(500)), closeTo(0, 0.01));
    });

    test('rien n est accumule : deux appels identiques repondent pareil', () {
      expect(a120.beatAt(ms(1234)), a120.beatAt(ms(1234)));
      expect(a120.phaseAt(ms(1234)), a120.phaseAt(ms(1234)));
    });
  });
}
