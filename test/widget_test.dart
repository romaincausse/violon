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
}
