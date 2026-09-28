import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/meter.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';

Passage passage({Meter? meter, int tempo = 141}) => Passage(
      title: 'x',
      notes: const <ScoreNote>[
        ScoreNote(
          id: 'n1',
          midi: 69,
          onsetTicks: 0,
          durationTicks: 480,
          measure: 1,
        ),
      ],
      ticksPerBeat: 480,
      writtenTempoBpm: tempo,
      meter: meter,
    );

void main() {
  group('Meter', () {
    test('une 6/8 se bat en deux noires pointees', () {
      const Meter m = Meter(6, 8);
      expect(m.isCompound, isTrue);
      expect(m.ticksPerMeasure(480), 1440);
      expect(m.beatTicks(480), 720);
      expect(m.pulsesPerMeasure(480), 2);
      expect(m.pulseName(480), 'noire pointee');
      expect(m.pulseBpm(141, 480), 94);
    });

    test('3/4, 2/2 et 3/8 se battent a leur unite', () {
      expect(const Meter(3, 4).isCompound, isFalse);
      expect(const Meter(3, 4).pulsesPerMeasure(480), 3);
      expect(const Meter(2, 2).pulseName(480), 'blanche');
      expect(const Meter(2, 2).pulseBpm(120, 480), 60);
      expect(const Meter(3, 8).isCompound, isFalse);
      expect(const Meter(3, 8).pulseName(480), 'croche');
      expect(const Meter(12, 8).pulsesPerMeasure(480), 4);
    });

    test('survit au JSON, et un JSON abime ne donne rien', () {
      expect(Meter.fromJson(const Meter(6, 8).toJson()), const Meter(6, 8));
      expect(Meter.fromJson(<String, Object?>{'beats': 0}), isNull);
      expect(Meter.fromJson('6/8'), isNull);
    });
  });

  group('Passage.tempoText', () {
    test('a la noire, rien ne change', () {
      expect(passage(tempo: 92).tempoText, '92 bpm');
      expect(passage(tempo: 92, meter: const Meter(3, 4)).tempoText, '92 bpm');
      expect(passage(tempo: 92).pulsesPerMeasure, isNull);
    });

    test('en 6/8, le tempo se lit comme sur la partition', () {
      final Passage p = passage(meter: const Meter(6, 8));
      expect(p.tempoText, 'noire pointee = 94');
      expect(p.pulseBpm, 94);
      expect(p.pulsesPerMeasure, 2);
    });
  });
}
