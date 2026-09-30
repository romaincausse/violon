import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/bench_recorder.dart';
import 'package:violon/ui/screens/bench_screen.dart';

void main() {
  Future<FakeBenchRecorder> poser(WidgetTester tester) async {
    final FakeBenchRecorder banc = FakeBenchRecorder();
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: BenchScreen(recorder: banc)));
    await tester.pumpAndSettle();
    return banc;
  }

  Future<void> appuyer(WidgetTester tester) async {
    await tester.tap(find.byKey(BenchScreen.enregistrerKey));
    await tester.pump();
    await tester.pump();
  }

  group('BenchScreen', () {
    testWidgets('enregistre la prise choisie sous son nom', (
      WidgetTester tester,
    ) async {
      final FakeBenchRecorder banc = await poser(tester);
      await tester
          .tap(find.byKey(BenchScreen.priseKey('05-stars-arret-reprise')));
      await tester.pump();
      await appuyer(tester);
      expect(banc.enCours, '05-stars-arret-reprise');
      expect(find.text('Terminer'), findsOneWidget);

      await appuyer(tester);
      await tester.pumpAndSettle();
      expect(banc.enCours, isNull);
      final List<BenchTake> prises = await banc.takes();
      expect(prises.single.name, '05-stars-arret-reprise');
      expect(prises.single.duration, const Duration(seconds: 1));
    });

    testWidgets('une deuxieme prise du meme nom ne remplace pas la premiere', (
      WidgetTester tester,
    ) async {
      final FakeBenchRecorder banc = await poser(tester);
      for (int i = 0; i < 2; i++) {
        await appuyer(tester);
        await appuyer(tester);
        await tester.pumpAndSettle();
      }
      expect(
        (await banc.takes()).map((BenchTake t) => t.name),
        <String>['01-gamme-detache', '01-gamme-detache-2'],
      );
    });

    testWidgets('une saturation se signale', (WidgetTester tester) async {
      final FakeBenchRecorder banc = await poser(tester);
      await appuyer(tester);
      banc.niveaux.add(-0.2);
      await tester.pump();
      expect(find.textContaining('sature'), findsOneWidget);
      await appuyer(tester);
      await tester.pumpAndSettle();
    });

    testWidgets('une prise s efface', (WidgetTester tester) async {
      final FakeBenchRecorder banc = await poser(tester);
      await appuyer(tester);
      await appuyer(tester);
      await tester.pumpAndSettle();
      // La liste est paresseuse : la prise faite est sous les douze de la
      // grille, pas encore construite.
      await tester.scrollUntilVisible(
        find.byKey(BenchScreen.effacerKey('01-gamme-detache')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(BenchScreen.effacerKey('01-gamme-detache')));
      await tester.pumpAndSettle();
      expect(await banc.takes(), isEmpty);
    });
  });

  test('nomLibre suffixe sans jamais reprendre un nom', () {
    expect(nomLibre('a', <String>[]), 'a');
    expect(nomLibre('a', <String>['a', 'a-2']), 'a-3');
  });
}
