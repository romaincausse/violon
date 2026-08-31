import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/ui/widgets/metronome_bar.dart';

void main() {
  /// Taux de remplissage de la barre, de 0 a 1.
  double remplissage(WidgetTester tester) => tester
      .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
      .widthFactor!;

  Future<void> poser(
    WidgetTester tester, {
    required bool running,
    int tempoBpm = 60,
    int? beatsPerMeasure,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetronomeBar(
            tempoBpm: tempoBpm,
            running: running,
            beatsPerMeasure: beatsPerMeasure,
          ),
        ),
      ),
    );
  }

  group('MetronomeBar', () {
    testWidgets('a l arret, la barre reste vide', (WidgetTester tester) async {
      await poser(tester, running: false);
      expect(remplissage(tester), 0);

      // Meme apres du temps : rien ne doit bouger tant qu'on n'a pas lance.
      await tester.pump(const Duration(milliseconds: 500));
      expect(remplissage(tester), 0);
    });

    testWidgets('la barre se remplit au fil du temps', (
      WidgetTester tester,
    ) async {
      await poser(tester, running: true, tempoBpm: 60);

      await tester.pump(const Duration(milliseconds: 250));
      final double quart = remplissage(tester);
      await tester.pump(const Duration(milliseconds: 250));
      final double moitie = remplissage(tester);

      expect(quart, greaterThan(0));
      expect(moitie, greaterThan(quart));
      expect(moitie, lessThan(1));
    });

    testWidgets('la barre retombe a chaque temps', (
      WidgetTester tester,
    ) async {
      await poser(tester, running: true, tempoBpm: 60);

      await tester.pump(const Duration(milliseconds: 900));
      final double presqueFini = remplissage(tester);
      // On franchit le battement : la barre repart de tres bas.
      await tester.pump(const Duration(milliseconds: 200));
      final double apresLeTemps = remplissage(tester);

      expect(presqueFini, greaterThan(0.8));
      expect(apresLeTemps, lessThan(presqueFini));
    });

    testWidgets('un tempo plus rapide remplit plus vite', (
      WidgetTester tester,
    ) async {
      await poser(tester, running: true, tempoBpm: 60);
      await tester.pump(const Duration(milliseconds: 200));
      final double lent = remplissage(tester);

      await poser(tester, running: true, tempoBpm: 120);
      await tester.pump(const Duration(milliseconds: 200));
      final double rapide = remplissage(tester);

      expect(rapide, greaterThan(lent));
    });

    testWidgets('arreter remet la barre a zero', (WidgetTester tester) async {
      await poser(tester, running: true);
      await tester.pump(const Duration(milliseconds: 400));
      expect(remplissage(tester), greaterThan(0));

      await poser(tester, running: false);
      await tester.pump();
      expect(remplissage(tester), 0);
    });

    testWidgets('sans chiffrage connu, aucun temps n est accentue', (
      WidgetTester tester,
    ) async {
      // Accentuer en supposant du 4/4 marquerait le mauvais temps sur un 3/4.
      // Tant que Passage ne porte pas le chiffrage, on n'accentue rien.
      await poser(tester, running: true, tempoBpm: 60);
      await tester.pump(const Duration(milliseconds: 10));
      final Color sansChiffrage = tester
          .widget<DecoratedBox>(find.byType(DecoratedBox).last)
          .decoration
          .fill;

      await poser(
        tester,
        running: true,
        tempoBpm: 60,
        beatsPerMeasure: 4,
      );
      await tester.pump(const Duration(milliseconds: 10));
      final Color avecChiffrage = tester
          .widget<DecoratedBox>(find.byType(DecoratedBox).last)
          .decoration
          .fill;

      expect(sansChiffrage, isNot(avecChiffrage));
    });

    testWidgets('le metronome est annonce aux lecteurs d ecran', (
      WidgetTester tester,
    ) async {
      await poser(tester, running: false, tempoBpm: 92);
      expect(
        find.bySemanticsLabel(
          'Metronome visuel, 92 battements par minute',
        ),
        findsOneWidget,
      );
    });
  });
}

extension on Decoration {
  /// Couleur de remplissage de la barre.
  Color get fill => (this as BoxDecoration).color!;
}
