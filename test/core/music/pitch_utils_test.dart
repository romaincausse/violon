import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/pitch_utils.dart';

void main() {
  group('PitchUtils', () {
    test('le la4 vaut 440 Hz au diapason par defaut', () {
      expect(PitchUtils.midiToFrequency(69), closeTo(440, 0.001));
    });

    test('le diapason a 442 Hz decale toutes les notes', () {
      expect(PitchUtils.midiToFrequency(69, a4: 442), closeTo(442, 0.001));
      expect(PitchUtils.midiToFrequency(76, a4: 442), greaterThan(659.25));
    });

    test('les cordes a vide du violon tombent sur les bonnes frequences', () {
      expect(PitchUtils.midiToFrequency(55), closeTo(196.00, 0.01)); // sol3
      expect(PitchUtils.midiToFrequency(62), closeTo(293.66, 0.01)); // re4
      expect(PitchUtils.midiToFrequency(69), closeTo(440.00, 0.01)); // la4
      expect(PitchUtils.midiToFrequency(76), closeTo(659.26, 0.01)); // mi5
    });

    test('midi et frequence sont reciproques', () {
      for (final int midi in <int>[55, 62, 69, 76, 84]) {
        final double frequency = PitchUtils.midiToFrequency(midi);
        expect(PitchUtils.frequencyToMidi(frequency), closeTo(midi, 1e-9));
      }
    });

    test('une octave vaut 1200 cents', () {
      expect(PitchUtils.centsBetween(880, 440), closeTo(1200, 1e-9));
      expect(PitchUtils.centsBetween(220, 440), closeTo(-1200, 1e-9));
    });

    test('centsOffset reste dans la demi-plage', () {
      expect(PitchUtils.centsOffset(440), closeTo(0, 1e-6));
      expect(PitchUtils.centsOffset(445), inInclusiveRange(0, 50));
      expect(PitchUtils.centsOffset(435), inInclusiveRange(-50, 0));
    });

    test('un violon accorde un peu bas reste sur la bonne note', () {
      // 437 Hz : environ 12 cents sous le la, ce qui arrive tous les jours.
      expect(PitchUtils.nearestMidiNote(437), 69);
      expect(PitchUtils.centsOffset(437), closeTo(-11.8, 0.5));
    });

    test('nomme correctement les notes', () {
      expect(PitchUtils.noteName(69), 'La4');
      expect(PitchUtils.noteName(60), 'Do4');
      expect(PitchUtils.noteName(55), 'Sol3');
    });

    test('trouve la corde a vide la plus proche', () {
      expect(PitchUtils.nearestOpenString(200), 55);
      expect(PitchUtils.nearestOpenString(450), 69);
      expect(PitchUtils.nearestOpenString(650), 76);
    });

    test('refuse les frequences non positives', () {
      expect(() => PitchUtils.frequencyToMidi(0), throwsArgumentError);
      expect(() => PitchUtils.centsBetween(-1, 440), throwsArgumentError);
    });
  });
}
