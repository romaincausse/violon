import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/homework.dart';
import 'package:violon/core/store/take_history.dart';

void main() {
  final DateTime pose = DateTime(2026, 10, 3, 17);

  Homework devoir({int vise = 80, String? mot}) => Homework(
        workKey: 'exo:gamme-re',
        title: 'Gamme de re',
        targetPulseBpm: vise,
        createdAtMs: pose.millisecondsSinceEpoch,
        exerciseId: 'gamme-re',
        note: mot,
      );

  TakeRecord prise(DateTime quand, int tempo, {bool fin = true}) => TakeRecord(
        atMs: quand.millisecondsSinceEpoch,
        key: 'exo:gamme-re',
        title: 'Gamme de re',
        fromMeasure: 1,
        toMeasure: 4,
        writtenPulseBpm: 92,
        durationMs: 20000,
        heldPulseBpm: tempo,
        reachedEnd: fin,
      );

  test('un devoir avance avec les prises jouees depuis qu il est pose', () {
    final TakeHistory h = TakeHistory.vide
        // Avant le devoir : ne compte pas.
        .withTake(prise(pose.subtract(const Duration(days: 1)), 90))
        .withTake(prise(pose.add(const Duration(days: 1)), 70))
        // Pas allee au bout : ne compte pas.
        .withTake(prise(pose.add(const Duration(days: 2)), 85, fin: false));
    expect(devoir().bestSince(h), 70);
    expect(devoir().doneIn(h), isFalse);
    final TakeHistory apres =
        h.withTake(prise(pose.add(const Duration(days: 3)), 81));
    expect(devoir().doneIn(apres), isTrue);
  });

  test('un nouveau devoir sur le meme passage remplace l ancien', () {
    final HomeworkList l = HomeworkList.vide
        .withHomework(devoir(vise: 70))
        .withHomework(devoir(vise: 80, mot: 'Lie les croches'));
    expect(l.items.single.targetPulseBpm, 80);
    expect(l.without('exo:gamme-re').items, isEmpty);
  });

  test('les devoirs se rangent et se relisent', () {
    final HomeworkList l =
        HomeworkList.vide.withHomework(devoir(mot: 'Lie les croches'));
    final Homework relu = HomeworkList.decode(l.encode()).items.single;
    expect(relu.note, 'Lie les croches');
    expect(relu.exerciseId, 'gamme-re');
    expect(relu.targetPulseBpm, 80);
    expect(HomeworkList.decode('{abime').items, isEmpty);
  });
}
