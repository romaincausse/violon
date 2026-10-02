import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/document_saver.dart';
import 'package:violon/core/store/take_history.dart';
import 'package:violon/ui/screens/week_report_screen.dart';

void main() {
  final DateTime maintenant = DateTime(2026, 10, 9, 19);

  TakeHistory semaine() {
    TakeHistory h = TakeHistory.vide;
    for (int i = 0; i < 3; i++) {
      h = h.withTake(TakeRecord(
        atMs: maintenant.subtract(Duration(days: i)).millisecondsSinceEpoch,
        key: 'piece:stars:8-12',
        title: 'Into the Stars',
        fromMeasure: 8,
        toMeasure: 12,
        writtenPulseBpm: 94,
        durationMs: 300000,
        heldPulseBpm: 60 + i,
        tuningScore: 82,
        rhythmScore: 88,
        reachedEnd: true,
        measures: const <MeasureTrace>[
          MeasureTrace(measure: 10, difficulty: 50, restarts: 5),
        ],
      ));
    }
    return h;
  }

  Future<void> poser(
    WidgetTester tester,
    TakeHistory h, {
    DocumentSaver? saver,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: WeekReportScreen(
          history: h,
          saver: saver,
          clock: () => maintenant,
        ),
      ),
    );
  }

  testWidgets('la semaine se lit comme un progres', (
    WidgetTester tester,
  ) async {
    await poser(tester, semaine());
    expect(find.text('3 jours de travail, 15 min d archet'), findsOneWidget);
    expect(find.text('Into the Stars'), findsOneWidget);
    expect(find.textContaining('mesure 10 : reprise 15 fois'), findsOneWidget);
  });

  testWidgets('copier met le rapport dans le presse-papiers', (
    WidgetTester tester,
  ) async {
    String? copie;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall appel) async {
        if (appel.method == 'Clipboard.setData') {
          copie = (appel.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await poser(tester, semaine());
    await tester.tap(find.byKey(WeekReportScreen.copierKey));
    await tester.pump();
    expect(copie, contains('Ma semaine de violon'));
    expect(copie, contains('Into the Stars'));
    expect(find.text('Rapport copie.'), findsOneWidget);
  });

  testWidgets('enregistrer range un fichier texte, la ou il le choisit', (
    WidgetTester tester,
  ) async {
    final FakeDocumentSaver saver = FakeDocumentSaver();
    await poser(tester, semaine(), saver: saver);
    await tester.tap(find.byKey(WeekReportScreen.enregistrerKey));
    await tester.pump();
    expect(saver.saved.single.$1, 'violon-semaine-2026-10-09.txt');
    expect(utf8.decode(saver.saved.single.$2), contains('Into the Stars'));
    expect(find.text('Rapport enregistre.'), findsOneWidget);
  });

  testWidgets('une semaine vide le dit simplement', (
    WidgetTester tester,
  ) async {
    await poser(tester, TakeHistory.vide);
    expect(
        find.text('Pas encore de prise suivie cette semaine.'), findsOneWidget);
    expect(find.byKey(WeekReportScreen.enregistrerKey), findsNothing);
  });
}
