import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/measure_heat.dart';
import 'package:violon/core/store/take_history.dart';

TakeRecord prise(DateTime at, List<(int, int)> mesures) => TakeRecord(
      atMs: at.millisecondsSinceEpoch,
      key: 'piece:stars:1-12',
      title: 'Into the Stars',
      fromMeasure: 1,
      toMeasure: 12,
      writtenPulseBpm: 92,
      durationMs: 30000,
      measures: <MeasureTrace>[
        for (final (int m, int d) in mesures)
          MeasureTrace(measure: m, difficulty: d, stops: 0, restarts: 0),
      ],
    );

void main() {
  final DateTime now = DateTime(2026, 10, 20, 19);

  group('MeasureProgress', () {
    test('ce qui coincait et coince moins, rapporte a la chaleur pleine', () {
      final TakeHistory h = TakeHistory.vide
          .withTake(prise(now.subtract(const Duration(days: 14)),
              <(int, int)>[(9, 50), (10, 60), (11, 4)]))
          .withTake(prise(now.subtract(const Duration(days: 1)),
              <(int, int)>[(9, 20), (10, 58), (11, 0), (12, 10)]));
      final MeasureProgress p = MeasureProgress.of(h, 'stars', now);
      expect(p.progress[9], closeTo(30 / 60, 1e-9));
      expect(p.progress[10], closeTo(2 / 60, 1e-9));
      expect(p.progress[11], closeTo(4 / 60, 1e-9));
      expect(p.progress.containsKey(12), isFalse, reason: 'jamais vue avant');
      expect(p.mostImproved(), <int>[9]);
    });

    test('pire qu avant vaut zero, jamais un negatif', () {
      final TakeHistory h = TakeHistory.vide
          .withTake(prise(
              now.subtract(const Duration(days: 10)), <(int, int)>[(3, 10)]))
          .withTake(prise(
              now.subtract(const Duration(days: 2)), <(int, int)>[(3, 40)]));
      expect(MeasureProgress.of(h, 'stars', now).progress[3], 0);
    });

    test('au-dela de quatre semaines, on ne compare plus', () {
      final TakeHistory h = TakeHistory.vide
          .withTake(prise(
              now.subtract(const Duration(days: 40)), <(int, int)>[(3, 60)]))
          .withTake(prise(
              now.subtract(const Duration(days: 2)), <(int, int)>[(3, 0)]));
      expect(MeasureProgress.of(h, 'stars', now).progress, isEmpty);
    });

    test('un autre morceau ne compte pas', () {
      final TakeHistory h = TakeHistory.vide.withTake(
          prise(now.subtract(const Duration(days: 10)), <(int, int)>[(3, 60)]));
      expect(MeasureProgress.of(h, 'autre', now).progress, isEmpty);
    });
  });
}
