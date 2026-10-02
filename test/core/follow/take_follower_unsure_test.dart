import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/follow/take_follower.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/pitch_utils.dart';

/// Le suiveur qui doute (lot S5), sur des trames ecrites a la main.
void main() {
  Passage passage(List<int> midis) {
    final PassageBuilder b = PassageBuilder();
    for (final int m in midis) {
      b.add(m, NoteValue.quarter);
    }
    return Passage(
      title: 't',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
    );
  }

  int t = 0;
  void jouer(TakeFollower s, int? midi, int trames) {
    for (int i = 0; i < trames; i++) {
      if (midi != null) {
        s.addPitch(
          SmoothedPitch(
            estimate: PitchEstimate(
              frequencyHz: PitchUtils.midiToFrequency(midi),
              confidence: 1,
              timestampMs: t,
            ),
            excursionCents: 0,
            vibrato: false,
          ),
        );
      }
      s.addFrame(
        FeatureFrame(
          timeMs: t,
          midi: midi?.toDouble(),
          rms: midi == null ? 0.001 : 0.1,
          onset: midi != null && i == 0,
        ),
      );
      t += 23;
    }
  }

  setUp(() => t = 0);

  test('une melodie qui change de note ne laisse aucun doute', () {
    final TakeFollower s = TakeFollower(passage(<int>[62, 64, 66, 67, 69]));
    for (final int m in <int>[62, 64, 66, 67]) {
      jouer(s, m, 12);
      expect(s.unsure, isFalse, reason: 'apres la note $m');
    }
    expect(s.tuning.heardNoteIds, hasLength(4));
  });

  test('douze la identiques : il dit qu il cherche, et ne note pas au hasard',
      () {
    // Firework, mesures 1 a 12 en petit : rien ne dit ou l'eleve en est.
    final TakeFollower s = TakeFollower(passage(<int>[
      for (int i = 0; i < 12; i++) 69,
      62,
    ]));
    // Il demarre au milieu, sans qu'on puisse le savoir.
    bool aDoute = false;
    for (int k = 0; k < 6; k++) {
      jouer(s, 69, 8);
      aDoute = aDoute || s.unsure;
    }
    expect(aDoute, isTrue);
    // Ce qui a ete entendu pendant le doute n'a ete rattache a rien...
    final int pendantLeDoute = s.tuning.heardNoteIds.length;
    expect(pendantLeDoute, lessThan(6));
    // ... et l'aligneur le reprend en fin de prise.
    expect(s.rescore().heardNoteIds.length, greaterThan(pendantLeDoute));
  });

  test('avant de commencer, il attend : ce n est pas un doute', () {
    final TakeFollower s = TakeFollower(passage(<int>[62, 64]));
    jouer(s, null, 30);
    expect(s.started, isFalse);
    expect(s.unsure, isFalse);
  });
}
