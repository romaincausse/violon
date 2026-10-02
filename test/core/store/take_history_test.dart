import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/progress.dart';
import 'package:violon/core/store/take_history.dart';

void main() {
  final DateTime lundi = DateTime(2026, 10, 5, 18);

  TakeRecord prise(
    DateTime quand, {
    String key = 'exo:gamme',
    int? tempo = 70,
    int? justesse = 80,
    bool fin = true,
  }) =>
      TakeRecord(
        atMs: quand.millisecondsSinceEpoch,
        key: key,
        title: 'Gamme',
        fromMeasure: 1,
        toMeasure: 4,
        writtenPulseBpm: 72,
        durationMs: 30000,
        heldPulseBpm: tempo,
        tuningScore: justesse,
        rhythmScore: 90,
        reachedEnd: fin,
        measures: const <MeasureTrace>[
          MeasureTrace(measure: 2, difficulty: 34, stops: 1, tempoRatio: 0.8),
        ],
        notes: const <NoteTrace>[
          NoteTrace(midi: 66, measure: 2, cents: -18.4),
        ],
      );

  test('une prise se range et se relit a l identique', () {
    final TakeHistory h = TakeHistory.vide.withTake(prise(lundi));
    final TakeHistory relu = TakeHistory.decode(h.encode());
    final TakeRecord t = relu.takes.single;
    expect(t.at, lundi);
    expect(t.heldPulseBpm, 70);
    expect(t.measures.single.tempoRatio, 0.8);
    expect(t.measures.single.stops, 1);
    expect(t.notes.single.cents, closeTo(-18.4, 0.05));
  });

  test('un historique abime ne fait pas tomber l application', () {
    expect(TakeHistory.decode('{pas du json').takes, isEmpty);
    expect(TakeHistory.decode('{"prises": [{"k": 3}]}').takes, isEmpty);
  });

  test('au-dela de la capacite, les plus anciennes s effacent', () {
    TakeHistory h = TakeHistory.vide;
    for (int i = 0; i < TakeHistory.capacity + 5; i++) {
      h = h.withTake(prise(lundi.add(Duration(minutes: i))));
    }
    expect(h.takes, hasLength(TakeHistory.capacity));
    expect(h.takes.first.at, lundi.add(const Duration(minutes: 5)));
  });

  test('la courbe garde le meilleur du jour, pas la moyenne', () {
    TakeHistory h = TakeHistory.vide;
    h = h.withTake(prise(lundi, tempo: 60, justesse: 70));
    h = h.withTake(prise(lundi.add(const Duration(minutes: 20)), tempo: 68));
    // Une prise plus rapide mais pas allee au bout ne compte pas.
    h = h.withTake(
        prise(lundi.add(const Duration(minutes: 30)), tempo: 90, fin: false));
    h = h.withTake(prise(lundi.add(const Duration(days: 1)), tempo: 72));
    h = h.withTake(prise(lundi, key: 'exo:autre', tempo: 100));
    final ProgressSeries s = ProgressSeries.of(h, 'exo:gamme');
    expect(s.points, hasLength(2));
    expect(s.points.first.heldPulseBpm, 68);
    expect(s.points.first.takes, 3);
    expect(s.points.first.tuningScore, 80);
    expect(s.bestPulseBpm, 72);
  });

  test('le journal du jour dit ce qui a ete joue, et ce qui a monte', () {
    TakeHistory h = TakeHistory.vide;
    h = h.withTake(prise(lundi.subtract(const Duration(days: 2)), tempo: 66));
    h = h.withTake(prise(lundi, tempo: 64));
    h = h.withTake(prise(lundi.add(const Duration(minutes: 15)), tempo: 70));
    h = h.withTake(prise(lundi, key: 'piece:stars', tempo: 50));
    final DayJournal j = DayJournal.of(h, lundi);
    expect(j.takes, hasLength(3));
    expect(j.playing, const Duration(seconds: 90));
    expect(j.keys, <String>['exo:gamme', 'piece:stars']);
    expect(j.recordFor(h, 'exo:gamme'), 70);
    // Un premier jour sur un morceau est un record aussi.
    expect(j.recordFor(h, 'piece:stars'), 50);
  });
}
