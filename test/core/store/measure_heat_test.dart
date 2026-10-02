import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/measure_heat.dart';
import 'package:violon/core/store/take_history.dart';

void main() {
  final DateTime maintenant = DateTime(2026, 10, 20, 18);

  TakeRecord prise(int joursAvant, Map<int, int> difficultes,
          {String piece = 'stars'}) =>
      TakeRecord(
        atMs: maintenant
            .subtract(Duration(days: joursAvant))
            .millisecondsSinceEpoch,
        key: 'piece:$piece:1-8',
        title: 'Into the Stars',
        fromMeasure: 1,
        toMeasure: 8,
        writtenPulseBpm: 94,
        durationMs: 40000,
        measures: <MeasureTrace>[
          for (final MapEntry<int, int> e in difficultes.entries)
            MeasureTrace(measure: e.key, difficulty: e.value),
        ],
      );

  test('la chaleur est la moyenne des prises, pas leur somme', () {
    TakeHistory h = TakeHistory.vide;
    for (int i = 0; i < 10; i++) {
      h = h.withTake(prise(0, <int, int>{3: 6, 5: 60}));
    }
    final MeasureHeat c = MeasureHeat.of(h, 'stars', maintenant);
    expect(c.heat[3], closeTo(0.1, 0.01));
    expect(c.heat[5], closeTo(1, 0.01));
    expect(c.takes, 10);
    expect(c.hottest(), <int>[5]);
  });

  test('une mesure travaillee depuis palit', () {
    final TakeHistory h = TakeHistory.vide
        // Il y a trois semaines, la mesure 4 coincait...
        .withTake(prise(21, <int, int>{4: 60}))
        // ... cette semaine, elle tient.
        .withTake(prise(0, <int, int>{4: 6}));
    final MeasureHeat c = MeasureHeat.of(h, 'stars', maintenant);
    expect(c.heat[4], lessThan(0.25));
    expect(c.hottest(), isEmpty);
  });

  test('les autres morceaux ne comptent pas', () {
    final TakeHistory h = TakeHistory.vide
        .withTake(prise(0, <int, int>{2: 60}, piece: 'firework'));
    expect(MeasureHeat.of(h, 'stars', maintenant).heat, isEmpty);
  });
}
