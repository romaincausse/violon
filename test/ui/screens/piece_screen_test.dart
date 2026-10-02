import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/import/imported_piece.dart';
import 'package:violon/core/import/musicxml_reader.dart';
import 'package:violon/core/store/measure_heat.dart';
import 'package:violon/core/store/take_history.dart';
import 'package:violon/ui/screens/piece_screen.dart';
import 'package:violon/ui/widgets/score_view.dart';

import '../../core/import/musicxml_fixtures.dart';

/// Douze mesures de la en 6/8, la cinquieme en silence.
ImportedPiece douzeMesures({String extraEntete = ''}) => MusicXmlReader.read(
      partition(
        <String>[
          for (int m = 1; m <= 12; m++)
            '<measure number="$m">${m == 1 ? sixHuit : ''}'
                '${m == 5 ? silence(6) : note('A4', 6)}</measure>',
        ].join(),
        parties: extraEntete,
      ),
    );

void main() {
  PieceAction? rendu;

  Future<void> ouvrir(
    WidgetTester tester,
    ImportedPiece piece, {
    int? de,
    int? a,
    MeasureHeat? chaleur,
  }) async {
    rendu = null;
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                rendu = await Navigator.of(context).push<PieceAction>(
                  MaterialPageRoute<PieceAction>(
                    builder: (BuildContext c) => PieceScreen(
                      piece: piece,
                      initialFrom: de,
                      initialTo: a,
                      heat: chaleur,
                    ),
                  ),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  group('PieceScreen', () {
    testWidgets('propose huit mesures, gravees, et les rend', (
      WidgetTester tester,
    ) async {
      await ouvrir(tester, douzeMesures());
      expect(find.text('Mesures 1 a 8'), findsOneWidget);
      expect(find.byType(ScoreView), findsOneWidget);
      await tester.tap(find.byKey(PieceScreen.travaillerKey));
      await tester.pumpAndSettle();
      expect(rendu, isA<WorkBars>());
      expect((rendu! as WorkBars).from, 1);
      expect((rendu! as WorkBars).to, 8);
    });

    testWidgets('rouvre sur les mesures de la derniere fois', (
      WidgetTester tester,
    ) async {
      await ouvrir(tester, douzeMesures(), de: 3, a: 6);
      expect(find.text('Mesures 3 a 6'), findsOneWidget);
    });

    testWidgets('des mesures de silence seules ne se travaillent pas', (
      WidgetTester tester,
    ) async {
      await ouvrir(tester, douzeMesures(), de: 5, a: 5);
      expect(find.text('Que des silences : rien a jouer ici.'), findsOneWidget);
      final FilledButton bouton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Travailler ces mesures'),
          matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
        ),
      );
      expect(bouton.onPressed, isNull);
    });

    testWidgets('la carte de chaleur mene aux mesures qui coincent', (
      WidgetTester tester,
    ) async {
      final ImportedPiece piece = douzeMesures();
      final DateTime maintenant = DateTime(2026, 10, 20);
      final TakeHistory h = TakeHistory.vide.withTake(
        TakeRecord(
          atMs: maintenant.millisecondsSinceEpoch,
          key: 'piece:${piece.id}:7-12',
          title: piece.title,
          fromMeasure: 7,
          toMeasure: 12,
          writtenPulseBpm: 94,
          durationMs: 30000,
          measures: const <MeasureTrace>[
            MeasureTrace(measure: 9, difficulty: 50),
            MeasureTrace(measure: 10, difficulty: 60),
            MeasureTrace(measure: 11, difficulty: 4),
          ],
        ),
      );
      await ouvrir(
        tester,
        piece,
        chaleur: MeasureHeat.of(h, piece.id, maintenant),
      );
      expect(find.byKey(PieceScreen.chaleurKey), findsOneWidget);
      expect(find.text('La ou ca coince : mesures 9 et 10'), findsOneWidget);
      await tester.tap(find.byKey(PieceScreen.chaudesKey));
      await tester.pump();
      expect(find.text('Mesures 9 a 10'), findsOneWidget);
    });

    testWidgets('un morceau jamais travaille n a pas de carte', (
      WidgetTester tester,
    ) async {
      await ouvrir(tester, douzeMesures());
      expect(find.byKey(PieceScreen.chaleurKey), findsNothing);
    });

    testWidgets('retirer demande confirmation', (WidgetTester tester) async {
      await ouvrir(tester, douzeMesures());
      await tester.tap(find.byKey(PieceScreen.retirerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle();
      expect(rendu, isNull);
      expect(find.byType(PieceScreen), findsOneWidget);

      await tester.tap(find.byKey(PieceScreen.retirerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();
      expect(rendu, isA<RemovePiece>());
    });

    testWidgets('ce que l import a simplifie est dit', (
      WidgetTester tester,
    ) async {
      await ouvrir(
        tester,
        douzeMesures(
          extraEntete: '<part id="P2"><measure number="1">$sixHuit'
              '${note('D3', 6)}</measure></part>',
        ),
      );
      expect(find.text('Ce que l import a simplifie'), findsOneWidget);
      expect(find.textContaining('"Violon" est suivie'), findsOneWidget);
    });
  });
}
