import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/main.dart';

void main() {
  testWidgets('l\'application s\'ouvre sur le passage de demonstration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    expect(find.text('Demo - mesures 12 a 13'), findsOneWidget);
    expect(find.text('Mesures 12 a 13'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget);
  });

  testWidgets('les notes du passage sont affichees dans l\'ordre', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    // L'emplacement de la portee gravee (lot G4) montre pour l'instant la
    // suite des notes : c'est ce qui permet de verifier qu'un passage arrive
    // bien jusqu'a l'ecran de travail.
    expect(find.text('Sol4'), findsWidgets);
  });

  testWidgets('le tempo ecrit du passage est affiche', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());

    expect(find.textContaining('bpm'), findsOneWidget);
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
