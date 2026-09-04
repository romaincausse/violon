import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/microphone_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';

import 'package:violon/core/music/demo_passage.dart';
import 'package:violon/core/music/passage.dart';
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
}
