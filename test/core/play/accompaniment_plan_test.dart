import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/meter.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/play/accompaniment.dart';
import 'package:violon/core/play/accompaniment_plan.dart';
import 'package:violon/core/play/metronome_clock.dart';

/// Deux mesures de 6/8 a noire = 120, soit noire pointee = 80.
Passage deuxMesures() => Passage(
      title: 'x',
      notes: const <ScoreNote>[
        ScoreNote(
          id: 'n1',
          midi: 69,
          onsetTicks: 1440,
          durationTicks: 1440,
          measure: 2,
        ),
      ],
      ticksPerBeat: 480,
      writtenTempoBpm: 120,
      meter: const Meter(6, 8),
      bars: const <Bar>[
        Bar(number: 1, startTicks: 0, durationTicks: 1440),
        Bar(number: 2, startTicks: 1440, durationTicks: 1440),
      ],
    );

void main() {
  group('AccompanimentPlan', () {
    test('un decompte d une mesure, en temps battus', () {
      final AccompanimentPlan plan = AccompanimentPlan(
        passage: deuxMesures(),
        notes: melodyOf(deuxMesures()),
      );
      // Noire pointee = 80 : un temps dure 750 ms, deux temps de decompte.
      expect(plan.pulse, const Duration(milliseconds: 750));
      expect(plan.countIn, const Duration(milliseconds: 1500));
      expect(plan.countInClicks.map((TimedClick c) => c.accent), <PulseAccent>[
        PulseAccent.downbeat,
        PulseAccent.beat,
      ]);
      // Deux mesures de 6/8 a noire = 120 : trois secondes.
      expect(plan.length, const Duration(seconds: 3));
    });

    test('les notes tombent apres le decompte, a leur place', () {
      final AccompanimentPlan plan = AccompanimentPlan(
        passage: deuxMesures(),
        notes: melodyOf(deuxMesures()),
      );
      final TimedNote la = plan.loopNotes(0).single;
      expect(la.at, const Duration(milliseconds: 1500 + 1500));
      expect(la.duration, const Duration(milliseconds: 1500));
      expect(plan.loopNotes(1).single.at, const Duration(milliseconds: 6000));
    });

    test('le curseur suit la partition, et revient en boucle', () {
      final AccompanimentPlan seul = AccompanimentPlan(
        passage: deuxMesures(),
        notes: melodyOf(deuxMesures()),
      );
      expect(seul.tickAt(const Duration(milliseconds: 1000)), isNull);
      expect(seul.tickAt(const Duration(milliseconds: 3000)), 1440);
      expect(seul.tickAt(const Duration(milliseconds: 4600)), isNull);
      expect(seul.isFinishedAt(const Duration(milliseconds: 4500)), isTrue);

      final AccompanimentPlan boucle = AccompanimentPlan(
        passage: deuxMesures(),
        notes: melodyOf(deuxMesures()),
        loop: true,
      );
      expect(boucle.tickAt(const Duration(milliseconds: 4500)), 0);
      expect(boucle.isFinishedAt(const Duration(minutes: 5)), isFalse);
    });

    test('ce qui deborde du passage est recoupe', () {
      final AccompanimentPlan plan = AccompanimentPlan(
        passage: deuxMesures(),
        notes: const <AccompanimentNote>[
          AccompanimentNote(midi: 50, onsetTicks: -480, durationTicks: 960),
          AccompanimentNote(midi: 50, onsetTicks: 2880, durationTicks: 480),
        ],
      );
      expect(plan.oneLoop.single.at, Duration.zero);
      expect(plan.oneLoop.single.duration, const Duration(milliseconds: 500));
    });
  });

  group('AccompanimentScheduler', () {
    test('pose le decompte une fois, puis les notes a l avance', () {
      final AccompanimentScheduler s = AccompanimentScheduler(
        AccompanimentPlan(
          passage: deuxMesures(),
          notes: melodyOf(deuxMesures()),
        ),
      );
      final (List<TimedClick> clics, List<TimedNote> notes) =
          s.due(Duration.zero);
      expect(clics, hasLength(2));
      expect(notes, isEmpty, reason: 'la note est a 3 s, l horizon a 1,5 s');
      final (List<TimedClick> clics2, List<TimedNote> notes2) =
          s.due(const Duration(milliseconds: 1600));
      expect(clics2, isEmpty);
      expect(notes2.single.midi, 69);
      expect(s.due(const Duration(milliseconds: 1700)).$2, isEmpty,
          reason: 'une note posee ne se repose pas');
    });

    test('en boucle, les tours s enchainent sans fin', () {
      final AccompanimentScheduler s = AccompanimentScheduler(
        AccompanimentPlan(
          passage: deuxMesures(),
          notes: melodyOf(deuxMesures()),
          loop: true,
        ),
      );
      final List<Duration> instants = <Duration>[];
      for (int ms = 0; ms <= 12000; ms += 400) {
        instants.addAll(
          s.due(Duration(milliseconds: ms)).$2.map((TimedNote n) => n.at),
        );
      }
      expect(instants, <Duration>[
        const Duration(milliseconds: 3000),
        const Duration(milliseconds: 6000),
        const Duration(milliseconds: 9000),
        const Duration(milliseconds: 12000),
      ]);
    });

    test('sans boucle, plus rien apres le passage', () {
      final AccompanimentScheduler s = AccompanimentScheduler(
        AccompanimentPlan(
          passage: deuxMesures(),
          notes: melodyOf(deuxMesures()),
        ),
      );
      s.due(const Duration(milliseconds: 2000));
      expect(s.due(const Duration(seconds: 30)).$2, isEmpty);
    });
  });
}
