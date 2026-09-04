import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/main.dart';
import 'package:violon/ui/screens/passage_editor_screen.dart';
import 'package:violon/ui/widgets/note_keyboard.dart';

Future<void> pumpEditeur(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: PassageEditorScreen()));
}

Future<void> taperNote(WidgetTester tester, String nom) async {
  await tester.tap(find.widgetWithText(OutlinedButton, nom));
  await tester.pump();
}

void main() {
  group('PassageEditorScreen', () {
    testWidgets('on ne peut pas valider un passage vide', (
      WidgetTester tester,
    ) async {
      await pumpEditeur(tester);

      final Finder valider = find.widgetWithText(TextButton, 'Travailler');
      expect(tester.widget<TextButton>(valider).onPressed, isNull);
      expect(find.textContaining('Tape les notes'), findsOneWidget);
    });

    testWidgets('taper une note l affiche et debloque la validation', (
      WidgetTester tester,
    ) async {
      await pumpEditeur(tester);
      await taperNote(tester, 'Sol4');

      expect(find.textContaining('1 notes'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Travailler'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('le diese ferme les boutons mi et si', (
      WidgetTester tester,
    ) async {
      await pumpEditeur(tester);

      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Mi4'))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.widgetWithText(FilterChip, '♯'));
      await tester.pump();

      // Un mi diese est un fa : le bouton reste en place mais devient inerte,
      // plutot que de disparaitre et de faire sauter tout le clavier.
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Mi4'))
            .onPressed,
        isNull,
      );
      expect(find.widgetWithText(OutlinedButton, 'Fa#4'), findsOneWidget);
    });

    testWidgets('changer le chiffrage renumerote les notes deja saisies', (
      WidgetTester tester,
    ) async {
      await pumpEditeur(tester);

      // Quatre noires tiennent exactement dans une mesure a quatre temps.
      for (int i = 0; i < 4; i++) {
        await taperNote(tester, 'Sol4');
      }
      expect(find.textContaining('mesure 1'), findsOneWidget);

      // A trois temps, la quatrieme bascule dans la mesure suivante. C'est ce
      // que l'ecran doit recalculer, pas seulement pour les notes a venir.
      await tester.tap(find.byKey(const Key('Temps-moins')));
      await tester.pump();
      expect(find.textContaining('mesures 1 a 2'), findsOneWidget);
    });

    testWidgets('la premiere mesure suit la numerotation de la partition', (
      WidgetTester tester,
    ) async {
      await pumpEditeur(tester);
      await taperNote(tester, 'Sol4');

      for (int i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('Mesure-plus')));
        await tester.pump();
      }
      expect(find.textContaining('mesure 12'), findsOneWidget);
    });

    testWidgets('annuler la derniere retire la note', (
      WidgetTester tester,
    ) async {
      await pumpEditeur(tester);
      await taperNote(tester, 'Sol4');
      await taperNote(tester, 'La4');
      expect(find.textContaining('2 notes'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Annuler la derniere'));
      await tester.pump();
      expect(find.textContaining('1 notes'), findsOneWidget);
    });

    testWidgets('tient aussi le telephone couche', (
      WidgetTester tester,
    ) async {
      // Le verrou du portrait est leve : l'ecran de saisie peut desormais se
      // retrouver en paysage, ou il ne reste que 360 pixels de hauteur pour
      // le clavier, les reglages et les notes deja tapees.
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(780, 360);
      tester.view.padding = const FakeViewPadding(bottom: 32);

      await pumpEditeur(tester);

      // Un debordement de rendu fait echouer ce test tout seul.
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(OutlinedButton, 'Si5'), findsOneWidget);
    });

    testWidgets('tient sur un vrai telephone, barre systeme comprise', (
      WidgetTester tester,
    ) async {
      // Galaxy S22 : 1080x2340 physiques a une densite de 3, soit 360x780
      // logiques, moins la barre d'etat et la barre de navigation. C'est le
      // format le plus contraint que l'application doive tenir, et un
      // debordement de Column y ferait echouer ce test.
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);

      await pumpEditeur(tester);

      // Le clavier va jusqu'au si5, et le bas de l'ecran reste au-dessus de
      // la barre de navigation.
      final Finder derniereNote = find.widgetWithText(OutlinedButton, 'Si5');
      expect(derniereNote, findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(NoteKeyboard)).dy,
        lessThanOrEqualTo(780 - 48),
      );

      // Le clavier ne doit pas manger l'ecran : a trois touches par ligne il
      // occupait six lignes et les deux tiers de la hauteur, ne laissant plus
      // voir ni les reglages ni les notes deja saisies. Ne pas deborder ne
      // suffit pas, encore faut-il laisser de la place au reste.
      expect(
        tester.getSize(find.byType(NoteKeyboard)).height,
        lessThan(780 / 2),
        reason: 'le clavier doit tenir dans la moitie basse',
      );

      // Et la saisie reste utilisable a cette taille.
      await taperNote(tester, 'Sol4');
      expect(find.textContaining('1 notes'), findsOneWidget);
    });
  });

  group('NoteKeyboard', () {
    test('couvre la premiere position du violon', () {
      expect(NoteKeyboard.naturals.first, 55, reason: 'sol3, corde a vide');
      expect(NoteKeyboard.naturals.last, 83, reason: 'si5');
      expect(NoteKeyboard.naturals.length, 17);
    });

    test('ne propose pas les alterations qui sont des naturelles', () {
      expect(NoteKeyboard.canSharpen(64), isFalse, reason: 'mi# = fa');
      expect(NoteKeyboard.canSharpen(71), isFalse, reason: 'si# = do');
      expect(NoteKeyboard.canSharpen(65), isTrue, reason: 'fa# existe');
    });
  });

  testWidgets('le passage saisi remplace la demo sur l\'ecran de travail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ViolonApp());
    expect(find.text('Demo - mesures 12 a 13'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    // Croches, et passage annonce a la mesure 12 comme sur la partition.
    await tester.tap(find.text('C'));
    await tester.pump();
    for (int i = 0; i < 11; i++) {
      await tester.tap(find.byKey(const Key('Mesure-plus')));
      await tester.pump();
    }
    for (final String nom in <String>['Sol4', 'La4', 'Si4', 'Do5']) {
      await taperNote(tester, nom);
    }

    await tester.tap(find.widgetWithText(TextButton, 'Travailler'));
    await tester.pumpAndSettle();

    // De retour sur l'ecran de travail, sur le nouveau passage.
    expect(find.text('Mesure 12'), findsNWidgets(2),
        reason: 'titre et bandeau');
    expect(find.text('Demo - mesures 12 a 13'), findsNothing);
  });
}
