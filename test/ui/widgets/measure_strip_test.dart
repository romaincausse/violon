import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/scoring/measure_scores.dart';
import 'package:violon/ui/widgets/measure_strip.dart';

MeasureScore mesure(int numero,
    {int? score, int entendues = 2, int total = 2}) {
  return MeasureScore(
    measure: numero,
    score: score,
    heardNotes: entendues,
    noteCount: total,
  );
}

Future<void> poser(
  WidgetTester tester,
  List<MeasureScore> mesures, {
  int? courante,
  Size taille = const Size(360, 640),
}) async {
  await tester.binding.setSurfaceSize(taille);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: MeasureStrip(measures: mesures, currentMeasure: courante),
        ),
      ),
    ),
  );
}

/// Part remplie de la case d'une mesure, entre 0 et 1.
double remplissage(WidgetTester tester, int numero) {
  final Finder boite = find.descendant(
    of: find.byKey(MeasureStrip.keyFor(numero)),
    matching: find.byType(FractionallySizedBox),
  );
  return tester.widget<FractionallySizedBox>(boite).heightFactor!;
}

void main() {
  group('MeasureStrip', () {
    testWidgets('une case par mesure, numerotee comme la partition', (
      WidgetTester tester,
    ) async {
      await poser(tester, <MeasureScore>[mesure(12), mesure(13), mesure(14)]);

      expect(find.byKey(MeasureStrip.keyFor(12)), findsOneWidget);
      expect(find.byKey(MeasureStrip.keyFor(14)), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('une mesure pas encore entendue reste vide', (
      WidgetTester tester,
    ) async {
      await poser(tester, <MeasureScore>[mesure(1)]);
      expect(remplissage(tester, 1), 0);
    });

    testWidgets('une mesure jouee juste se remplit entierement', (
      WidgetTester tester,
    ) async {
      await poser(tester, <MeasureScore>[mesure(1, score: 100)]);
      expect(remplissage(tester, 1), 1);
    });

    testWidgets('une mesure moyenne se remplit a moitie', (
      WidgetTester tester,
    ) async {
      // L'information est portee par la HAUTEUR, pas seulement par la
      // couleur : la teinte est ce qui se degrade en premier en vision
      // peripherique, et elle ne dit rien a un daltonien.
      await poser(tester, <MeasureScore>[mesure(1, score: 50)]);
      expect(remplissage(tester, 1), closeTo(0.5, 0.01));
    });

    testWidgets(
        'une mesure a peine entendue ne se remplit pas comme une mesure tenue',
        (
      WidgetTester tester,
    ) async {
      // Cent sur cent etabli sur une note sur quatre ne vaut pas cent sur
      // cent sur toute la mesure. Afficher les deux pareil mentirait.
      await poser(tester, <MeasureScore>[
        mesure(1, score: 100, entendues: 1, total: 4),
      ]);
      expect(remplissage(tester, 1), closeTo(0.25, 0.01));
    });

    testWidgets('la mesure en cours se distingue des autres', (
      WidgetTester tester,
    ) async {
      await poser(tester, <MeasureScore>[mesure(1), mesure(2)], courante: 2);

      BoxDecoration deco(int n) => tester
          .widget<Container>(find.byKey(MeasureStrip.keyFor(n)))
          .decoration! as BoxDecoration;
      expect(deco(2).border!.top.width, greaterThan(deco(1).border!.top.width));
    });

    testWidgets('sans mesures, rien ne s affiche', (WidgetTester tester) async {
      await poser(tester, <MeasureScore>[]);
      expect(find.byKey(MeasureStrip.stripKey), findsNothing);
    });

    testWidgets('huit mesures tiennent sur un petit telephone', (
      WidgetTester tester,
    ) async {
      // Le projet a deja eu deux debordements en production. Un bandeau qui
      // deborde est inutilisable la ou il sert : sur un ecran de 360 points.
      await poser(
        tester,
        <MeasureScore>[for (int i = 1; i <= 8; i++) mesure(i, score: 80)],
        taille: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('et dans la colonne etroite du mode paysage', (
      WidgetTester tester,
    ) async {
      await poser(
        tester,
        <MeasureScore>[for (int i = 1; i <= 4; i++) mesure(i, score: 80)],
        taille: const Size(200, 360),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('chaque case s annonce pour la synthese vocale', (
      WidgetTester tester,
    ) async {
      await poser(tester, <MeasureScore>[mesure(7, score: 84), mesure(8)]);

      expect(find.bySemanticsLabel('Mesure 7, 84 sur 100'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Mesure 8, pas encore entendue'),
        findsOneWidget,
      );
    });
  });
}
