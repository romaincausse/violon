import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/play/drone.dart';

void main() {
  group('Drone', () {
    test('le bourdon de sol sonne la corde de sol a vide', () {
      // Propriete utile : l'enfant peut verifier le bourdon contre son propre
      // instrument, et une corde a vide ne peut pas etre jouee faux.
      const Drone bourdon = Drone(pitchClass: Drone.sol);
      expect(bourdon.midi, 55);
      expect(bourdon.tonicHz, closeTo(196.0, 0.01));
    });

    test('il suit le diapason mesure, pas 440', () {
      // Un bourdon a 440 contre un violon accorde a 442 ferait battre
      // l'instrument contre la reference : l'enfant corrigerait vers le faux.
      const Drone a440 = Drone(pitchClass: Drone.sol);
      const Drone a442 = Drone(pitchClass: Drone.sol, a4: 442);
      expect(a442.tonicHz / a440.tonicHz, closeTo(442 / 440, 1e-9));
    });

    test('la quinte est pure, pas temperee', () {
      const Drone bourdon = Drone(pitchClass: Drone.sol);
      expect(bourdon.fifthHz, closeTo(bourdon.tonicHz * 1.5, 1e-9));

      // Et elle est donc deux cents au-dessus du re du piano.
      final double ecart = PitchUtils.centsBetween(
        bourdon.fifthHz!,
        PitchUtils.midiToFrequency(62),
      );
      expect(ecart, closeTo(1.955, 0.01));
      expect(Drone.fifthVersusTemperedCents, closeTo(1.955, 0.01));
    });

    test('sans la quinte, une seule frequence', () {
      const Drone bourdon = Drone(pitchClass: Drone.sol, withFifth: false);
      expect(bourdon.fifthHz, isNull);
      expect(bourdon.frequencies, hasLength(1));
      expect(const Drone(pitchClass: Drone.sol).frequencies, hasLength(2));
    });

    test('les douze notes existent, avec les deux orthographes', () {
      expect(Drone.names, hasLength(12));
      expect(Drone.names[Drone.sol], 'Sol');
      expect(Drone.names[10], 'La# / Sib');
      for (int n = 0; n < 12; n++) {
        expect(Drone(pitchClass: n).label, Drone.names[n]);
        expect(Drone(pitchClass: n).midi, 48 + n);
      }
    });

    test('copyWith ne change que ce qu on lui donne', () {
      const Drone bourdon = Drone(pitchClass: Drone.sol, a4: 442);
      final Drone autre = bourdon.copyWith(pitchClass: 2);
      expect(autre.pitchClass, 2);
      expect(autre.a4, 442);
      expect(autre.withFifth, isTrue);
    });
  });
}
