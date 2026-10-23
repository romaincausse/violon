import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/finger_diagnosis.dart';
import 'package:violon/core/scoring/live_tuning.dart';
import 'package:violon/core/scoring/resonance.dart';
import 'package:violon/core/store/take_history.dart';

void main() {
  group('quelles notes sonnent', () {
    test('sol, re, la, mi et leurs octaves, pas les autres', () {
      expect(Resonance.stringFor(67), ViolinString.g); // sol4, 3e doigt sur re
      expect(Resonance.stringFor(74), ViolinString.d); // re5, 3e doigt sur la
      expect(Resonance.stringFor(57), ViolinString.a); // la3, 1er doigt sur sol
      expect(Resonance.stringFor(64), ViolinString.e); // mi4, 1er doigt sur re
      expect(Resonance.stringFor(66), isNull); // fa#4
      expect(Resonance.stringFor(43), isNull, reason: 'sous le sol grave');
    });

    test('les cordes a vide ne se jugent pas : elles disent l accord', () {
      for (final ViolinString s in ViolinString.values) {
        expect(Resonance.judged(s.openMidi), isFalse);
        expect(Resonance.judged(s.openMidi + 12), isTrue);
      }
      expect(Resonance.judged(71), isFalse);
    });
  });

  group('la marge', () {
    PitchEstimate joue(int midi, double cents) => PitchEstimate(
          frequencyHz: PitchUtils.midiToFrequency(midi) *
              math.pow(2, cents / 1200).toDouble(),
          confidence: 1,
          timestampMs: 0,
        );
    ScoreNote note(String id, int midi) => ScoreNote(
          id: id,
          midi: midi,
          onsetTicks: 0,
          durationTicks: 480,
          measure: 1,
        );

    test('un re a 28 cents fait taire la corde, un fa# a 28 cents passe', () {
      final LiveTuning t = LiveTuning();
      final ScoreNote re = note('re', 74);
      final ScoreNote fa = note('fa', 78);
      for (int i = 0; i < 3; i++) {
        t.observe(re, joue(74, -28));
        t.observe(fa, joue(78, -28));
      }
      expect(t.bandFor(re), ToleranceBand.resonant);
      expect(t.verdictFor('re'), TuningVerdict.low);
      expect(t.verdictFor('fa'), TuningVerdict.inTune);
      expect(t.scoreFor('re'), lessThan(t.scoreFor('fa')!));
    });

    test('avec une tonalite aussi : la resonance passe avant le degre', () {
      final LiveTuning t = LiveTuning(tonality: (tonic: 2, minor: false));
      expect(t.bandFor(note('mi', 64)), ToleranceBand.resonant);
      expect(t.bandFor(note('si', 71)), ToleranceBand.imperfect);
      // La corde a vide garde la marge de son degre.
      expect(t.bandFor(note('re', 62)), ToleranceBand.perfect);
    });

    test('dans une prise, la note qui sort le plus de sa marge nomme la corde',
        () {
      final LiveTuning t = LiveTuning();
      final ScoreNote re = note('re', 74);
      final ScoreNote sol = note('sol', 67);
      final ScoreNote fa = note('fa', 66);
      for (int i = 0; i < 3; i++) {
        t.observe(re, joue(74, 24));
        t.observe(sol, joue(67, -30));
        t.observe(fa, joue(66, 45));
      }
      expect(Resonance.silencedIn(<ScoreNote>[re, sol, fa], t), ViolinString.g);
      expect(Resonance.silencedIn(<ScoreNote>[fa], t), isNull,
          reason: 'un fa# faux ne fait taire aucune corde');
      expect(resonanceReason(ViolinString.g),
          'ton sol ne fait pas vibrer la corde de sol');
    });

    test('elle est plus serree que celle de la quinte', () {
      expect(ToleranceBand.resonant.perfectCents,
          lessThan(ToleranceBand.perfect.perfectCents));
      expect(ToleranceBand.resonant.verdictCents,
          lessThanOrEqualTo(ToleranceBand.perfect.verdictCents));
      expect(ToleranceBand.resonant.verdictCents,
          lessThan(ToleranceBand.imperfect.verdictCents));
    });
  });

  group('l habitude, sur plusieurs prises', () {
    TakeRecord prise(int minute, List<NoteTrace> notes) => TakeRecord(
          atMs: DateTime(2026, 10, 2, 18, minute).millisecondsSinceEpoch,
          key: 'exo:gamme',
          title: 'Gamme',
          fromMeasure: 1,
          toMeasure: 2,
          writtenPulseBpm: 72,
          durationMs: 20000,
          notes: notes,
        );
    NoteTrace n(int midi, double cents) =>
        NoteTrace(midi: midi, measure: 1, cents: cents);

    test('un re bas d une prise a l autre se dit, par son nom', () {
      final TakeHistory h = TakeHistory(<TakeRecord>[
        prise(1, <NoteTrace>[n(74, -16), n(74, -14), n(74, -18), n(67, 2)]),
        prise(2, <NoteTrace>[n(74, -15), n(74, -12), n(74, -17), n(67, -3)]),
      ]);
      final ResonanceFinding r = Resonance.of(h)!;
      expect(r.string, ViolinString.d);
      expect(r.flat, isTrue);
      expect(r.sentence,
          'Ton re ne fait pas vibrer la corde de re : il tombe bas.');
    });

    test('un soir ne fait pas une habitude, et la corde a vide ne compte pas',
        () {
      expect(
        Resonance.of(TakeHistory(<TakeRecord>[
          prise(1, <NoteTrace>[for (int i = 0; i < 8; i++) n(74, -20)]),
        ])),
        isNull,
      );
      expect(
        Resonance.of(TakeHistory(<TakeRecord>[
          prise(1, <NoteTrace>[for (int i = 0; i < 4; i++) n(62, -20)]),
          prise(2, <NoteTrace>[for (int i = 0; i < 4; i++) n(62, -20)]),
        ])),
        isNull,
      );
    });
  });
}
