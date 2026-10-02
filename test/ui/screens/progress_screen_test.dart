import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/take_history.dart';
import 'package:violon/ui/screens/progress_screen.dart';

void main() {
  final DateTime maintenant = DateTime(2026, 10, 2, 19);

  TakeRecord prise(int minutes,
          {List<NoteTrace> notes = const <NoteTrace>[]}) =>
      TakeRecord(
        atMs: maintenant
            .subtract(Duration(minutes: minutes))
            .millisecondsSinceEpoch,
        key: 'exo:gamme',
        title: 'Gamme de re',
        fromMeasure: 1,
        toMeasure: 2,
        writtenPulseBpm: 72,
        durationMs: 60000,
        heldPulseBpm: 70,
        tuningScore: 85,
        rhythmScore: 90,
        reachedEnd: true,
        notes: notes,
      );

  Future<void> poser(WidgetTester tester, TakeHistory h,
          {bool lecon = false}) =>
      tester.pumpWidget(
        MaterialApp(
          home: ProgressScreen(
            history: h,
            clock: () => maintenant,
            detailed: lecon,
          ),
        ),
      );

  testWidgets('les courbes par travail ne sortent qu en mode lecon', (
    WidgetTester tester,
  ) async {
    final TakeHistory h = TakeHistory.vide.withTake(prise(30));
    await poser(tester, h);
    expect(find.byKey(ProgressScreen.courbeKey('exo:gamme')), findsNothing);
    await poser(tester, h, lecon: true);
    expect(find.byKey(ProgressScreen.courbeKey('exo:gamme')), findsOneWidget);
  });

  testWidgets('sans prise, il dit d ou viendront les courbes', (
    WidgetTester tester,
  ) async {
    await poser(tester, TakeHistory.vide);
    expect(find.textContaining('premiere prise'), findsOneWidget);
  });

  testWidgets('le journal du jour compte les prises et l archet', (
    WidgetTester tester,
  ) async {
    await poser(
      tester,
      TakeHistory.vide.withTake(prise(30)).withTake(prise(10)),
    );
    expect(find.textContaining('2 prises, 2 min d archet'), findsOneWidget);
    expect(find.textContaining('nouveau record, 70'), findsOneWidget);
    // Les jours joues ce mois (V3) : deux prises le meme jour, un jour.
    expect(
      tester.widget<Text>(find.byKey(ProgressScreen.joursKey)).data,
      '1 jour joue en octobre',
    );
  });

  testWidgets('un doigt qui derive sur plusieurs cordes est nomme', (
    WidgetTester tester,
  ) async {
    NoteTrace n(int midi, double c) =>
        NoteTrace(midi: midi, measure: 1, cents: c);
    await poser(
      tester,
      TakeHistory.vide.withTake(prise(5, notes: <NoteTrace>[
        n(66, -20),
        n(73, -18),
        n(59, -22),
        n(66, -19),
        n(73, -21),
        n(59, -17),
      ])),
    );
    expect(find.byKey(ProgressScreen.mainKey), findsOneWidget);
    expect(
      find.textContaining('2e doigt haut tombe bas'),
      findsOneWidget,
    );
    expect(find.textContaining('cordes de sol, re et la'), findsOneWidget);
  });
}
