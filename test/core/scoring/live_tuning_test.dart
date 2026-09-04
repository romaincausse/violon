import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/live_tuning.dart';

void main() {
  const ScoreNote la4 = ScoreNote(
    id: 'n1',
    midi: 69,
    onsetTicks: 0,
    durationTicks: 480,
    measure: 1,
  );

  /// Une mesure a [cents] de la note temperee [midi].
  PitchEstimate joue(int midi, double cents, {double confidence = 1}) {
    return PitchEstimate(
      frequencyHz: PitchUtils.midiToFrequency(midi) *
          math.pow(2, cents / 1200).toDouble(),
      confidence: confidence,
      timestampMs: 0,
    );
  }

  group('LiveTuning', () {
    test('sans son, aucun verdict', () {
      expect(LiveTuning().verdictFor('n1'), TuningVerdict.unknown);
    });

    test('une seule mesure ne suffit pas a se prononcer', () {
      // Le temps de l'attaque, la hauteur glisse. Se prononcer sur la
      // premiere trame ferait clignoter la partition.
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, 0));
      expect(t.verdictFor('n1'), TuningVerdict.unknown);
      t.observe(la4, joue(69, 0));
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
    });

    test('juste, bas, haut', () {
      for (final (double cents, TuningVerdict attendu)
          in <(double, TuningVerdict)>[
        (0, TuningVerdict.inTune),
        (30, TuningVerdict.inTune),
        (-30, TuningVerdict.inTune),
        (60, TuningVerdict.high),
        (-60, TuningVerdict.low),
      ]) {
        final LiveTuning t = LiveTuning();
        t.observe(la4, joue(69, cents));
        t.observe(la4, joue(69, cents));
        expect(t.verdictFor('n1'), attendu, reason: '$cents cents');
      }
    });

    test('la tolerance se regle', () {
      // On ne teste pas la valeur pile sur la limite : elle se joue a la
      // representation d'un flottant, ce qui n'apprend rien sur le code.
      final LiveTuning t = LiveTuning(toleranceCents: 20);
      t.observe(la4, joue(69, 19));
      t.observe(la4, joue(69, 19));
      expect(t.verdictFor('n1'), TuningVerdict.inTune);

      final LiveTuning u = LiveTuning(toleranceCents: 20);
      u.observe(la4, joue(69, 21));
      u.observe(la4, joue(69, 21));
      expect(u.verdictFor('n1'), TuningVerdict.high);
    });

    test('un vibrato large ne rend pas la note fausse', () {
      // Cinquante cents d'oscillation, ce qui deborde largement la tolerance
      // a chaque extreme. La mediane retombe au centre : c'est exactement
      // pour ca qu'on ne prend pas la moyenne des ecarts absolus.
      final LiveTuning t = LiveTuning();
      for (final double cents in <double>[-50, 45, -48, 50, -46, 47, 0]) {
        t.observe(la4, joue(69, cents));
      }
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
    });

    test('une attaque fausse ne condamne pas une note tenue juste', () {
      // Le glissando du debut d'archet tire une moyenne ; la mediane l'ignore.
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, -180));
      t.observe(la4, joue(69, -90));
      for (int i = 0; i < 6; i++) {
        t.observe(la4, joue(69, 5));
      }
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
    });

    test('jouer juste la mauvaise note ne passe pas pour juste', () {
      // Le piege que la comparaison a la note temperee la plus proche ne
      // verrait pas : un si4 parfait la ou on attendait un la4.
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(71, 0));
      t.observe(la4, joue(71, 0));
      expect(t.verdictFor('n1'), TuningVerdict.high);
    });

    test('les mesures peu sures sont ignorees', () {
      // Changement d'archet, silence, bruit de la piece.
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 5; i++) {
        t.observe(la4, joue(69, 300, confidence: 0.2));
      }
      expect(t.sampleCountFor('n1'), 0);
      expect(t.verdictFor('n1'), TuningVerdict.unknown);
    });

    test('chaque note a son propre verdict', () {
      const ScoreNote si4 = ScoreNote(
        id: 'n2',
        midi: 71,
        onsetTicks: 480,
        durationTicks: 480,
        measure: 1,
      );
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 2; i++) {
        t.observe(la4, joue(69, 0));
        t.observe(si4, joue(71, -70));
      }
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
      expect(t.verdictFor('n2'), TuningVerdict.low);
    });

    test('le diapason de reference deplace le jugement', () {
      // Un enfant accorde a 442 joue son la4 a 442 Hz. Juge contre 440, il
      // est haut de 8 cents ; juge contre son propre accord, il est juste.
      const PitchEstimate a442 = PitchEstimate(
        frequencyHz: 442,
        confidence: 1,
        timestampMs: 0,
      );
      final LiveTuning contre440 = LiveTuning(toleranceCents: 5);
      final LiveTuning contre442 = LiveTuning(toleranceCents: 5, a4: 442);
      for (int i = 0; i < 2; i++) {
        contre440.observe(la4, a442);
        contre442.observe(la4, a442);
      }
      expect(contre440.verdictFor('n1'), TuningVerdict.high);
      expect(contre442.verdictFor('n1'), TuningVerdict.inTune);
    });

    test('recommencer le passage oublie le precedent', () {
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, -80));
      t.observe(la4, joue(69, -80));
      expect(t.verdictFor('n1'), TuningVerdict.low);
      t.reset();
      expect(t.verdictFor('n1'), TuningVerdict.unknown);
    });
  });

  group('LiveTuning, exclusion de l attaque', () {
    test('sans information de temps, tout est retenu', () {
      // Les appelants qui ne savent pas ou en est la note gardent l'ancien
      // comportement.
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, 0));
      t.observe(la4, joue(69, 0));
      expect(t.sampleCountFor('n1'), 2);
    });

    test('le debut de la note est ecarte', () {
      // Pendant qu'un archet se pose, la hauteur glisse sur des dizaines de
      // cents avant de se fixer. Le compter reviendrait a reprocher a
      // l'enfant la physique de son instrument.
      final LiveTuning t = LiveTuning(attackMs: 80);
      t.observe(la4, joue(69, -200), sinceNoteStartMs: 0);
      t.observe(la4, joue(69, -120), sinceNoteStartMs: 46);
      expect(t.sampleCountFor('n1'), 0);

      t.observe(la4, joue(69, 0), sinceNoteStartMs: 92);
      expect(t.sampleCountFor('n1'), 1);
    });

    test('une attaque ratee ne condamne plus une note tenue juste', () {
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, -250), sinceNoteStartMs: 0);
      t.observe(la4, joue(69, -180), sinceNoteStartMs: 46);
      for (int i = 0; i < 4; i++) {
        t.observe(la4, joue(69, 4), sinceNoteStartMs: 92 + i * 46);
      }
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
      expect(t.scoreFor('n1'), 100);
    });
  });

  group('LiveTuning, note sur cent', () {
    test('la courbe est genereuse pres de la cible', () {
      // Dix cents, c'est en deca de ce que l'oreille distingue sur une note
      // isolee : y perdre des points serait absurde.
      expect(LiveTuning.noteScoreForCents(0), 100);
      expect(LiveTuning.noteScoreForCents(10), 100);
      expect(LiveTuning.noteScoreForCents(-10), 100);
    });

    test('elle descend regulierement jusqu au demi-ton', () {
      // A cent cents, ce n'est plus la meme note.
      expect(LiveTuning.noteScoreForCents(100), 0);
      expect(LiveTuning.noteScoreForCents(-100), 0);
      expect(LiveTuning.noteScoreForCents(55), closeTo(50, 1));
    });

    test('au-dela du demi-ton, on ne descend pas sous zero', () {
      expect(LiveTuning.noteScoreForCents(400), 0);
    });

    test('une note non entendue n a pas de note', () {
      final LiveTuning t = LiveTuning();
      expect(t.scoreFor('n1'), isNull);
      t.observe(la4, joue(69, 0));
      expect(t.scoreFor('n1'), isNull,
          reason: 'une seule mesure ne suffit pas');
    });

    test('la note d ensemble est la moyenne des notes entendues', () {
      const ScoreNote si4 = ScoreNote(
        id: 'n2',
        midi: 71,
        onsetTicks: 480,
        durationTicks: 480,
        measure: 1,
      );
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 2; i++) {
        t.observe(la4, joue(69, 0)); // 100
        t.observe(si4, joue(71, 55)); // environ 50
      }
      expect(t.scoreFor('n1'), 100);
      expect(t.scoreFor('n2'), closeTo(50, 1));
      expect(t.overallScore, closeTo(75, 1));
    });

    test('une note non entendue ne compte pas pour zero', () {
      // La compter punirait un silence, un archet rate ou un micro trop loin
      // comme une fausse note.
      const ScoreNote si4 = ScoreNote(
        id: 'n2',
        midi: 71,
        onsetTicks: 480,
        durationTicks: 480,
        measure: 1,
      );
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 2; i++) {
        t.observe(la4, joue(69, 0));
      }
      t.observe(si4, joue(71, 0)); // une seule mesure : pas assez
      expect(t.overallScore, 100);
      expect(t.heardNoteIds, <String>['n1']);
    });

    test('sans rien entendu, il n y a pas de note d ensemble', () {
      expect(LiveTuning().overallScore, isNull);
    });

    test('recommencer efface la note d ensemble', () {
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 2; i++) {
        t.observe(la4, joue(69, 0));
      }
      expect(t.overallScore, 100);
      t.reset();
      expect(t.overallScore, isNull);
    });
  });
}
