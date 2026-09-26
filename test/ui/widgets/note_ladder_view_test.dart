import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/scoring/note_ladder.dart';
import 'package:violon/core/scoring/tuning_trace.dart';
import 'package:violon/ui/widgets/note_ladder_view.dart';
import 'package:violon/ui/widgets/tuning_colors.dart';

/// Ce que le peintre a effectivement dessine.
///
/// **On interroge le peintre, pas une image.** Un golden dirait "ca a change"
/// a la premiere retouche de theme sans dire ce qui a change ; ici chaque
/// test nomme la propriete qu'il defend.
class _CanvasEspion implements Canvas {
  final List<({RRect forme, Color couleur, PaintingStyle style})> barreaux =
      <({RRect forme, Color couleur, PaintingStyle style})>[];
  final List<({Offset centre, double rayon, Color couleur})> cercles =
      <({Offset centre, double rayon, Color couleur})>[];
  final List<Path> chemins = <Path>[];
  int noms = 0;
  int couches = 0;

  @override
  void drawRRect(RRect rrect, Paint paint) =>
      barreaux.add((forme: rrect, couleur: paint.color, style: paint.style));

  @override
  void drawCircle(Offset c, double rayon, Paint paint) =>
      cercles.add((centre: c, rayon: rayon, couleur: paint.color));

  @override
  void drawPath(Path path, Paint paint) => chemins.add(path);

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => noms++;

