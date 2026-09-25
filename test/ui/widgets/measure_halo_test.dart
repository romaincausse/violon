import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/ui/widgets/measure_halo.dart';

void main() {
  group('MeasureHalo', () {
    testWidgets('il laisse passer les appuis', (WidgetTester tester) async {
      // Une recompense ne doit jamais avaler un appui : le bouton passe
      // dessous reste atteignable, y compris pendant la lueur.
      int appuis = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeasureHalo(
              trigger: 1,
              child: Center(
                child: FilledButton(
                  onPressed: () => appuis++,
                  child: const Text('Jouer'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Jouer'));
      expect(appuis, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('la lueur s eteint d elle-meme', (WidgetTester tester) async {
      // Elle marque une etape, elle ne s'installe pas : une lueur qui reste
      // deviendrait un decor, puis du bruit.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeasureHalo(
              trigger: 1,
              duration: Duration(milliseconds: 300),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'plus rien ne s anime une fois la lueur passee');
    });

    testWidgets('changer de declencheur rallume la lueur', (
      WidgetTester tester,
    ) async {
      Widget avec(int n) => MaterialApp(
            home: Scaffold(
              body: MeasureHalo(trigger: n, child: const SizedBox.expand()),
            ),
          );

      await tester.pumpWidget(avec(1));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(avec(2));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue,
          reason: 'une nouvelle mesure reussie relance l animation');
      await tester.pumpAndSettle();
    });

    testWidgets('reconstruire sans changer le declencheur ne rallume rien', (
      WidgetTester tester,
    ) async {
      Widget avec(int n) => MaterialApp(
            home: Scaffold(
              body: MeasureHalo(trigger: n, child: const SizedBox.expand()),
            ),
          );
      await tester.pumpWidget(avec(3));
      await tester.pumpAndSettle();

      // L'ecran se reconstruit a chaque trame du micro : la lueur ne doit pas
      // repartir a chaque fois.
      await tester.pumpWidget(avec(3));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
