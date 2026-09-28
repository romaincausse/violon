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

    test('le tempo en temps battus se ramene a la noire', () {
      expect(const Meter(6, 8).quarterBpm(94, 480), 141);
      expect(const Meter(6, 8).quarterBpm(60, 480), 90);
      expect(const Meter(2, 2).quarterBpm(60, 480), 120);
      expect(const Meter(4, 4).quarterBpm(72, 480), 72);
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

  group('Passage a un autre tempo', () {
    test('ne change que le tempo', () {
      final Passage p = Passage(
        title: 'x',
        notes: passage().notes,
        ticksPerBeat: 480,
        writtenTempoBpm: 141,
        meter: const Meter(6, 8),
        keyFifths: 2,
        bars: const <Bar>[Bar(number: 1, startTicks: 0, durationTicks: 1440)],
      );
      final Passage lent = p.withPulseBpm(60);
      expect(lent.writtenTempoBpm, 90);
      expect(lent.tempoText, 'noire pointee = 60');
      expect(lent.notes, same(p.notes));
      expect(lent.bars, same(p.bars));
      expect(lent.keyFifths, 2);
      expect(lent.meter, const Meter(6, 8));
      expect(p.withTempoBpm(141).pulseBpm, 94);
    });

    test('sans chiffrage, le temps battu est la noire', () {
      expect(passage(tempo: 92).withPulseBpm(60).writtenTempoBpm, 60);
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
