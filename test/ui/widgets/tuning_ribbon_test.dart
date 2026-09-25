import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/scoring/live_tuning.dart';
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

/// Ce que le peintre a effectivement dessine.
///
/// **On interroge le peintre, pas une image.** Un golden dirait "ca a change"
/// a la premiere retouche de theme sans dire ce qui a change ; ici chaque test
/// nomme la propriete qu'il defend -- la tete est dans le cadre, le passe est
/// attenue, les graduations disparaissent quand la place manque.
class _CanvasEspion implements Canvas {
  final List<({Offset centre, double rayon})> cercles =
      <({Offset centre, double rayon})>[];
  final List<({Offset a, Offset b})> lignes = <({Offset a, Offset b})>[];
  final List<Rect> rectangles = <Rect>[];
  final List<Path> chemins = <Path>[];
  int couches = 0;

  @override
  void drawCircle(Offset c, double rayon, Paint paint) =>
      cercles.add((centre: c, rayon: rayon));

  @override
  void drawLine(Offset a, Offset b, Paint paint) => lignes.add((a: a, b: b));

  @override
  void drawRect(Rect rect, Paint paint) => rectangles.add(rect);

  @override
  void drawPath(Path path, Paint paint) => chemins.add(path);

  @override
  void saveLayer(Rect? bounds, Paint paint) => couches++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Fait peindre le ruban sur l'espion et rend ce qu'il a vu.
_CanvasEspion _peindre(
  WidgetTester tester, {
  required Size taille,
}) {
  final CustomPaint peinture = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byKey(TuningRibbon.ribbonKey),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  final _CanvasEspion espion = _CanvasEspion();
  peinture.painter!.paint(espion, taille);
  return espion;
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

  group('ce que le peintre dessine', () {
    const Size grand = Size(300, 96);
    const Size petit = Size(300, 24);

    testWidgets('au repos, la tete se pose au milieu', (
      WidgetTester tester,
    ) async {
      // Un ruban vide doit avoir l'air d'attendre, pas d'etre eteint : c'est
      // ce qu'on a sous les yeux avant chaque prise.
      await poser(tester, TuningTrace(), hauteur: 96);
      final _CanvasEspion vu = _peindre(tester, taille: grand);

      expect(vu.cercles, isNotEmpty, reason: 'la tete est dessinee');
      expect(vu.cercles.last.centre.dy, grand.height / 2);
      expect(vu.chemins, isEmpty, reason: 'rien a tracer');
    });

    testWidgets('la tete reste dans le cadre, halo compris', (
      WidgetTester tester,
    ) async {
      // Sans marge a droite, le halo du point courant -- celui qu'on suit du
      // coin de l'oeil -- etait coupe par le coin arrondi.
      await poser(tester, traceDe(<double>[0, 8, -4]), hauteur: 96);
      final _CanvasEspion vu = _peindre(tester, taille: grand);

      final ({Offset centre, double rayon}) halo = vu.cercles.first;
      expect(halo.centre.dx + halo.rayon, lessThanOrEqualTo(grand.width));
    });

    testWidgets('la tete monte quand la note est haute', (
      WidgetTester tester,
    ) async {
      // Le sens est la moitie de l'information : plus aigu, plus haut.
      await poser(tester, traceDe(<double>[0, 60]), hauteur: 96);
      final _CanvasEspion haut = _peindre(tester, taille: grand);

      await poser(tester, traceDe(<double>[0, -60]), hauteur: 96);
      final _CanvasEspion bas = _peindre(tester, taille: grand);

      expect(haut.cercles.last.centre.dy, lessThan(grand.height / 2));
      expect(bas.cercles.last.centre.dy, greaterThan(grand.height / 2));
    });

    testWidgets('une erreur d octave sature au bord', (
      WidgetTester tester,
    ) async {
      await poser(tester, traceDe(<double>[0, 1200]), hauteur: 96);
      final _CanvasEspion vu = _peindre(tester, taille: grand);

      expect(vu.cercles.last.centre.dy, 0);
    });

    testWidgets('le trace est un seul chemin, pas un segment par point', (
      WidgetTester tester,
    ) async {
      // Un segment par point imposait une couleur par segment, donc une
      // couture franche au milieu d'un trait continu.
      await poser(
        tester,
        traceDe(<double>[0, 10, -10, 5, 20, -30]),
        hauteur: 96,
      );
      final _CanvasEspion vu = _peindre(tester, taille: grand);

      expect(vu.chemins, hasLength(1));
    });

    testWidgets('le passe est attenue, jamais efface', (
      WidgetTester tester,
    ) async {
      // Le masque est pose dans une couche a part : c'est ce qui permet
      // d'attenuer un trait deja peint sans le redessiner morceau par morceau.
      await poser(tester, traceDe(<double>[0, 10, -10]), hauteur: 96);
      final _CanvasEspion vu = _peindre(tester, taille: grand);

      expect(vu.couches, 1);
    });

    testWidgets('les graduations disparaissent quand la place manque', (
      WidgetTester tester,
    ) async {
      // A vingt-quatre points de haut, quatre traits horizontaux ne font pas
      // une echelle : ils remplissent le ruban.
      await poser(tester, traceDe(<double>[0, 5]), hauteur: 96);
      final int avecPlace = _peindre(tester, taille: grand).lignes.length;

      await poser(tester, traceDe(<double>[0, 5]), hauteur: 24);
      final int sansPlace = _peindre(tester, taille: petit).lignes.length;

      expect(sansPlace, 1, reason: 'seul l axe reste');
      expect(avecPlace, greaterThan(sansPlace));
    });

    testWidgets('la bande juste vaut bien perfectCents', (
      WidgetTester tester,
    ) async {
      // La bande est la seule information lisible au coin de l'oeil : si sa
      // hauteur ne correspondait plus au bareme, elle mentirait.
      await poser(tester, TuningTrace(), hauteur: 96);
      final _CanvasEspion vu = _peindre(tester, taille: grand);

      final Rect bande = vu.rectangles.first;
      final double attendue =
          grand.height * LiveTuning.perfectCents / TuningRibbon.rangeCents;
      expect(bande.height, closeTo(attendue, 0.01));
      expect(bande.center.dy, closeTo(grand.height / 2, 0.01));
    });
  });
}
