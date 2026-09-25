import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/scoring/tuning_trace.dart';
import 'package:violon/ui/widgets/tuning_ribbon.dart';

Future<void> poser(
  WidgetTester tester,
  TuningTrace trace, {
  Size taille = const Size(360, 640),
  double hauteur = 44,
}) async {
  await tester.binding.setSurfaceSize(taille);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: TuningRibbon(trace: trace, height: hauteur)),
      ),
    ),
  );
}

TuningTrace traceDe(List<double> cents) {
  final TuningTrace t = TuningTrace();
  for (int i = 0; i < cents.length; i++) {
    t.add(i * 50, cents[i]);
  }
  return t;
}

void main() {
  group('TuningRibbon', () {
    testWidgets('un trace vide s affiche quand meme', (
      WidgetTester tester,
    ) async {
      // Le ruban est un repere permanent : il ne doit pas apparaitre et
      // disparaitre au gre des silences.
      await poser(tester, TuningTrace());
      expect(find.byKey(TuningRibbon.ribbonKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('il occupe la hauteur demandee', (WidgetTester tester) async {
      await poser(tester, traceDe(<double>[0, 5]), hauteur: 44);
      expect(tester.getSize(find.byKey(TuningRibbon.ribbonKey)).height, 44);
    });

    testWidgets('il peint un trace des qu il y a deux points', (
      WidgetTester tester,
    ) async {
      await poser(tester, traceDe(<double>[-30, -10, 0, 12]));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('un ecart enorme ne sort pas du cadre', (
      WidgetTester tester,
    ) async {
      // Une erreur d'octave de YIN vaut 1200 cents. Le trait doit saturer,
      // pas deborder du ruban ni faire exploser la peinture.
      await poser(tester, traceDe(<double>[0, 1200, -1200, 0]));
      expect(tester.takeException(), isNull);
    });

    testWidgets('il tient dans la colonne etroite du paysage', (
      WidgetTester tester,
    ) async {
      await poser(
        tester,
        traceDe(<double>[0, 10, -10, 5]),
        taille: const Size(200, 360),
        hauteur: 24,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('un seul point ne trace pas de ligne, sans planter', (
      WidgetTester tester,
    ) async {
      await poser(tester, traceDe(<double>[15]));
      expect(tester.takeException(), isNull);
    });
  });
}
