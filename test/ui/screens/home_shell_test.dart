import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_source.dart';
import 'package:violon/core/music/demo_passage.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/main.dart';
import 'package:violon/ui/screens/free_play_screen.dart';
import 'package:violon/ui/screens/home_shell.dart';
import 'package:violon/ui/screens/mic_check_screen.dart';
import 'package:violon/ui/screens/session_screen.dart';
import 'package:violon/ui/screens/tuner_screen.dart';

Future<PitchSource> micMuet() async => FakePitchSource(const <PitchEstimate>[]);

Future<void> poser(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const ViolonApp(pitchSourceFactory: micMuet));
  await tester.pump();
}

/// Ouvre le tiroir d'outils et laisse l'animation finir.
Future<void> ouvrirLesOutils(WidgetTester tester) async {
  await tester.tap(find.byKey(HomeShell.outilsKey));
  await tester.pumpAndSettle();
}

void main() {
  group('HomeShell', () {
    testWidgets('l application s ouvre sur le travail, pas sur un menu', (
      WidgetTester tester,
    ) async {
      // Dix secondes, c'est la duree au-dela de laquelle un enfant repose le
      // violon. Un ecran d'accueil couterait un appui par seance, tous les
      // soirs, pour une information qu'il connait deja.
      await poser(tester);
      expect(find.byType(SessionScreen), findsOneWidget);
      expect(find.text('Jouer le passage'), findsOneWidget);
    });

    testWidgets('le repertoire montre le passage en cours', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();

      expect(find.text(buildDemoPassage().title), findsOneWidget);
      expect(find.text('Saisir un passage'), findsOneWidget);
    });

    testWidgets('les outils s ouvrent par-dessus, sans changer d onglet', (
      WidgetTester tester,
    ) async {
      // Un onglet remplace l'ecran ; un outil se pose par-dessus. On prend
      // l'accordeur violon en main, au milieu d'une seance.
      await poser(tester);
      await ouvrirLesOutils(tester);

      expect(find.text('Accorder'), findsOneWidget);
      expect(find.text('Jouer librement'), findsOneWidget);
      expect(find.text('Est-ce qu elle m entend ?'), findsOneWidget);
      expect(find.byType(SessionScreen), findsOneWidget,
          reason: 'la seance est toujours la, dessous');
    });

    testWidgets('le tiroir mene a l accordeur', (WidgetTester tester) async {
      await poser(tester);
      await ouvrirLesOutils(tester);
      await tester.tap(find.text('Accorder'));
      await tester.pumpAndSettle();
      expect(find.byType(TunerScreen), findsOneWidget);
    });

    testWidgets('le tiroir mene au mode libre', (WidgetTester tester) async {
      await poser(tester);
      await ouvrirLesOutils(tester);
      await tester.tap(find.text('Jouer librement'));
      await tester.pumpAndSettle();
      expect(find.byType(FreePlayScreen), findsOneWidget);
      expect(find.text('Rien n est note ici.'), findsOneWidget);
    });

    testWidgets('le tiroir mene au controle du micro', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await ouvrirLesOutils(tester);
      await tester.tap(find.text('Est-ce qu elle m entend ?'));
      await tester.pumpAndSettle();
      expect(find.byType(MicCheckScreen), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(MicCheckScreen.sourceKey)).data,
        'source factice',
      );
    });

    testWidgets('accorder garde son raccourci depuis la seance', (
      WidgetTester tester,
    ) async {
      // C'est la premiere chose de chaque seance : elle merite un appui, pas
      // deux.
      await poser(tester);
      await tester.tap(find.byTooltip('Accorder'));
      await tester.pumpAndSettle();
      expect(find.byType(TunerScreen), findsOneWidget);
    });

    testWidgets('le diapason par defaut est annonce au repertoire', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await tester.tap(find.text('Repertoire'));
      await tester.pumpAndSettle();
      expect(
        find.text('Diapason : ${PitchUtils.defaultA4.round()} Hz (par defaut)'),
        findsOneWidget,
      );
    });
  });
}
