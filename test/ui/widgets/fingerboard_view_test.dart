import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/finger_pattern.dart';
import 'package:violon/core/music/fingerboard.dart';
import 'package:violon/ui/widgets/fingerboard_view.dart';

/// Ce que le peintre a effectivement dessine.
class _CanvasEspion implements Canvas {
  final List<({Offset de, Offset a, Color couleur, double epaisseur})> traits =
      <({Offset de, Offset a, Color couleur, double epaisseur})>[];
  final List<
          ({Offset centre, double rayon, Color couleur, PaintingStyle style})>
      ronds =
      <({Offset centre, double rayon, Color couleur, PaintingStyle style})>[];
  int glyphes = 0;

  @override
  void drawLine(Offset de, Offset a, Paint p) =>
      traits.add((de: de, a: a, couleur: p.color, epaisseur: p.strokeWidth));

  @override
  void drawCircle(Offset c, double rayon, Paint p) =>
      ronds.add((centre: c, rayon: rayon, couleur: p.color, style: p.style));

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => glyphes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Les ordonnees des doigts dessines, du plus aigu au plus grave.
List<double> _ordonnees(_CanvasEspion vu) => vu.ronds
    .where((({
              Offset centre,
              double rayon,
              Color couleur,
              PaintingStyle style
            }) r) =>
        r.style == PaintingStyle.fill)
    .map((({
              Offset centre,
              double rayon,
              Color couleur,
              PaintingStyle style
            }) r) =>
        r.centre.dy)
    .toList()
  ..sort();

void main() {
  const FingerPattern majeur = FingerPattern.deuxTroisSerres;

  Future<_CanvasEspion> peindre(
    WidgetTester tester,
    FingerPlacement? cible, {
    FingerPattern pattern = majeur,
    double hauteur = 200,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: hauteur,
              child: FingerboardView(
                pattern: pattern,
                target: cible,
                height: hauteur,
              ),
            ),
          ),
        ),
      ),
    );
    final CustomPaint peinture = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byKey(FingerboardView.fingerboardKey),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    final _CanvasEspion espion = _CanvasEspion();
    peinture.painter!.paint(espion, Size(320, hauteur));
    return espion;
  }

  /// Le premier doigt sur la corde de re : un mi.
  const FingerPlacement premierSurRe =
      FingerPlacement(stringMidi: 62, finger: 1, midi: 64);

  group('FingerboardView', () {
    testWidgets('quatre cordes, toujours', (WidgetTester tester) async {
      // On montre une corde **parmi quatre** : une corde seule ne dirait pas
      // laquelle c'est.
      final _CanvasEspion vu = await peindre(tester, premierSurRe);
      expect(vu.traits.length, Fingerboard.strings.length);
    });

    testWidgets('la corde visee est la seule appuyee', (
      WidgetTester tester,
    ) async {
      final _CanvasEspion vu = await peindre(tester, premierSurRe);
      final List<double> epaisseurs = vu.traits
          .map((({Offset de, Offset a, Color couleur, double epaisseur}) t) =>
              t.epaisseur)
          .toList();
      final double max =
          epaisseurs.reduce((double a, double b) => a > b ? a : b);
      expect(epaisseurs.where((double e) => e == max).length, 1);
      // Et c'est la deuxieme en partant du grave : sol, **re**, la, mi.
      expect(epaisseurs.indexOf(max), 1);
    });

    testWidgets('le demi-ton de l ecartement se voit', (
      WidgetTester tester,
    ) async {
      // **C'est ce que l'ecartement fait travailler.** En 2-3 serres, le
      // deuxieme et le troisieme doigt se touchent ; les autres sont a un ton.
      // Un schema a ecarts egaux -- un manche de guitare -- ne dirait rien de
      // ce qui est justement le sujet.
      final _CanvasEspion vu = await peindre(tester, premierSurRe);
      final List<double> y = _ordonnees(vu);
      expect(y, hasLength(4));
      final double unDeux = y[1] - y[0];
      final double deuxTrois = y[2] - y[1];
      final double troisQuatre = y[3] - y[2];
      expect(deuxTrois, lessThan(unDeux));
      expect(deuxTrois, lessThan(troisQuatre));
    });

    testWidgets('les quatre doigts ne se chevauchent jamais', (
      WidgetTester tester,
    ) async {
      // **Constate sur l'appareil, puis sur les chiffres.** Un demi-ton fait
      // dix-sept points de haut en portrait et onze en paysage : une pastille
      // reglee a la main mord sur sa voisine des que la place se reduit. Le
      // rayon suit donc l'ecart le plus serre, et on le verifie sur toute la
      // gamme de hauteurs que les deux orientations donnent.
      for (final double hauteur in <double>[120, 150, 180, 240]) {
        for (final FingerPattern ecart in FingerPattern.premierePosition) {
          final _CanvasEspion vu = await peindre(
            tester,
            premierSurRe,
            pattern: ecart,
            hauteur: hauteur,
          );
          final List<double> y = _ordonnees(vu);
          final double diametre = 2 *
              vu.ronds
                  .where((({
                            Offset centre,
                            double rayon,
                            Color couleur,
                            PaintingStyle style
                          }) r) =>
                      r.style == PaintingStyle.fill)
                  .map((({
                            Offset centre,
                            double rayon,
                            Color couleur,
                            PaintingStyle style
                          }) r) =>
                      r.rayon)
                  .reduce((double a, double b) => a > b ? a : b);
          for (int i = 1; i < y.length; i++) {
            expect(
              y[i] - y[i - 1],
              greaterThan(diametre),
              reason: 'hauteur $hauteur, ecartement ${ecart.id}',
            );
          }
        }
      }
    });

    testWidgets('le rond de corde a vide ne mord pas sur le nom', (
      WidgetTester tester,
    ) async {
      const FingerPlacement reAVide =
          FingerPlacement(stringMidi: 62, finger: 0, midi: 62);
      final _CanvasEspion vu = await peindre(tester, reAVide);
      final ({
        Offset centre,
        double rayon,
        Color couleur,
        PaintingStyle style
      }) creux = vu.ronds.firstWhere(
        (({
                  Offset centre,
                  double rayon,
                  Color couleur,
                  PaintingStyle style
                }) r) =>
            r.style == PaintingStyle.stroke,
      );
      // Le nom des cordes est ecrit a partir de l'ordonnee zero, sur une
      // quinzaine de points.
      expect(creux.centre.dy - creux.rayon, greaterThan(16));
    });

    testWidgets('le doigt demande se distingue par la couleur', (
      WidgetTester tester,
    ) async {
      // **Pas par la taille.** Deux doigts serres sont separes d'un demi-ton,
      // soit moins de vingt points ici : grossir celui qu'on demande le
      // ferait mordre sur ses voisins.
      final _CanvasEspion vu = await peindre(tester, premierSurRe);
      final List<
              ({
                Offset centre,
                double rayon,
                Color couleur,
                PaintingStyle style
              })> doigts =
          vu.ronds
              .where((({
                        Offset centre,
                        double rayon,
                        Color couleur,
                        PaintingStyle style
                      }) r) =>
                  r.style == PaintingStyle.fill)
              .toList();
      expect(doigts, hasLength(4));
      expect(
        doigts
            .map((({
                      Offset centre,
                      double rayon,
                      Color couleur,
                      PaintingStyle style
                    }) r) =>
                r.rayon)
            .toSet(),
        hasLength(1),
      );
      // Un seul est opaque : les trois autres sont de l'encre effacee.
      final List<
              ({
                Offset centre,
                double rayon,
                Color couleur,
                PaintingStyle style
              })> appuyes =
          doigts
              .where((({
                        Offset centre,
                        double rayon,
                        Color couleur,
                        PaintingStyle style
                      }) r) =>
                  r.couleur.a > 0.5)
              .toList();
      expect(appuyes, hasLength(1));
      // Le premier doigt est le plus haut des quatre.
      expect(appuyes.first.centre.dy, _ordonnees(vu).first);
    });

    testWidgets('une corde a vide se marque au sillet, en rond creux', (
      WidgetTester tester,
    ) async {
      // C'est la notation de doigte de toutes les partitions : un zero au
      // dessus de la note, pas un doigt pose.
      const FingerPlacement reAVide =
          FingerPlacement(stringMidi: 62, finger: 0, midi: 62);
      final _CanvasEspion vu = await peindre(tester, reAVide);
      final Iterable<
          ({
            Offset centre,
            double rayon,
            Color couleur,
            PaintingStyle style
          })> creux = vu.ronds.where((({
                Offset centre,
                double rayon,
                Color couleur,
                PaintingStyle style
              }) r) =>
          r.style == PaintingStyle.stroke);
      expect(creux, hasLength(1));
      // Au-dessus des quatre doigts : au sillet.
      final double premierDoigt = vu.ronds
          .where((({
                    Offset centre,
                    double rayon,
                    Color couleur,
                    PaintingStyle style
                  }) r) =>
              r.style == PaintingStyle.fill)
          .map((({
                    Offset centre,
                    double rayon,
                    Color couleur,
                    PaintingStyle style
                  }) r) =>
              r.centre.dy)
          .reduce((double a, double b) => a < b ? a : b);
      expect(creux.first.centre.dy, lessThan(premierDoigt));
    });

    testWidgets('sans cible, aucun doigt n est dessine', (
      WidgetTester tester,
    ) async {
      // L'aide ne s'affiche pas tout de suite : chercher sa note fait partie
      // de l'exercice.
      final _CanvasEspion vu = await peindre(tester, null);
      expect(vu.ronds, isEmpty);
      expect(vu.traits.length, Fingerboard.strings.length);
    });

    testWidgets('l ecartement change ou tombent les doigts', (
      WidgetTester tester,
    ) async {
      // 2-3 serres contre 3-4 serres : le troisieme doigt monte.
      final _CanvasEspion majeurVu = await peindre(tester, premierSurRe);
      final _CanvasEspion autreVu = await peindre(
        tester,
        premierSurRe,
        pattern: FingerPattern.troisQuatreSerres,
      );
      final List<double> a = majeurVu.ronds
          .map((({
                    Offset centre,
                    double rayon,
                    Color couleur,
                    PaintingStyle style
                  }) r) =>
              r.centre.dy)
          .toList()
        ..sort();
      final List<double> b = autreVu.ronds
          .map((({
                    Offset centre,
                    double rayon,
                    Color couleur,
                    PaintingStyle style
                  }) r) =>
              r.centre.dy)
          .toList()
        ..sort();
      expect(b[2], greaterThan(a[2]));
    });
  });
}
