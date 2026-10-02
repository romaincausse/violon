import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/accompaniment.dart';
import 'package:violon/core/play/speaker_voicing.dart';

void main() {
  AccompanimentNote n(int midi) => AccompanimentNote(
        midi: midi,
        onsetTicks: 480,
        durationTicks: 240,
        velocity: 0.8,
      );

  group('SpeakerVoicing', () {
    test('remonte par octaves ce qui passe sous le plancher', () {
      final List<AccompanimentNote> r =
          SpeakerVoicing.raise(<AccompanimentNote>[
        n(43), // sol2 : une octave
        n(35), // si1 : deux octaves
        n(47), // si2 : une octave, juste sous le plancher
      ]);
      expect(r.map((AccompanimentNote x) => x.midi), <int>[55, 59, 59]);
    });

    test('ne touche pas ce qui est au-dessus, ni le reste de la note', () {
      final List<AccompanimentNote> r =
          SpeakerVoicing.raise(<AccompanimentNote>[n(48), n(72)]);
      expect(r.map((AccompanimentNote x) => x.midi), <int>[48, 72]);
      expect(r.first.onsetTicks, 480);
      expect(r.first.durationTicks, 240);
      expect(r.first.velocity, 0.8);
    });

    test('le plancher se regle', () {
      expect(
        SpeakerVoicing.raise(<AccompanimentNote>[n(50)], floor: 60).single.midi,
        62,
      );
    });
  });
}
