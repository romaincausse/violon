import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/follow/take_follower.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/live_tuning.dart';

/// Les demanches (K5) : le glissando entre deux positions est un geste, pas
/// une note. Le suiveur ne s'y perd pas, le juge ne le compte pas.
void main() {
  test('chaque arrivee glisse 200 ms : suivi jusqu au bout, juste partout', () {
    final Passage p =
        ExerciseCatalog.byId('demanche-la')!.toPassage(tempoBpm: 72);
    // Croches a 72 : 417 ms.
    const int croche = 417;
    final List<BowedNote> notes = <BowedNote>[
      for (int i = 0; i < p.notes.length; i++)
        BowedNote(
          start: Duration(milliseconds: 300 + croche * i),
          duration:
              Duration(milliseconds: i == p.notes.length - 1 ? 900 : croche),
          midi: p.notes[i].midi.toDouble(),
          glide: i == 0 ? Duration.zero : const Duration(milliseconds: 200),
        ),
    ];
    final List<FeatureFrame> trames = PerformanceFeatures.extract(
      ViolinSynth(seed: 3).render(
        notes,
        length: Duration(milliseconds: 300 + croche * p.notes.length + 2500),
      ),
    );
    final TakeFollower suivi = TakeFollower(p);
    final List<SmoothedPitch> hauteurs = <SmoothedPitch>[
      for (final FeatureFrame f in trames)
        if (f.midi != null)
          SmoothedPitch(
            estimate: PitchEstimate(
              frequencyHz: PitchUtils.midiToFrequency(f.midi!),
              confidence: 1,
              timestampMs: f.timeMs,
            ),
            excursionCents: 0,
            vibrato: false,
          ),
    ];
    int k = 0;
    for (final FeatureFrame f in trames) {
      while (
          k < hauteurs.length && hauteurs[k].estimate.timestampMs <= f.timeMs) {
        suivi.addPitch(hauteurs[k++]);
      }
      suivi.addFrame(f);
    }
    expect(suivi.reachedEnd, isTrue);
    final LiveTuning juste = suivi.rescore();
    expect(juste.glides, hasLength(p.notes.length - 1),
        reason: 'chaque note arrive d une autre position');
    expect(juste.heardNoteIds.length, p.notes.length);
    expect(juste.overallScore, greaterThanOrEqualTo(98));
    expect(juste.weakestNoteId, isNull);
  });
}
