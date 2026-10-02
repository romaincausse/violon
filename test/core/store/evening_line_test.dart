import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/evening_line.dart';
import 'package:violon/core/store/take_history.dart';

TakeRecord prise({
  required DateTime at,
  String key = 'piece:stars:1-8',
  String title = 'Into the Stars',
  int? held = 70,
  bool end = true,
  int durationMs = 6 * 60 * 1000,
}) =>
    TakeRecord(
      atMs: at.millisecondsSinceEpoch,
      key: key,
      title: title,
      fromMeasure: 1,
      toMeasure: 8,
      writtenPulseBpm: 92,
      durationMs: durationMs,
      heldPulseBpm: held,
      tuningScore: 80,
      rhythmScore: 80,
      reachedEnd: end,
      measures: const <MeasureTrace>[],
      notes: const <NoteTrace>[],
    );

void main() {
  final DateTime soir = DateTime(2026, 10, 2, 19, 30);

  group('EveningLine', () {
    test('rien joue, rien dit', () {
      expect(EveningLine.of(TakeHistory.vide, soir), isNull);
    });

    test('la duree, et ce qui a tenu jusqu au bout', () {
      final TakeHistory h = TakeHistory.vide
          .withTake(prise(at: soir.subtract(const Duration(minutes: 30))))
          .withTake(
              prise(at: soir.subtract(const Duration(minutes: 20)), held: 76));
      expect(
        EveningLine.of(h, soir),
        'Ce soir : 12 minutes d archet. Into the Stars tenu a 76, jusqu au '
        'bout.',
      );
    });

    test('plus vite que jamais, et la plus longue seance de la semaine', () {
      final TakeHistory h = TakeHistory.vide
          .withTake(prise(
              at: soir.subtract(const Duration(days: 2)),
              held: 70,
              durationMs: 4 * 60 * 1000))
          .withTake(
              prise(at: soir.subtract(const Duration(minutes: 10)), held: 76));
      expect(
        EveningLine.of(h, soir),
        'Ce soir : 6 minutes d archet. Into the Stars tenu a 76 : jamais '
        'aussi vite. Ta plus longue seance de la semaine.',
      );
    });

    test(
        'moins vite qu avant : le tempo, sans commentaire, et pas de record '
        'de duree', () {
      final TakeHistory h = TakeHistory.vide
          .withTake(prise(
              at: soir.subtract(const Duration(days: 1)),
              held: 80,
              durationMs: 10 * 60 * 1000))
          .withTake(
              prise(at: soir.subtract(const Duration(minutes: 10)), held: 76));
      expect(
        EveningLine.of(h, soir),
        'Ce soir : 6 minutes d archet. Into the Stars tenu a 76.',
      );
    });

    test('une prise abandonnee ne tient rien', () {
      final TakeHistory h = TakeHistory.vide.withTake(
        prise(at: soir.subtract(const Duration(minutes: 5)), end: false),
      );
      expect(EveningLine.of(h, soir), 'Ce soir : 6 minutes d archet.');
    });
  });
}
