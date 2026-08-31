import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/score/staff_layout.dart';
import 'package:violon/ui/widgets/score_view.dart';

void main() {
  Passage passageDe(List<(int, NoteValue)> notes) {
    final PassageBuilder b = PassageBuilder();
    for (final (int midi, NoteValue value) in notes) {
      b.add(midi, value);
    }
    return b.build();
  }

  Future<Size> poser(
    WidgetTester tester,
    Passage passage, {
    double spaceSize = 9,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScoreView(passage: passage, spaceSize: spaceSize),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(CustomPaint).last);
  }

  group('ScoreView', () {
    testWidgets('la largeur peinte suit la largeur calculee', (
      WidgetTester tester,
    ) async {
      final Passage p = passageDe(<(int, NoteValue)>[
        (67, NoteValue.quarter),
        (69, NoteValue.quarter),
      ]);
      const double espace = 9;
      final Size taille = await poser(tester, p, spaceSize: espace);

      // Le widget ne decide d'aucune position : il convertit ce que
      // core/score a calcule.
      expect(
        taille.width,
        closeTo(StaffLayout.of(p).widthSpaces * espace, 0.01),
      );
    });

    testWidgets('doubler la taille d un espace double la portee', (
      WidgetTester tester,
    ) async {
      final Passage p = passageDe(<(int, NoteValue)>[(67, NoteValue.quarter)]);
      final Size petite = await poser(tester, p, spaceSize: 8);
      final Size grande = await poser(tester, p, spaceSize: 16);

      expect(grande.width, closeTo(petite.width * 2, 0.01));
      expect(grande.height, closeTo(petite.height * 2, 0.01));
    });

    testWidgets('la hauteur ne bouge pas sur toute la tessiture du violon', (
      WidgetTester tester,
    ) async {
      // La reserve verticale vaut la portee plus une hampe pleine longueur,
      // ce qui couvre deja du sol3 au si5. Consequence voulue : la portee ne
      // saute pas verticalement quand on change de passage.
      final Size milieu = await poser(
        tester,
        passageDe(<(int, NoteValue)>[(71, NoteValue.quarter)]), // si4
      );
      final Size grave = await poser(
        tester,
        passageDe(<(int, NoteValue)>[(55, NoteValue.quarter)]), // sol3
      );
      final Size aigu = await poser(
        tester,
        passageDe(<(int, NoteValue)>[(83, NoteValue.quarter)]), // si5
      );

      expect(grave.height, milieu.height);
      expect(aigu.height, milieu.height);
    });

    testWidgets('au-dela de la tessiture, la reserve s agrandit quand meme', (
      WidgetTester tester,
    ) async {
      // Mi2 : hors du clavier de saisie, mais la mise en page ne doit pas le
      // rogner pour autant.
      final Size normale = await poser(
        tester,
        passageDe(<(int, NoteValue)>[(71, NoteValue.quarter)]),
      );
      final Size tresGrave = await poser(
        tester,
        passageDe(<(int, NoteValue)>[(40, NoteValue.quarter)]),
      );

      expect(tresGrave.height, greaterThan(normale.height));
    });

    testWidgets('la portee s adapte a la largeur disponible', (
      WidgetTester tester,
    ) async {
      // Sans taille imposee, un passage court doit occuper la largeur offerte
      // plutot que de rester minuscule au milieu de l'ecran.
      final Passage p = passageDe(<(int, NoteValue)>[
        (67, NoteValue.quarter),
        (69, NoteValue.quarter),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 600, child: ScoreView(passage: p)),
          ),
        ),
      );
      final double large = tester.getSize(find.byType(CustomPaint).last).height;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 200, child: ScoreView(passage: p)),
          ),
        ),
      );
      final double etroit =
          tester.getSize(find.byType(CustomPaint).last).height;

      expect(large, greaterThan(etroit));
    });

    testWidgets('la portee ne descend jamais sous le lisible', (
      WidgetTester tester,
    ) async {
      // Seize croches sur un ecran etroit : plutot que de reduire la portee a
      // rien, on s'arrete au plancher et on defile.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: ScoreView(
                passage: passageDe(<(int, NoteValue)>[
                  for (int i = 0; i < 16; i++) (67, NoteValue.eighth),
                ]),
              ),
            ),
          ),
        ),
      );
      final Size taille = tester.getSize(find.byType(CustomPaint).last);
      expect(taille.width, greaterThan(200), reason: 'ca defile');
      expect(
        taille.height / 14,
        greaterThanOrEqualTo(ScoreView.minSpaceSize),
        reason: 'la reserve verticale vaut 14 espaces',
      );
    });

    testWidgets('un passage long defile au lieu de deborder', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);

      // Seize croches : bien plus large qu'un telephone.
      await poser(
        tester,
        passageDe(<(int, NoteValue)>[
          for (int i = 0; i < 16; i++) (67, NoteValue.eighth),
        ]),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      // Un debordement de rendu ferait echouer ce test tout seul.
      expect(find.byType(ScoreView), findsOneWidget);
    });

    testWidgets('le curseur ne se dessine qu une fois lance', (
      WidgetTester tester,
    ) async {
      final Passage p = passageDe(<(int, NoteValue)>[
        (67, NoteValue.quarter),
        (69, NoteValue.quarter),
      ]);
      // Sans curseur puis avec : le rendu doit changer.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ScoreView(passage: p))),
      );
      final CustomPaint sans = tester.widget<CustomPaint>(
        find.byType(CustomPaint).last,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScoreView(passage: p, cursorTick: 240)),
        ),
      );
      final CustomPaint avec = tester.widget<CustomPaint>(
        find.byType(CustomPaint).last,
      );
      expect(avec.painter!.shouldRepaint(sans.painter!), isTrue);
    });

    testWidgets('la couleur d une note peut etre pilotee de l exterieur', (
      WidgetTester tester,
    ) async {
      // C'est par la que le retour de justesse arrivera (lot F2).
      bool demande = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreView(
              passage: passageDe(<(int, NoteValue)>[(67, NoteValue.quarter)]),
              colorOf: (_) {
                demande = true;
                return Colors.green;
              },
            ),
          ),
        ),
      );
      expect(demande, isTrue, reason: 'le peintre consulte bien le resolveur');
    });
  });

  group('gravure Bravura', () {
    /// Compte les glyphes peints. Un glyphe SMuFL est un paragraphe de texte,
    /// une hampe ou une barre de mesure sont des traits : compter les
    /// paragraphes revient a compter les symboles issus de la police.
    Matcher glyphes(int combien) =>
        paintsExactlyCountTimes(#drawParagraph, combien);

    testWidgets('une note nue vaut deux glyphes : la cle et la tete', (
      WidgetTester tester,
    ) async {
      await poser(
        tester,
        passageDe(<(int, NoteValue)>[(69, NoteValue.quarter)]), // la4
      );
      expect(find.byType(CustomPaint).last, glyphes(2));
    });

    testWidgets('un diese ajoute son glyphe devant la tete', (
      WidgetTester tester,
    ) async {
      await poser(
        tester,
        passageDe(<(int, NoteValue)>[(66, NoteValue.quarter)]), // fa#4
      );
      expect(find.byType(CustomPaint).last, glyphes(3));
    });

    testWidgets('une note pointee porte son point', (
      WidgetTester tester,
    ) async {
      final PassageBuilder b = PassageBuilder();
      b.add(69, NoteValue.quarter, dotted: true);
      await poser(tester, b.build());
      expect(find.byType(CustomPaint).last, glyphes(3));
    });

    testWidgets('une croche isolee porte un crochet, une croche ligaturee non',
        (WidgetTester tester) async {
      // Une croche seule : cle + tete + crochet.
      await poser(
        tester,
        passageDe(<(int, NoteValue)>[(69, NoteValue.eighth)]),
      );
      expect(find.byType(CustomPaint).last, glyphes(3));

      // Deux croches sur le meme temps : la ligature remplace les crochets,
      // et elle est peinte, pas composee. Cle + deux tetes.
      await poser(
        tester,
        passageDe(<(int, NoteValue)>[
          (69, NoteValue.eighth),
          (71, NoteValue.eighth),
        ]),
      );
      expect(find.byType(CustomPaint).last, glyphes(3));
    });

    testWidgets('la reserve verticale laisse passer la cle de sol', (
      WidgetTester tester,
    ) async {
      // La cle deborde d'environ trois espaces et demi au-dessus de la portee
      // et de deux et demi en dessous. Si la reserve faite pour les hampes
      // venait a se reduire, la cle serait rognee sans qu'aucun autre test ne
      // bronche.
      const double espace = 9;
      final Size taille = await poser(
        tester,
        passageDe(<(int, NoteValue)>[(71, NoteValue.quarter)]),
        spaceSize: espace,
      );
      expect(taille.height / espace, greaterThanOrEqualTo(10));
    });
  });
}
