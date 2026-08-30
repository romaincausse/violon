import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';

void main() {
  group('FakePitchSource', () {
    test('rejoue le script dans l\'ordre', () async {
      final FakePitchSource source = FakePitchSource.fromFrequencies(
        <double>[440, 493.88, 523.25],
      );
      final Future<List<PitchEstimate>> collected =
          source.pitches.take(3).toList();
      source.emitAll();

      final List<PitchEstimate> events = await collected;
      expect(events.map((PitchEstimate e) => e.nearestMidi), <int>[69, 71, 72]);
      await source.dispose();
    });

    test('horodate regulierement', () async {
      final FakePitchSource source = FakePitchSource.fromFrequencies(
        <double>[440, 440],
        interval: const Duration(milliseconds: 50),
      );
      expect(source.script[0].timestampMs, 0);
      expect(source.script[1].timestampMs, 50);
      await source.dispose();
    });

    test('annonce une latence nulle', () {
      expect(FakePitchSource.fromFrequencies(<double>[440]).latencyMs, 0);
    });
  });
}
