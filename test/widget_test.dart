import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/main.dart';

void main() {
  testWidgets('l\'ecran de travail affiche le premier tour', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    expect(find.text('Tour 1 / 10'), findsOneWidget);
    expect(find.text('C\'etait propre'), findsOneWidget);
  });

  testWidgets('valider un tour fait avancer le compteur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    await tester.tap(find.text('C\'etait propre'));
    await tester.pumpAndSettle();

    expect(find.text('Tour 2 / 10'), findsOneWidget);
  });

  testWidgets('la session se termine par un ecran de bilan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    for (int i = 0; i < 10; i++) {
      await tester.tap(find.text('C\'etait propre'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Termine.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Recommencer'), findsOneWidget);
  });

  testWidgets('le bilan n\'affiche plus ni compteur de tours ni tempo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    for (int i = 0; i < 10; i++) {
      await tester.tap(find.text('C\'etait propre'));
      await tester.pumpAndSettle();
    }

    // Le compteur affichait "Tour 11 / 10", et le tempo celui d'un tour qui
    // n'existe plus.
    expect(find.textContaining('Tour '), findsNothing);
    expect(find.textContaining(' bpm'), findsNothing);
  });

  testWidgets('les boutons restent au-dessus de la barre de navigation', (
    WidgetTester tester,
  ) async {
    const double hauteurBarre = 48;
    const double hauteurEcran = 800;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, hauteurEcran);
    tester.view.padding = const FakeViewPadding(bottom: hauteurBarre);

    await tester.pumpWidget(const ViolonApp());

    // Sans SafeArea, ce bouton debordait sous la barre systeme et devenait
    // presque impossible a viser.
    final double basDuBouton = tester
        .getBottomLeft(
          find.widgetWithText(TextButton, 'Celle-la je n\'aime pas'),
        )
        .dy;
    expect(basDuBouton, lessThanOrEqualTo(hauteurEcran - hauteurBarre));
  });
}
