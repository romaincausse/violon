import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/performance_features.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('PerformanceFeatures', () {
    final Float32List signal = ViolinSynth(a4: 442).render(
      <BowedNote>[
        BowedNote(start: ms(500), duration: ms(500), midi: 69),
        BowedNote(start: ms(1000), duration: ms(500), midi: 69),
      ],
      length: ms(2000),
    );

    test('une trame toutes les 1024 echantillons', () {
      final List<FeatureFrame> f = PerformanceFeatures.extract(signal);
      expect(f, hasLength((2 * 44100 - 2048) ~/ 1024 + 1));
      expect(f[1].timeMs, 23);
    });

    test('la hauteur est rapportee a l accord reel', () {
      // Un la joue sur un violon accorde a 442 est un la juste, pas un la trop
      // haut de huit cents.
      final List<FeatureFrame> f = PerformanceFeatures.extract(signal, a4: 442);
      final FeatureFrame milieu =
          f.firstWhere((FeatureFrame t) => t.timeMs >= 700);
      expect(milieu.midi, closeTo(69, 0.03));
    });

    test('le silence n a pas de hauteur', () {
      final List<FeatureFrame> f = PerformanceFeatures.extract(signal);
      expect(f.first.voiced, isFalse);
      expect(f.last.voiced, isFalse);
    });

    test('chaque attaque marque une seule trame, juste apres elle', () {
      final List<FeatureFrame> attaques = PerformanceFeatures.extract(signal)
          .where((FeatureFrame t) => t.onset)
          .toList();
      expect(attaques, hasLength(2));
      expect(attaques[0].timeMs, inInclusiveRange(480, 530));
      expect(attaques[1].timeMs, inInclusiveRange(980, 1030));
    });
  });
}
