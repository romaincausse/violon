import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/take_history.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_source.dart';
import 'package:violon/core/import/piece_importer.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/core/store/piece_store.dart';
import 'package:violon/core/store/session_store.dart';
import 'package:violon/main.dart';
import 'package:violon/ui/screens/home_shell.dart';
import 'package:violon/ui/screens/piece_screen.dart';
import 'package:violon/ui/screens/session_screen.dart';

import '../../core/import/musicxml_fixtures.dart';

Future<PitchSource> micMuet() async => FakePitchSource(const <PitchEstimate>[]);

final String gavotte = partition(
  <String>[
    for (int m = 1; m <= 16; m++)
      '<measure number="$m">${m == 1 ? sixHuit : ''}'
          '${note('A4', 3)}${note('B4', 3)}</measure>',
  ].join(),
  entete: '<work><work-title>Gavotte</work-title></work>',
);

late FakeSessionStore memoire;
late FakePieceStore morceaux;
late FakeDocumentPicker selecteur;

Future<void> poser(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ViolonApp(
      pitchSourceFactory: micMuet,
      audioEngineFactory: FakeAudioEngine.new,
      sessionStoreFactory: () => memoire,
      pieceStoreFactory: () => morceaux,
      historyStoreFactory: FakeHistoryStore.new,
      documentPickerFactory: () => selecteur,
      pieceImporter: const PieceImporter(inflate: _pasDArchive),
    ),
  );
  await tester.pump();
  await tester.pump();
}

List<int> _pasDArchive(List<int> _) => throw UnsupportedError('pas de zip');

Future<void> allerAuRepertoire(WidgetTester tester) async {
  await tester.tap(find.text('Repertoire'));
  await tester.pumpAndSettle();
}

Future<void> importer(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byKey(HomeShell.importerKey), 100);
  await tester.tap(find.byKey(HomeShell.importerKey));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    memoire = FakeSessionStore();
    morceaux = FakePieceStore();
    selecteur = FakeDocumentPicker(
      PickedDocument(
        name: 'gavotte.musicxml',
        bytes: Uint8List.fromList(utf8.encode(gavotte)),
      ),
    );
  });

  group('importer un morceau', () {
    testWidgets('du fichier aux mesures travaillees, et le lendemain', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await allerAuRepertoire(tester);
      await importer(tester);

      // Le morceau est range, et s'ouvre aussitot sur ses mesures.
      expect(morceaux.current.pieces.single.title, 'Gavotte');
      expect(find.byType(PieceScreen), findsOneWidget);
      expect(find.text('Mesures 1 a 8'), findsOneWidget);

      await tester.tap(find.byKey(PieceScreen.travaillerKey));
      await tester.pumpAndSettle();
      expect(find.byType(SessionScreen), findsOneWidget);
      expect(find.text('Gavotte - mesures 1 a 8'), findsWidgets);
      expect(memoire.current.excerpt?.toMeasure, 8);
      expect(memoire.current.exerciseId, isNull);

      // Le lendemain : l'application rouvre sur ces mesures-la.
      await tester.pumpWidget(const SizedBox.shrink());
      await poser(tester);
      expect(find.text('Gavotte - mesures 1 a 8'), findsWidgets);
    });

    testWidgets('on ralentit sur l ecran Jouer, et on le retrouve demain', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await allerAuRepertoire(tester);
      await importer(tester);
      await tester.tap(find.byKey(PieceScreen.travaillerKey));
      await tester.pumpAndSettle();

      // Sans tempo dans le fichier : noire = 80, soit noire pointee = 53.
      expect(find.text('noire pointee = 53'), findsOneWidget);
      await tester.tap(find.byKey(SessionScreen.tempoKey));
      await tester.pumpAndSettle();
      expect(find.text('C est le tempo ecrit.'), findsOneWidget);
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Plus lent'));
        await tester.pump();
      }
      expect(find.text('Tempo ecrit : 53'), findsOneWidget);
      await tester.tap(find.text('Jouer a noire pointee = 45'));
      await tester.pumpAndSettle();
      expect(find.text('noire pointee = 45'), findsOneWidget);
      expect(memoire.current.excerpt?.tempoBpm, 68);

      // Le lendemain, au tempo de travail.
      await tester.pumpWidget(const SizedBox.shrink());
      await poser(tester);
      expect(find.text('noire pointee = 45'), findsOneWidget);

      // Et on revient au tempo ecrit d'un appui.
      await tester.tap(find.byKey(SessionScreen.tempoKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revenir au tempo ecrit (53)'));
      await tester.pump();
      await tester.tap(find.text('Jouer a noire pointee = 53'));
      await tester.pumpAndSettle();
      expect(find.text('noire pointee = 53'), findsOneWidget);
      expect(memoire.current.excerpt?.tempoBpm, isNull);
    });

    testWidgets('le morceau reste au repertoire et se rouvre', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await allerAuRepertoire(tester);
      await importer(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Gavotte'), findsOneWidget);
      expect(find.text('16 mesures'), findsOneWidget);
      await tester.tap(find.text('Gavotte'));
      await tester.pumpAndSettle();
      expect(find.byType(PieceScreen), findsOneWidget);
    });

    testWidgets('un fichier illisible le dit, et ne range rien', (
      WidgetTester tester,
    ) async {
      selecteur.document = PickedDocument(
        name: 'photo.jpg',
        bytes: Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0]),
      );
      await poser(tester);
      await allerAuRepertoire(tester);
      await importer(tester);

      expect(find.byType(PieceScreen), findsNothing);
      expect(
        find.textContaining('n est pas une partition MusicXML'),
        findsOneWidget,
      );
      expect(morceaux.saves, 0);
    });

    testWidgets('renoncer au choix du fichier ne fait rien', (
      WidgetTester tester,
    ) async {
      selecteur.document = null;
      await poser(tester);
      await allerAuRepertoire(tester);
      await importer(tester);

      expect(selecteur.picks, 1);
      expect(find.byType(PieceScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('retirer le morceau travaille oublie le passage de demain', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await allerAuRepertoire(tester);
      await importer(tester);
      await tester.tap(find.byKey(PieceScreen.travaillerKey));
      await tester.pumpAndSettle();

      await allerAuRepertoire(tester);
      await tester.scrollUntilVisible(find.text('Gavotte'), 100);
      await tester.tap(find.text('Gavotte'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PieceScreen.retirerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      expect(morceaux.current.pieces, isEmpty);
      expect(memoire.current.excerpt, isNull);
    });
  });
}
