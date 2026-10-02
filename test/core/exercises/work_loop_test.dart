import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/work_loop.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/scoring/live_tuning.dart';
import 'package:violon/core/scoring/rhythm_judge.dart';
import 'package:violon/core/scoring/take_report.dart';

void main() {
  LoopAttempt essai(int tempo, {bool reussi = true, int objectif = 0}) =>
      LoopAttempt(
        reachedEnd: true,
        tuningScore: reussi ? 95 : 60,
        rhythmScore: 95,
        heldPulseBpm: tempo,
        stops: 0,
        targetPulseBpm: objectif == 0 ? tempo : objectif,
      );

  group('la montee de tempo (R3)', () {
    test('deux reussites de suite, et le tempo monte d un cran', () {
      final WorkLoop b = WorkLoop(
        selection: const BarSelection(7, 8),
        startPulseBpm: 70,
        writtenPulseBpm: 92,
      );
      expect(b.record(essai(70)), LoopStep.again);
      expect(b.record(essai(70)), LoopStep.faster);
      expect(b.targetPulseBpm, 76);
      expect(b.successes, 2);
    });

    test('un essai rate ne remet pas les reussites a zero', () {
      final WorkLoop b = WorkLoop(
        selection: const BarSelection(7, 7),
        startPulseBpm: 70,
        writtenPulseBpm: 92,
      );
      b.record(essai(70));
      expect(b.record(essai(70, reussi: false)), LoopStep.again);
      expect(b.successes, 1, reason: 'une erreur ne remet jamais a zero');
      expect(b.streak, 0, reason: 'mais la serie qui fait monter, si');
      expect(b.targetPulseBpm, 70);
    });

    test('reussi en dessous de l objectif ne fait pas monter', () {
      final WorkLoop b = WorkLoop(
        selection: const BarSelection(1, 1),
        startPulseBpm: 80,
        writtenPulseBpm: 92,
      );
      final LoopAttempt lent = essai(70, objectif: 80);
      expect(lent.success, isFalse);
      expect(b.record(lent), LoopStep.again);
    });

    test('au tempo ecrit, la boucle a fait son travail', () {
      final WorkLoop b = WorkLoop(
        selection: const BarSelection(1, 2),
        startPulseBpm: 86,
        writtenPulseBpm: 90,
      );
      b.record(essai(86));
      expect(b.record(essai(86)), LoopStep.faster);
      expect(b.targetPulseBpm, 90, reason: 'on ne depasse pas le papier');
      b.record(essai(90));
      expect(b.record(essai(90)), LoopStep.done);
    });
  });

  group('le point de rupture (C2)', () {
    test('on monte jusqu a ce que ca casse, on note, on redescend', () {
      final WorkLoop b = WorkLoop(
        selection: const BarSelection(3, 4),
        startPulseBpm: 80,
        writtenPulseBpm: 90,
        findBreakingPoint: true,
      );
      int t = 80;
      for (int k = 0; k < 4; k++) {
        b.record(essai(t));
        expect(b.record(essai(t)), LoopStep.faster);
        t = b.targetPulseBpm;
      }
      // 80, 86, 92, 98 ont tenu : on depasse le papier en cherchant.
      expect(t, 104);
      expect(b.record(essai(t, reussi: false)), LoopStep.consolidate);
      expect(b.breakingPointBpm, 104);
      expect(b.targetPulseBpm, 92, reason: 'deux crans sous la rupture');
      b.record(essai(92));
      expect(b.record(essai(92)), LoopStep.done);
    });
  });

  group('finir sur une reussite (R4)', () {
    test('apres un echec, une derniere fois la ou ca tenait', () {
      final WorkLoop b = WorkLoop(
        selection: const BarSelection(5, 5),
        startPulseBpm: 70,
        writtenPulseBpm: 92,
      );
      b.record(essai(72));
      b.record(essai(70, reussi: false));
      expect(b.finishOnSuccessPulseBpm, 72);
      b.record(essai(72));
      expect(b.finishOnSuccessPulseBpm, isNull);
    });

    test('sans aucune reussite, un cran sous le depart', () {
      final WorkLoop b = WorkLoop(
        selection: const BarSelection(5, 5),
        startPulseBpm: 70,
        writtenPulseBpm: 92,
      );
      b.record(essai(70, reussi: false));
      expect(b.finishOnSuccessPulseBpm, 64);
    });
  });

  group('la selection des mesures faibles (R1)', () {
    final Passage p = () {
      final PassageBuilder b = PassageBuilder();
      for (int i = 0; i < 24; i++) {
        b.add(60 + i, NoteValue.quarter);
      }
      return Passage(
        title: 'six mesures',
        notes: b.notes,
        ticksPerBeat: b.ticksPerBeat,
        writtenTempoBpm: 100,
      );
    }();

    List<PlayedEvent> legato(Map<int, int> durees) {
      final List<PlayedEvent> e = <PlayedEvent>[];
      int t = 0;
      for (int i = 0; i < 24; i++) {
        final int d = durees[i] ?? 600;
        e.add(PlayedEvent(noteIndex: i, startMs: t, endMs: t + d));
        t += d;
      }
      return e;
    }

    test('la mesure designee, et sa voisine si elle est fragile aussi', () {
      // Mesures 3 et 4 nettement ralenties, la 3 davantage.
      final TakeReport r = TakeReport.of(
        p,
        RhythmJudge.fromEvents(
          p,
          legato(<int, int>{
            for (int i = 8; i < 12; i++) i: 900,
            for (int i = 12; i < 16; i++) i: 820,
          }),
        ),
        LiveTuning(),
      );
      expect(r.nextTask!.measure, 3);
      expect(WorkLoop.weakBars(r), const BarSelection(3, 4));
    });

    test('rien a retravailler, rien de designe', () {
      final TakeReport r = TakeReport.of(
        p,
        RhythmJudge.fromEvents(p, legato(<int, int>{})),
        LiveTuning(),
      );
      expect(WorkLoop.weakBars(r), isNull);
    });

    test('le passage de la selection se decoupe dans le morceau', () {
      final Passage? e = WorkLoop.excerpt(p, const BarSelection(2, 3));
      expect(e!.notes, hasLength(8));
      expect(e.notes.first.measure, 2);
      expect(e.title, contains('mesures 2 a 3'));
    });
  });
}
