// Lent : de la synthese et deux alignements par test.
@Tags(<String>['lent'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/follow/synthetic_take.dart';
import 'package:violon/core/follow/take_follower.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/live_tuning.dart';

import 'scenarios.dart';

/// Les hauteurs que YIN aurait rendues, une par trame voisee.
List<SmoothedPitch> hauteurs(List<FeatureFrame> trames, {double a4 = 440}) =>
    <SmoothedPitch>[
      for (final FeatureFrame f in trames)
        if (f.midi != null)
          SmoothedPitch(
            estimate: PitchEstimate(
              frequencyHz: PitchUtils.midiToFrequency(f.midi!.round(), a4: a4),
              confidence: 1,
              timestampMs: f.timeMs,
            ),
            excursionCents: 0,
            vibrato: false,
          ),
    ];

/// Les deux flux du micro, entrelaces comme en vrai : la hauteur d'un instant
/// arrive avant la trame du suiveur du meme instant.
TakeFollower jouer(Passage p, List<FeatureFrame> trames, {double a4 = 440}) {
  final TakeFollower suivi = TakeFollower(p, a4: a4);
  final List<SmoothedPitch> h = hauteurs(trames, a4: a4);
  int k = 0;
  for (final FeatureFrame f in trames) {
    while (k < h.length && h[k].estimate.timestampMs <= f.timeMs) {
      suivi.addPitch(h[k++]);
    }
    suivi.addFrame(f);
  }
  return suivi;
}

void main() {
  final Passage p = melodie();

  test('une prise jouee juste jusqu au bout se termine seule', () {
    final SyntheticTake prise = (TakeScript(p, seed: 1)..play('n1', 'n22'))
        .build(tail: const Duration(seconds: 3));
    final List<FeatureFrame> trames =
        PerformanceFeatures.extract(prise.render(ViolinSynth()));
    final TakeFollower suivi = jouer(p, trames);
    expect(suivi.reachedEnd, isTrue);
    expect(suivi.finished, isTrue);
    // Chaque note entendue est jugee contre elle-meme, donc juste.
    expect(suivi.tuning.heardNoteIds.length, greaterThanOrEqualTo(20));
    expect(suivi.tuning.overallScore, 100);
    expect(suivi.rescore().overallScore, 100);
  });

  test('un arret au milieu n est pas une fin', () {
    final SyntheticTake prise = (TakeScript(p, seed: 2)
          ..play('n1', 'n10')
          ..pause(const Duration(seconds: 4)))
        .build();
    final TakeFollower suivi =
        jouer(p, PerformanceFeatures.extract(prise.render(ViolinSynth())));
    expect(suivi.reachedEnd, isFalse);
    expect(suivi.finished, isFalse);
    expect(suivi.currentMeasure, isNotNull);
  });

  test('une note jouee basse est jugee basse, contre la note visee', () {
    final SyntheticTake prise = (TakeScript(p, seed: 3)
          ..play('n1', 'n22', centsOff: <String, double>{'n3': -45}))
        .build();
    final List<FeatureFrame> trames =
        PerformanceFeatures.extract(prise.render(ViolinSynth()));
    // Les hauteurs gardent ici leurs cents : on ne les arrondit pas.
    final TakeFollower suivi = TakeFollower(p);
    for (final FeatureFrame f in trames) {
      if (f.midi != null) {
        suivi.addPitch(
          SmoothedPitch(
            estimate: PitchEstimate(
              // midiToFrequency accepte un midi fractionnaire : les cents
              // restent dans la hauteur.
              frequencyHz: PitchUtils.midiToFrequency(f.midi!),
              confidence: 1,
              timestampMs: f.timeMs,
            ),
            excursionCents: 0,
            vibrato: false,
          ),
        );
      }
      suivi.addFrame(f);
    }
    expect(suivi.rescore().verdictFor('n3'), TuningVerdict.low);
    expect(suivi.tuning.verdictFor('n4'), TuningVerdict.inTune);
  });

  test('le diapason mesure ramene le flux a l accord de l instrument', () {
    // Un violon accorde a 443 : en direct le flux sort rapporte a 440, et
    // ses notes paraitraient toutes hautes de douze cents.
    final SyntheticTake prise =
        (TakeScript(p, seed: 4)..play('n1', 'n22')).build();
    final List<FeatureFrame> a440 =
        PerformanceFeatures.extract(prise.render(ViolinSynth(a4: 443)));
    final TakeFollower suivi = jouer(p, a440, a4: 443);
    expect(suivi.reachedEnd, isTrue);
  });
}
