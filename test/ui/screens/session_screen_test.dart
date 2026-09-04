import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/microphone_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';

import 'package:violon/core/music/demo_passage.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/ui/screens/session_screen.dart';
import 'package:violon/ui/widgets/score_view.dart';
import 'package:violon/ui/widgets/tuning_colors.dart';

void main() {
  final Passage demo = buildDemoPassage();
  final ScoreNote premiere = demo.notes.first;

  /// Un jeu parfaitement juste sur la premiere note du passage.
  List<PitchEstimate> juste(int midi, {int combien = 4}) => <PitchEstimate>[
        for (int i = 0; i < combien; i++)
          PitchEstimate(
            frequencyHz: PitchUtils.midiToFrequency(midi),
            confidence: 1,
            timestampMs: i * 46,
          ),
      ];

  /// Pose l'ecran avec un micro scripte, et rend la source pour pouvoir
  /// declencher l'emission au bon moment.
  Future<FakePitchSource> poser(
    WidgetTester tester,
    List<PitchEstimate> script,
  ) async {
    // Pas de `addTearDown(source.dispose)` : c'est l'ecran qui possede la
    // source et qui la libere. La liberer une seconde fois bloque le test,
    // parce qu'on attendrait la fermeture d'un flux deja ferme alors que
    // plus rien ne fait avancer l'horloge.
    final FakePitchSource source = FakePitchSource(script);
    await tester.pumpWidget(
      MaterialApp(
        home: SessionScreen(
          passage: demo,
          onChangePassage: () {},
          onTune: () {},
          pitchSourceFactory: () async => source,
        ),
      ),
    );
    return source;
  }

  /// Lance la lecture et laisse le micro s'ouvrir.
  ///
  /// L'ouverture est volontairement asynchrone dans l'ecran -- le curseur ne
  /// doit pas attendre une permission -- d'ou les deux images.
  Future<void> demarrer(WidgetTester tester) async {
    await tester.tap(find.text('Jouer le passage'));
    await tester.pump();
    await tester.pump();
  }

  /// Arrete la lecture et laisse la liberation du micro se terminer.
  ///
  /// La derniere image avance l'horloge : le faux micro emet sur un minuteur
  /// periodique, et il faut le laisser se declencher une fois pour qu'il
  /// s'annule de lui-meme.
  Future<void> arreter(WidgetTester tester) async {
    await tester.tap(find.text('Arreter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  /// Couleur que la partition donnerait a [note] en cet instant.
  Color? couleurDe(WidgetTester tester, ScoreNote note) {
    final ScoreView vue = tester.widget<ScoreView>(find.byType(ScoreView));
    return vue.colorOf?.call(note);
  }

  group('SessionScreen et le micro', () {
    testWidgets('a l arret, aucune note n est coloree', (
      WidgetTester tester,
    ) async {
      await poser(tester, const <PitchEstimate>[]);
      expect(couleurDe(tester, premiere), isNull);
    });

    testWidgets('une note jouee juste passe au vert', (
      WidgetTester tester,
    ) async {
      final FakePitchSource source = await poser(
        tester,
        juste(premiere.midi),
      );
      await demarrer(tester);

      source.emitAll();
      await tester.pump();

      expect(couleurDe(tester, premiere), TuningColors.inTune);
      await arreter(tester);
    });

    testWidgets('une note jouee trop bas passe au bleu, pas au rouge', (
      WidgetTester tester,
    ) async {
      // Le projet interdit la partition rouge : bas et haut disent une
      // direction, pas une faute.
      final FakePitchSource source = await poser(
        tester,
        <PitchEstimate>[
          for (int i = 0; i < 4; i++)
            PitchEstimate(
              // Un demi-ton sous la note attendue.
              frequencyHz: PitchUtils.midiToFrequency(premiere.midi - 1),
              confidence: 1,
              timestampMs: i * 46,
            ),
        ],
      );
      await demarrer(tester);

      source.emitAll();
      await tester.pump();

      expect(couleurDe(tester, premiere), TuningColors.low);
      expect(couleurDe(tester, premiere), isNot(Colors.red));
      await arreter(tester);
    });

    testWidgets('la legende n apparait que pendant l ecoute', (
      WidgetTester tester,
    ) async {
      await poser(tester, const <PitchEstimate>[]);
      expect(find.text('juste'), findsNothing);

      await demarrer(tester);
      expect(find.text('juste'), findsOneWidget);
      expect(find.text('bas'), findsOneWidget);
      expect(find.text('haut'), findsOneWidget);

      await arreter(tester);
      expect(find.text('juste'), findsNothing);
    });

    testWidgets('un micro refuse laisse le passage defiler', (
      WidgetTester tester,
    ) async {
      // Refuser le micro ne doit pas empecher de travailler son passage :
      // le curseur avance, seule la notation manque.
      await tester.pumpWidget(
        MaterialApp(
          home: SessionScreen(
            passage: demo,
            onChangePassage: () {},
            onTune: () {},
            pitchSourceFactory: () async => throw const MicPermissionDenied(),
          ),
        ),
      );
      await demarrer(tester);

      expect(find.textContaining('Micro refuse'), findsOneWidget);
      expect(find.text('Arreter'), findsOneWidget,
          reason: 'ca tourne quand meme');

      await arreter(tester);
    });

    testWidgets('un micro casse est distingue d un micro refuse', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionScreen(
            passage: demo,
            onChangePassage: () {},
            onTune: () {},
            pitchSourceFactory: () async => throw StateError('pas de micro'),
          ),
        ),
      );
      await demarrer(tester);

      expect(find.textContaining('Micro indisponible'), findsOneWidget);
      await arreter(tester);
    });

    testWidgets('recommencer efface les couleurs du passage precedent', (
      WidgetTester tester,
    ) async {
      // Une erreur ne doit jamais rester affichee au tour suivant : c'est la
      // regle "une erreur ne remet jamais un compteur a zero" vue a l'envers.
      final FakePitchSource source = await poser(
        tester,
        juste(premiere.midi),
      );
      await demarrer(tester);
      source.emitAll();
      await tester.pump();
      expect(couleurDe(tester, premiere), isNotNull);

      await arreter(tester);
      await demarrer(tester);

      expect(couleurDe(tester, premiere), isNull);
      await arreter(tester);
    });

    testWidgets('arreter libere vraiment le micro', (
      WidgetTester tester,
    ) async {
      final FakePitchSource source = await poser(tester, juste(premiere.midi));
      await demarrer(tester);
      await arreter(tester);

      // Un flux ferme refuse toute nouvelle emission. C'est la preuve que la
      // source a ete liberee et pas seulement oubliee : sur l'appareil, une
      // source oubliee laisserait le micro ouvert apres la seance.
      expect(source.emitAll, throwsStateError);
    });
  });

  group('SessionScreen, affichage de la partition', () {
    /// Huit mesures : de quoi deborder l'ecran en mode defilement. Le passage
    /// de demonstration, lui, n'en fait que deux et tient tout entier.
    Passage passageLong() {
      final PassageBuilder b = PassageBuilder(beatsPerMeasure: 2);
      for (int i = 0; i < 16; i++) {
        b.add(67, NoteValue.quarter);
      }
      return b.build();
    }

    Future<void> poserEcran(WidgetTester tester, {Passage? passage}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionScreen(
            passage: passage ?? demo,
            onChangePassage: () {},
            onTune: () {},
            pitchSourceFactory: () async =>
                FakePitchSource(const <PitchEstimate>[]),
          ),
        ),
      );
    }

    ScoreView vue(WidgetTester tester) =>
        tester.widget<ScoreView>(find.byType(ScoreView));

    testWidgets('la partition passe a la ligne par defaut', (
      WidgetTester tester,
    ) async {
      await poserEcran(tester);
      expect(vue(tester).mode, ScoreDisplayMode.systems);
      expect(vue(tester).zoom, 1);
    });

    testWidgets('un bouton bascule vers le defilement et revient', (
      WidgetTester tester,
    ) async {
      await poserEcran(tester);
      await tester.tap(find.byTooltip('Passer au defilement'));
      await tester.pump();
      expect(vue(tester).mode, ScoreDisplayMode.scrolling);

      await tester.tap(find.byTooltip('Passer a plusieurs lignes'));
      await tester.pump();
      expect(vue(tester).mode, ScoreDisplayMode.systems);
    });

    testWidgets('pincer agrandit la partition', (WidgetTester tester) async {
      await poserEcran(tester);
      final Offset centre = tester.getCenter(find.byType(ScoreView));

      final TestGesture doigt1 =
          await tester.startGesture(centre - const Offset(20, 0));
      final TestGesture doigt2 =
          await tester.startGesture(centre + const Offset(20, 0));
      await doigt1.moveBy(const Offset(-40, 0));
      await doigt2.moveBy(const Offset(40, 0));
      await tester.pump();
      await doigt1.up();
      await doigt2.up();
      await tester.pump();

      expect(vue(tester).zoom, greaterThan(1));
    });

    testWidgets('pincer a l envers reduit la partition', (
      WidgetTester tester,
    ) async {
      await poserEcran(tester);
      final Offset centre = tester.getCenter(find.byType(ScoreView));

      final TestGesture doigt1 =
          await tester.startGesture(centre - const Offset(60, 0));
      final TestGesture doigt2 =
          await tester.startGesture(centre + const Offset(60, 0));
      await doigt1.moveBy(const Offset(40, 0));
      await doigt2.moveBy(const Offset(-40, 0));
      await tester.pump();
      await doigt1.up();
      await doigt2.up();
      await tester.pump();

      expect(vue(tester).zoom, lessThan(1));
    });

    testWidgets('deux pincements de suite s enchainent sans exploser', (
      WidgetTester tester,
    ) async {
      // Le piege : repartir de 1 a chaque image multiplierait le zoom par le
      // facteur du geste a chaque trame, et la partition disparaitrait.
      await poserEcran(tester);
      final Offset centre = tester.getCenter(find.byType(ScoreView));

      for (int i = 0; i < 2; i++) {
        final TestGesture d1 =
            await tester.startGesture(centre - const Offset(20, 0));
        final TestGesture d2 =
            await tester.startGesture(centre + const Offset(20, 0));
        await d1.moveBy(const Offset(-10, 0));
        await d2.moveBy(const Offset(10, 0));
        await tester.pump();
        await d1.up();
        await d2.up();
        await tester.pump();
      }

      expect(vue(tester).zoom, greaterThan(1));
      expect(vue(tester).zoom, lessThanOrEqualTo(ScoreView.maxZoom));
    });

    testWidgets('en defilement, un doigt fait toujours glisser la partition', (
      WidgetTester tester,
    ) async {
      // Le zoom ne doit pas confisquer le geste a un doigt : sans defilement,
      // le mode defilement ne servirait a rien.
      await poserEcran(tester, passage: passageLong());
      await tester.tap(find.byTooltip('Passer au defilement'));
      await tester.pump();

      // La partition est doublement defilante : la premiere glissiere est la
      // verticale, qui enveloppe l'horizontale. C'est la seconde qu'on veut.
      final Finder glissiere = find
          .descendant(
            of: find.byType(ScoreView),
            matching: find.byType(Scrollable),
          )
          .last;
      final ScrollableState avant = tester.state<ScrollableState>(glissiere);
      final double depart = avant.position.pixels;

      await tester.drag(find.byType(ScoreView), const Offset(-120, 0));
      await tester.pump();

      expect(
        tester.state<ScrollableState>(glissiere).position.pixels,
        greaterThan(depart),
      );
    });
  });

  group('mode paysage', () {
    /// Un telephone couche : beaucoup de largeur, peu de hauteur.
    const Size paysage = Size(780, 360);
    const Size portrait = Size(360, 780);

    Future<void> poser(WidgetTester tester, Size ecran) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = ecran;
      await tester.pumpWidget(
        MaterialApp(
          home: SessionScreen(
            passage: demo,
            onChangePassage: () {},
            onTune: () {},
            pitchSourceFactory: () async =>
                FakePitchSource(const <PitchEstimate>[]),
          ),
        ),
      );
    }

    test('le plafond de systemes depend de l orientation', () {
      // En portrait la hauteur est abondante ; en paysage c'est la largeur.
      expect(maxSystemsFor(Orientation.portrait), 4);
      expect(maxSystemsFor(Orientation.landscape), 2);
    });

    testWidgets('en paysage, les commandes passent sur le cote', (
      WidgetTester tester,
    ) async {
      // Empilees comme en portrait, elles ne laisseraient pas de quoi
      // afficher deux systemes -- ce qui est justement l'interet de tourner
      // l'ecran.
      await poser(tester, paysage);
      final double basDeLaPartition =
          tester.getBottomLeft(find.byType(ScoreView)).dy;
      final double hautDuBouton =
          tester.getTopLeft(find.byType(FilledButton)).dy;
      expect(
        basDeLaPartition,
        greaterThan(hautDuBouton),
        reason: 'la partition descend plus bas que le bouton',
      );
    });

    testWidgets('en portrait, les commandes restent sous la partition', (
      WidgetTester tester,
    ) async {
      await poser(tester, portrait);
      final double basDeLaPartition =
          tester.getBottomLeft(find.byType(ScoreView)).dy;
      final double hautDuBouton =
          tester.getTopLeft(find.byType(FilledButton)).dy;
      expect(basDeLaPartition, lessThanOrEqualTo(hautDuBouton));
    });

    testWidgets('en paysage, la partition est plus haute qu en portrait', (
      WidgetTester tester,
    ) async {
      // Malgre un ecran deux fois moins haut : c'est le signe que la
      // disposition en ligne rend bien sa hauteur a la portee.
      await poser(tester, portrait);
      final double enPortrait = tester.getSize(find.byType(ScoreView)).height;
      await poser(tester, paysage);
      final double enPaysage = tester.getSize(find.byType(ScoreView)).height;

      expect(enPaysage / 360, greaterThan(enPortrait / 780));
    });

    testWidgets('rien ne deborde en paysage', (WidgetTester tester) async {
      // Un debordement de rendu fait echouer ce test tout seul.
      await poser(tester, paysage);
      expect(tester.takeException(), isNull);
      final double basDuContenu =
          tester.getBottomLeft(find.byKey(const Key('session-content'))).dy;
      expect(basDuContenu, lessThanOrEqualTo(360));
    });

    testWidgets('rien ne deborde en paysage pendant l ecoute', (
      WidgetTester tester,
    ) async {
      // C'est l'etat le plus charge : la legende s'ajoute aux commandes.
      await poser(tester, paysage);
      await tester.tap(find.text('Jouer le passage'));
      await tester.pump();
      await tester.pump();
      expect(find.text('juste'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Arreter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
    });
  });
}
