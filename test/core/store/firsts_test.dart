import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/firsts.dart';
import 'package:violon/core/store/progress.dart';
import 'package:violon/core/store/take_history.dart';

TakeRecord prise({
  required DateTime at,
  int? held = 70,
  bool end = true,
  List<(int, int)> mesures = const <(int, int)>[],
  String key = 'piece:stars:1-8',
}) =>
    TakeRecord(
      atMs: at.millisecondsSinceEpoch,
      key: key,
      title: 'Into the Stars',
      fromMeasure: 1,
      toMeasure: 8,
      writtenPulseBpm: 92,
      durationMs: 60000,
      heldPulseBpm: held,
      tuningScore: 80,
      rhythmScore: 80,
      reachedEnd: end,
      measures: <MeasureTrace>[
        for (final (int m, int d) in mesures)
          MeasureTrace(measure: m, difficulty: d, stops: 0, restarts: 0),
      ],
      notes: const <NoteTrace>[],
    );

void main() {
  // Un vendredi soir.
  final DateTime soir = DateTime(2026, 10, 2, 19);

  group('Firsts', () {
    test('la toute premiere prise n a pas de premiere fois', () {
      expect(Firsts.of(TakeHistory.vide, prise(at: soir)), isEmpty);
    });

    test('jusqu au bout pour la premiere fois', () {
      final TakeHistory h = TakeHistory.vide.withTake(
        prise(at: soir.subtract(const Duration(days: 1)), end: false),
      );
      expect(
        Firsts.of(h, prise(at: soir, held: null)),
        <String>['Jusqu au bout, pour la premiere fois.'],
      );
    });

    test(
        'la mesure qui tient pour la premiere fois, et pas celle qui tenait '
        'deja', () {
      final TakeHistory h = TakeHistory.vide.withTake(prise(
        at: soir.subtract(const Duration(days: 1)),
        held: 70,
        mesures: <(int, int)>[(1, 0), (2, 5), (3, 4)],
      ));
      final List<String> p = Firsts.of(
        h,
        prise(
            at: soir, held: 70, mesures: <(int, int)>[(1, 0), (2, 0), (3, 3)]),
      );
      expect(p, <String>['La mesure 2 tient pour la premiere fois.']);
    });

    test('deux mesures, et le tempo depuis le debut de la semaine', () {
      final TakeHistory h = TakeHistory.vide
          .withTake(prise(
            // Lundi.
            at: DateTime(2026, 9, 28, 18),
            held: 68,
            mesures: <(int, int)>[(2, 5), (7, 6)],
          ))
          .withTake(prise(
            at: DateTime(2026, 9, 30, 18),
            held: 72,
            mesures: <(int, int)>[(2, 2), (7, 6)],
          ));
      final List<String> p = Firsts.of(
        h,
        prise(at: soir, held: 76, mesures: <(int, int)>[(2, 0), (7, 0)]),
      );
      expect(p, <String>[
        'Les mesures 2 et 7 tiennent pour la premiere fois.',
        'Tempo +8 depuis lundi.',
      ]);
    });

    test('un tempo qui monte de moins de quatre ne se dit pas', () {
      final TakeHistory h = TakeHistory.vide.withTake(
        prise(at: soir.subtract(const Duration(hours: 1)), held: 70),
      );
      expect(Firsts.of(h, prise(at: soir, held: 72)), isEmpty);
      expect(
        Firsts.of(h, prise(at: soir, held: 75)),
        <String>['Tempo +5 depuis tout a l heure.'],
      );
    });

    test('un autre travail ne compte pas', () {
      final TakeHistory h = TakeHistory.vide.withTake(
        prise(at: soir.subtract(const Duration(days: 1)), key: 'exo:gamme'),
      );
      expect(Firsts.of(h, prise(at: soir, held: 90)), isEmpty);
    });
  });

  group('daysPlayedInMonth', () {
    test('compte les jours, pas les prises, et seulement ce mois', () {
      final TakeHistory h = TakeHistory.vide
          .withTake(prise(at: DateTime(2026, 10, 1, 18)))
          .withTake(prise(at: DateTime(2026, 10, 1, 19)))
          .withTake(prise(at: DateTime(2026, 10, 2, 18)))
          .withTake(prise(at: DateTime(2026, 9, 30, 18)));
      expect(daysPlayedInMonth(h, soir), 2);
      expect(daysPlayedInMonth(TakeHistory.vide, soir), 0);
      expect(monthName(soir), 'octobre');
    });
  });
}
