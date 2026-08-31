import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/main.dart';
import 'package:violon/ui/widgets/score_view.dart';

void main() {
  testWidgets('l\'application s\'ouvre sur le passage de demonstration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    expect(find.text('Demo - mesures 12 a 13'), findsOneWidget);
    expect(find.text('Mesures 12 a 13'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget);
  });

  testWidgets('le passage est grave sur une portee', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    expect(find.byType(ScoreView), findsOneWidget);
    // Les notes ne sont plus du texte : elles sont peintes.
    expect(find.text('Sol4'), findsNothing);
  });

  testWidgets('le tempo ecrit du passage est affiche', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    expect(find.textContaining('bpm'), findsOneWidget);
  });

  testWidgets('le metronome se lance et s arrete depuis l ecran', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    expect(find.text('Lancer le metronome'), findsOneWidget);
    await tester.tap(find.text('Lancer le metronome'));
    await tester.pump();
    expect(find.text('Arreter'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      greaterThan(0),
    );

    await tester.tap(find.text('Arreter'));
    await tester.pump();
    expect(find.text('Lancer le metronome'), findsOneWidget);
  });

  testWidgets('changer de passage arrete la pulsation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());
    await tester.tap(find.text('Lancer le metronome'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Arreter'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sol4'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Travailler'));
    await tester.pumpAndSettle();

    // Le tempo du nouveau passage n'est pas celui de l'ancien : laisser
    // battre l'ancien induirait en erreur.
    expect(find.text('Lancer le metronome'), findsOneWidget);
  });

  testWidgets('le contenu reste au-dessus de la barre de navigation', (
    WidgetTester tester,
  ) async {
    const double hauteurBarre = 48;
    const double hauteurEcran = 800;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, hauteurEcran);
    tester.view.padding = const FakeViewPadding(bottom: hauteurBarre);

    await tester.pumpWidget(const ViolonApp());

    // Sans SafeArea, le bas de la colonne debordait sous la barre systeme.
    // On mesure le contenu et non le SafeArea : ce dernier occupe toute la
    // hauteur, c'est son enfant qu'il decale.
    final double basDuContenu =
        tester.getBottomLeft(find.byKey(const Key('session-content'))).dy;
    expect(basDuContenu, lessThanOrEqualTo(hauteurEcran - hauteurBarre));
  });
}
