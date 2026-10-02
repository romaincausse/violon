import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/exercises/method_source.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/scale_pattern.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/live_tuning.dart';

/// La justesse par degre (lot I3).
void main() {
  // Sol majeur : sol = tonique, si = tierce.
  const ({int tonic, bool minor}) solMajeur = (tonic: 7, minor: false);
  const ScoreNote sol = ScoreNote(
      id: 'sol', midi: 67, onsetTicks: 0, durationTicks: 480, measure: 1);
  const ScoreNote si = ScoreNote(
      id: 'si', midi: 71, onsetTicks: 480, durationTicks: 480, measure: 1);
  const ScoreNote la = ScoreNote(
      id: 'la', midi: 69, onsetTicks: 960, durationTicks: 480, measure: 1);

  LiveTuning juge(
    ScoreNote n,
    double cents, {
    ({int tonic, bool minor})? tonalite = solMajeur,
  }) {
    final LiveTuning t = LiveTuning(tonality: tonalite);
    for (int i = 0; i < 3; i++) {
      t.observe(
        n,
        PitchEstimate(
          frequencyHz: PitchUtils.midiToFrequency(n.midi) * _ratio(cents),
          confidence: 1,
          timestampMs: 0,
        ),
      );
    }
    return t;
  }

  test('la tonique se juge plus serree que la tierce', () {
    expect(juge(sol, 15).scoreFor('sol'), lessThan(100));
    expect(juge(si, 15).scoreFor('si'), 100);
    expect(juge(sol, 28).verdictFor('sol'), TuningVerdict.high);
    expect(juge(si, 28).verdictFor('si'), TuningVerdict.inTune);
  });

  test('le deuxieme degre est entre les deux', () {
    expect(juge(la, 12).scoreFor('la'), 100);
    expect(juge(la, 18).scoreFor('la'), lessThan(100));
  });

  test('sans tonalite connue, la marge large pour tous', () {
    expect(juge(sol, 15, tonalite: null).scoreFor('sol'), 100);
    expect(
        juge(sol, 28, tonalite: null).verdictFor('sol'), TuningVerdict.inTune);
  });

  test('les gammes portent leur armure, et donc leur tonalite', () {
    ScaleExercise gamme(ScalePattern p, int tonique) => ScaleExercise(
          id: 'x',
          titre: 'x',
          source: MethodSource.all.first,
          palier: 1,
          tempoVise: 72,
          pattern: p,
          tonicMidi: tonique,
          octaves: 1,
        );
    expect(gamme(ScalePattern.majeur, 55).keyFifths, 1, reason: 'sol');
    expect(gamme(ScalePattern.majeur, 62).keyFifths, 2, reason: 're');
    expect(gamme(ScalePattern.majeur, 65).keyFifths, -1, reason: 'fa');
    expect(gamme(ScalePattern.mineurHarmonique, 57).keyFifths, 0,
        reason: 'la mineur');
    expect(gamme(ScalePattern.mineurNaturel, 62).keyFifths, -1,
        reason: 're mineur');
    final Exercise solCatalogue = ExerciseCatalog.byId('gamme-sol-majeur-1')!;
    final ({int tonic, bool minor})? t =
        LiveTuning.tonalityOf(solCatalogue.toPassage());
    expect(t, (tonic: 7, minor: false));
  });
}

double _ratio(double cents) =>
    PitchUtils.midiToFrequency(69 + cents / 100) /
    PitchUtils.midiToFrequency(69);
