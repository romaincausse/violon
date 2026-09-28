import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/exercises/note_by_note.dart';
import 'package:violon/core/music/finger_pattern.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/ui/screens/note_by_note_screen.dart';
import 'package:violon/ui/widgets/fingerboard_view.dart';

void main() {
  final MotifExercise motif =
      ExerciseCatalog.byId('motif-en-ligne-2-3')! as MotifExercise;
  final NoteByNote reference = NoteByNote(placements: motif.placements);

  late FakePitchSource micro;

  Future<void> poser(WidgetTester tester) async {
    micro = FakePitchSource(const <PitchEstimate>[]);
    await tester.pumpWidget(
      MaterialApp(
        home: NoteByNoteScreen(
          exercise: motif,
          pitchSourceFactory: () async => micro,
        ),
      ),
    );
    // Deux images : l'ouverture du micro est asynchrone, l'ecran ne l'attend
    // pas pour s'afficher.
    await tester.pump();
    await tester.pump();
  }

  /// Fait entendre [midi] assez longtemps pour valider une note.
  Future<void> jouer(WidgetTester tester, int midi) async {
    for (int i = 0; i < reference.confirmations; i++) {
      micro.emit(
        PitchEstimate(
          frequencyHz: PitchUtils.midiToFrequency(midi),
          confidence: 1,
          timestampMs: i * 46,
        ),
      );
    }
    await tester.pump();
  }

  String noteAffichee(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(NoteByNoteScreen.noteKey)).data!;

  group('NoteByNoteScreen', () {
    testWidgets('elle attend la premiere note, sans montrer le doigt', (
      WidgetTester tester,
    ) async {
      // **Chercher sa note fait partie de l'exercice.** La donner d'emblee le
      // viderait de son sens.
      await poser(tester);
      expect(noteAffichee(tester),
          PitchUtils.noteName(motif.placements.first.midi));
      expect(find.text('Cherche la note.'), findsOneWidget);
      expect(
        tester.widget<FingerboardView>(find.byType(FingerboardView)).target,
        isNull,
      );
    });

    testWidgets('la bonne note fait avancer', (WidgetTester tester) async {
      await poser(tester);
      await jouer(tester, motif.placements.first.midi);
      expect(
        noteAffichee(tester),
        PitchUtils.noteName(motif.placements[1].midi),
      );
      expect(find.text('2 sur ${motif.placements.length}'), findsOneWidget);
    });

    testWidgets('la mauvaise note ne fait rien avancer', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      // Une note a un ton de la bonne, jouee longtemps.
      for (int i = 0; i < 10; i++) {
        await jouer(tester, motif.placements.first.midi + 2);
      }
      expect(find.text('1 sur ${motif.placements.length}'), findsOneWidget);
    });

    testWidgets('apres quelques secondes, le doigt s affiche', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await tester.pump(reference.helpAfter);

      final FingerPlacement? cible =
          tester.widget<FingerboardView>(find.byType(FingerboardView)).target;
      expect(cible?.midi, motif.placements.first.midi);
      // Et il est aussi dit en toutes lettres : un schema se regarde, une
      // phrase s'entend dans la tete.
      expect(find.textContaining('corde de'), findsOneWidget);
    });

    testWidgets('puis on passe, sans avoir rien a demander', (
      WidgetTester tester,
    ) async {
      // **Bloquer oui, impasse non.** Un enfant coince n'a plus de prochaine
      // tache, il a un mur.
      await poser(tester);
      await tester.pump(reference.skipAfter);
      expect(
        noteAffichee(tester),
        PitchUtils.noteName(motif.placements[1].midi),
      );
      // L'aide repart de zero sur la nouvelle note.
      expect(
        tester.widget<FingerboardView>(find.byType(FingerboardView)).target,
        isNull,
      );
    });

    testWidgets('le motif fini, le bilan designe une seule chose', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      for (int i = 0; i < motif.placements.length; i++) {
        await jouer(tester, motif.placements[i].midi);
      }
      expect(find.byKey(NoteByNoteScreen.bilanKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(NoteByNoteScreen.bilanKey)).data,
        '${motif.placements.length} notes sur ${motif.placements.length}',
      );
      expect(find.text('Tout y etait.'), findsOneWidget);
    });

    testWidgets('une note manquee revient comme prochaine tache', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      // On laisse passer la premiere, on joue toutes les autres.
      await tester.pump(reference.skipAfter);
      for (int i = 1; i < motif.placements.length; i++) {
        await jouer(tester, motif.placements[i].midi);
      }
      expect(find.byKey(NoteByNoteScreen.bilanKey), findsOneWidget);
      expect(find.textContaining('A retravailler'), findsOneWidget);
    });

    testWidgets('recommencer repart a zero', (WidgetTester tester) async {
      await poser(tester);
      for (int i = 0; i < motif.placements.length; i++) {
        await jouer(tester, motif.placements[i].midi);
      }
      await tester.tap(find.byKey(NoteByNoteScreen.recommencerKey));
      await tester.pump();
      expect(find.byKey(NoteByNoteScreen.bilanKey), findsNothing);
      expect(find.text('1 sur ${motif.placements.length}'), findsOneWidget);
    });

    testWidgets('sans micro, l exercice avance quand meme', (
      WidgetTester tester,
    ) async {
      // Mieux vaut un exercice qui defile qu'un mur : l'horloge ne depend pas
      // du micro.
      await tester.pumpWidget(
        MaterialApp(
          home: NoteByNoteScreen(
            exercise: motif,
            pitchSourceFactory: () async => throw StateError('pas de micro'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(reference.skipAfter);
      expect(find.text('2 sur ${motif.placements.length}'), findsOneWidget);
    });

    testWidgets('rien ne deborde, dans les deux orientations', (
      WidgetTester tester,
    ) async {
      for (final Size taille in <Size>[
        const Size(360, 780),
        const Size(780, 360),
      ]) {
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = taille;
        await poser(tester);
        await tester.pump(reference.helpAfter);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
