import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/daily_session.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/music/meter.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/store/homework.dart';
import 'package:violon/core/store/take_history.dart';

/// Quatre mesures en re majeur.
Passage morceau({int? keyFifths = 2}) => Passage(
      title: 'Into the Stars',
      notes: <ScoreNote>[
        for (int m = 1; m <= 4; m++)
          ScoreNote(
            id: 'n$m',
            midi: 74,
            onsetTicks: (m - 1) * 1920,
            durationTicks: 1920,
            measure: m,
          ),
      ],
      ticksPerBeat: 480,
      writtenTempoBpm: 80,
      meter: const Meter(4, 4),
      keyFifths: keyFifths,
      bars: <Bar>[
        for (int m = 1; m <= 4; m++)
          Bar(number: m, startTicks: (m - 1) * 1920, durationTicks: 1920),
      ],
    );

TakeRecord prise(List<(int, int)> difficultes) => TakeRecord(
      atMs: 1000,
      key: 'piece:stars:1-4',
      title: 'Into the Stars',
      fromMeasure: 1,
      toMeasure: 4,
      writtenPulseBpm: 80,
      durationMs: 20000,
      heldPulseBpm: 70,
      tuningScore: 80,
      rhythmScore: 80,
      reachedEnd: true,
      measures: <MeasureTrace>[
        for (final (int m, int d) in difficultes)
          MeasureTrace(measure: m, difficulty: d, stops: 0, restarts: 0),
      ],
      notes: const <NoteTrace>[],
    );

void main() {
  group('DailySessionPlanner', () {
    test('la gamme est dans la tonalite du morceau, au palier le plus bas', () {
      final DailySessionPlan p = DailySessionPlanner.plan(
        passage: morceau(),
        workKey: 'piece:stars:1-4',
        history: TakeHistory.vide,
        homework: HomeworkList.vide,
      );
      expect(p.warmup.id, 'gamme-re-majeur-1');
      expect(p.warmup.keyFifths, 2);
    });

    test('sans tonalite proche, la plus proche sur le cycle des quintes', () {
      // Mi bemol majeur (-3) : si bemol (-2) est la plus proche du catalogue.
      final Passage p = morceau(keyFifths: -3);
      final DailySessionPlan plan = DailySessionPlanner.plan(
        passage: p,
        workKey: 'x',
        history: TakeHistory.vide,
        homework: HomeworkList.vide,
      );
      expect(plan.warmup.id, 'gamme-si-bemol-majeur-2');
    });

    test('un arpege ne sert pas d echauffement', () {
      for (final Exercise e in ExerciseCatalog.all) {
        if (e is! ScaleExercise) {
          continue;
        }
        final DailySessionPlan p = DailySessionPlanner.plan(
          passage: morceau(keyFifths: e.keyFifths),
          workKey: 'x',
          history: TakeHistory.vide,
          homework: HomeworkList.vide,
        );
        expect(p.warmup.id, startsWith('gamme-'));
      }
    });

    test('sans rien, le passage entier', () {
      final DailySessionPlan p = DailySessionPlanner.plan(
        passage: morceau(),
        workKey: 'piece:stars:1-4',
        history: TakeHistory.vide,
        homework: HomeworkList.vide,
      );
      expect(
          p.choices.single,
          const WorkChoice(
            from: 1,
            to: 4,
            why: 'Le passage entier, pour commencer',
          ));
    });

    test('le devoir d abord, puis la mesure qui a coince et sa voisine', () {
      final DailySessionPlan p = DailySessionPlanner.plan(
        passage: morceau(),
        workKey: 'piece:stars:1-4',
        history: TakeHistory.vide.withTake(
          prise(<(int, int)>[(1, 0), (2, 6), (3, 4), (4, 0)]),
        ),
        homework: HomeworkList.vide.withHomework(
          const Homework(
            workKey: 'piece:stars:1-4',
            title: 'Into the Stars',
            targetPulseBpm: 80,
            createdAtMs: 0,
            pieceId: 'stars',
            fromMeasure: 3,
            toMeasure: 4,
          ),
        ),
      );
      expect(p.choices, hasLength(2));
      expect(p.choices.first.why, 'Le devoir de la semaine');
      expect((p.choices.first.from, p.choices.first.to), (3, 4));
      expect((p.choices.last.from, p.choices.last.to), (2, 3));
    });

    test('deux mesures qui coincent, deux propositions', () {
      final DailySessionPlan p = DailySessionPlanner.plan(
        passage: morceau(),
        workKey: 'piece:stars:1-4',
        history: TakeHistory.vide.withTake(
          prise(<(int, int)>[(1, 5), (2, 0), (3, 0), (4, 7)]),
        ),
        homework: HomeworkList.vide,
      );
      expect(p.choices.map((WorkChoice c) => c.from), <int>[4, 1]);
      expect(p.choices.first.to, 4, reason: 'pas de voisine fragile');
    });
  });

  group('DailySession', () {
    DailySession seance({bool workFirst = false}) => DailySession(
          plan: DailySessionPlanner.plan(
            passage: morceau(),
            workKey: 'x',
            history: TakeHistory.vide,
            homework: HomeworkList.vide,
          ),
          startedAt: DateTime(2026, 10, 2, 18),
          chosen: const WorkChoice(from: 1, to: 4, why: ''),
          workFirst: workFirst,
        );

    test('echauffement, travail, musique, et ce qui reste', () {
      final DailySession s = seance();
      expect(s.current, SessionStep.warmup);
      expect(s.remaining, <SessionStep>[SessionStep.work, SessionStep.music]);
      expect(s.stepNumber, 1);
      s.complete(SessionStep.warmup);
      expect(s.current, SessionStep.work);
      s.complete(SessionStep.work);
      expect(s.current, SessionStep.music);
      expect(s.remaining, isEmpty);
      expect(s.finished, isFalse);
      s.complete(SessionStep.music);
      expect(s.finished, isTrue);
      expect(s.current, isNull);
    });

    test(
        'il peut commencer par le travail, jamais finir autrement qu en '
        'musique', () {
      final DailySession s = seance(workFirst: true);
      expect(s.order, <SessionStep>[
        SessionStep.work,
        SessionStep.warmup,
        SessionStep.music,
      ]);
      expect(s.order.last, SessionStep.music);
    });

    test('une etape faite hors de son tour compte quand meme', () {
      final DailySession s = seance();
      s.complete(SessionStep.work);
      expect(s.current, SessionStep.warmup);
      s.complete(SessionStep.warmup);
      expect(s.current, SessionStep.music);
    });

    test('les bornes sont celles du plan', () {
      expect(DailySession.warmupBudget, const Duration(minutes: 3));
      expect(DailySession.workAttempts, 6);
    });
  });
}