  @override
  void saveLayer(Rect? bounds, Paint paint) => couches++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Les barreaux, sans le cadre de fond ni le lisere de la note attendue.
List<({RRect forme, Color couleur, PaintingStyle style})> _barreauxPleins(
  _CanvasEspion vu,
) =>
    vu.barreaux
        .where(
          (({RRect forme, Color couleur, PaintingStyle style}) b) =>
              b.style == PaintingStyle.fill,
        )
        .skip(1)
        .toList();

TuningTrace traceDe(List<double> midis) {
  final TuningTrace t = TuningTrace();
  for (int i = 0; i < midis.length; i++) {
    t.add(i * 46, 0, midi: midis[i]);
  }
  return t;
}

void main() {
  const Size grand = Size(360, 400);

  Future<_CanvasEspion> peindre(
    WidgetTester tester, {
    required List<int> notes,
    TuningTrace? trace,
    int? attendu,
    Size taille = grand,
  }) async {
    await tester.binding.setSurfaceSize(taille);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteLadderView(
            ladder: NoteLadder(notes: notes),
            trace: trace ?? TuningTrace(),
            expected: attendu,
          ),
        ),
      ),
    );
    final CustomPaint peinture = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byKey(NoteLadderView.ladderKey),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    final _CanvasEspion espion = _CanvasEspion();
    peinture.painter!.paint(espion, taille);
    return espion;
  }

  group('NoteLadderView', () {
    testWidgets('un barreau par note de l exercice, et pas un de plus', (
      WidgetTester tester,
    ) async {
      // **Pas un clavier chromatique.** Sur un motif la-re, deux barreaux, et
      // entre eux le vide qui les separe vraiment : on lit l'intervalle avant
      // de lire les noms.
      final _CanvasEspion vu = await peindre(tester, notes: <int>[62, 69]);
      expect(_barreauxPleins(vu), hasLength(2));
    });

    testWidgets('le grave est en bas', (WidgetTester tester) async {
      final _CanvasEspion vu = await peindre(tester, notes: <int>[62, 69]);
      final List<({RRect forme, Color couleur, PaintingStyle style})> b =
          _barreauxPleins(vu);
      expect(b.first.forme.center.dy, greaterThan(b.last.forme.center.dy));
    });

    testWidgets('le barreau atteint est le seul colore', (
      WidgetTester tester,
    ) async {
      // "La hauteur jouee vient colorer celui qu'elle atteint" : les autres
      // restent des contenants vides.
      final _CanvasEspion vu = await peindre(
        tester,
        notes: <int>[62, 69],
        trace: traceDe(<double>[69.0, 69.05]),
        attendu: 69,
      );
      final List<Color> couleurs = _barreauxPleins(
        vu,
      )
          .map((({RRect forme, Color couleur, PaintingStyle style}) b) =>
              b.couleur)
          .toList();
      expect(couleurs.toSet(), hasLength(2), reason: 'un seul se distingue');
    });

    testWidgets('jouer la mauvaise note dit dans quel sens on s est trompe', (
      WidgetTester tester,
    ) async {
      // Atteindre un barreau qui n'est pas celui attendu n'est pas "juste" :
      // c'est trop bas ou trop haut, dans les memes couleurs que partout
      // ailleurs.
      final _CanvasEspion bas = await peindre(
        tester,
        notes: <int>[62, 69],
        trace: traceDe(<double>[62.0, 62.02]),
        attendu: 69,
      );
      expect(
        bas.cercles.last.couleur.toARGB32(),
        TuningColors.low.toARGB32(),
        reason: 'un re au lieu d un la',
      );

      final _CanvasEspion haut = await peindre(
        tester,
        notes: <int>[62, 69],
        trace: traceDe(<double>[69.0, 69.02]),
        attendu: 62,
      );
      expect(
        haut.cercles.last.couleur.toARGB32(),
        TuningColors.high.toARGB32(),
      );
    });

    testWidgets('la bonne note est verte', (WidgetTester tester) async {
      final _CanvasEspion vu = await peindre(
        tester,
        notes: <int>[62, 69],
        trace: traceDe(<double>[69.0, 69.1]),
        attendu: 69,
      );
      expect(
        vu.cercles.last.couleur.toARGB32(),
        TuningColors.inTune.toARGB32(),
      );
    });

    testWidgets('une erreur d octave se colle au bord sans sortir du cadre', (
      WidgetTester tester,
    ) async {
      // On voit d'un coup qu'on n'est pas du tout sur la note, sans avoir a
      // lire un chiffre.
      final _CanvasEspion vu = await peindre(
        tester,
        notes: <int>[62, 69],
        trace: traceDe(<double>[81.0, 81.0]),
        attendu: 69,
      );
      expect(vu.cercles.last.centre.dy, 0);
    });

    testWidgets('le trace est un seul chemin, et le passe s attenue', (
      WidgetTester tester,
    ) async {
      final _CanvasEspion vu = await peindre(
        tester,
        notes: <int>[62, 69],
        trace: traceDe(<double>[62, 64, 66, 68, 69]),
        attendu: 69,
      );
      expect(vu.chemins, hasLength(1));
      expect(vu.couches, 1, reason: 'le masque est pose dans une couche');
    });

    testWidgets('les noms s effacent quand les barreaux se serrent', (
      WidgetTester tester,
    ) async {
      // Une gamme sur deux octaves pose vingt-cinq barreaux : les nommer tous
      // empilerait des etiquettes illisibles. Restent le nom attendu et celui
      // qu'on atteint -- les deux qui servent.
      final _CanvasEspion large = await peindre(tester, notes: <int>[62, 69]);
      final _CanvasEspion serre = await peindre(
        tester,
        notes: <int>[for (int m = 55; m <= 79; m++) m],
        attendu: 69,
      );
      expect(large.noms, 2);
      expect(serre.noms, lessThan(large.noms));
    });

    testWidgets('au repos, la tete attend au milieu', (
      WidgetTester tester,
    ) async {
      // Une echelle vide doit avoir l'air d'attendre, pas d'etre eteinte.
      final _CanvasEspion vu = await peindre(tester, notes: <int>[62, 69]);
      expect(vu.cercles, isNotEmpty);
      expect(vu.cercles.last.centre.dy, grand.height / 2);
      expect(vu.chemins, isEmpty);
    });

    testWidgets('un exercice vide ne fait pas planter', (
      WidgetTester tester,
    ) async {
      await peindre(tester, notes: <int>[]);
      expect(tester.takeException(), isNull);
    });
  });
}
