import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/core/play/metronome_clock.dart';
import 'package:violon/ui/screens/metronome_screen.dart';

void main() {
  Future<FakeAudioEngine> poser(
    WidgetTester tester, {
    int tempoBpm = 60,
    Size taille = const Size(400, 800),
  }) async {
    final FakeAudioEngine moteur = FakeAudioEngine();
    await tester.binding.setSurfaceSize(taille);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MetronomeScreen(engine: moteur, tempoBpm: tempoBpm),
      ),
    );
    return moteur;
  }

  /// Demarre le metronome.
  ///
  /// `pumpAndSettle` est inutilisable ici : une fois lance, le metronome
  /// redessine a chaque image et l'arbre ne se stabilise jamais. On avance
  /// donc image par image -- deux suffisent, l'ouverture du moteur etant
  /// asynchrone.
  Future<void> faireSonner(WidgetTester tester) async {
    await tester.tap(find.byKey(MetronomeScreen.jouerKey));
    await tester.pump();
    await tester.pump();
  }

  group('MetronomeScreen', () {
    testWidgets('rien n est pose tant qu on n a pas demarre', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      expect(moteur.clicks, isEmpty);
      expect(find.text('Arrete'), findsOneWidget);
    });

    testWidgets('demarrer pose les pulsations d avance, avec leurs accents', (
      WidgetTester tester,
    ) async {
      // A soixante, une pulsation par seconde : la premiere tout de suite, la
      // suivante dans une seconde. Les deux sont posees avant d avoir sonne.
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);

      expect(moteur.clicks, hasLength(2));
      expect(moteur.clicks.first.delay, Duration.zero);
      expect(moteur.clicks.first.accent, PulseAccent.downbeat);
      expect(
        moteur.clicks[1].delay.inMilliseconds,
        closeTo(1000, 20),
      );
      expect(moteur.clicks[1].accent, PulseAccent.beat);
    });

    testWidgets('le temps qui passe pose la suite, sans rien repeter', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      final int avant = moteur.clicks.length;

      await tester.pump(const Duration(milliseconds: 1200));
      expect(moteur.clicks.length, greaterThan(avant));

      // Chaque pulsation n'est posee qu'une fois. Toutes ont ete demandees a
      // la meme image, donc deux delais egaux voudraient dire deux clics au
      // meme instant -- et un clic double s'entend autant qu'un clic manquant.
      final List<Duration> delais =
          moteur.clicks.skip(avant).map((FakeClick c) => c.delay).toList();
      expect(delais.toSet(), hasLength(delais.length));
    });

    testWidgets('le premier temps de chaque mesure est un downbeat', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      await tester.pump(const Duration(milliseconds: 3600));

      final List<PulseAccent> accents =
          moteur.clicks.map((FakeClick c) => c.accent).toList();
      expect(accents.first, PulseAccent.downbeat);
      // Quatre temps par mesure : le cinquieme clic repart sur un downbeat.
      expect(accents.length, greaterThan(4));
      expect(accents[4], PulseAccent.downbeat);
      expect(accents[1], PulseAccent.beat);
    });

    testWidgets('les croches ajoutent des subdivisions', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      await tester.tap(find.byKey(MetronomeScreen.subdivisionKey(2)));
      await tester.pumpAndSettle();
      await faireSonner(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        moteur.clicks.map((FakeClick c) => c.accent),
        contains(PulseAccent.subdivision),
      );
    });

    testWidgets('changer de tempo repart de zero', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      await tester.pump(const Duration(milliseconds: 2000));

      await tester.drag(
        find.byKey(MetronomeScreen.tempoKey),
        const Offset(120, 0),
      );
      await tester.pump();
      await tester.pump();

      // Tout ce qui etait planifie a ete annule, et on repart sur un premier
      // temps : sinon le changement de tempo laisserait sonner l ancien.
      expect(moteur.stopAlls, greaterThan(0));
      expect(moteur.clicks.first.accent, PulseAccent.downbeat);
      expect(moteur.clicks.first.delay, Duration.zero);
    });

    testWidgets('arreter annule ce qui etait deja planifie', (
      WidgetTester tester,
    ) async {
      // Sans ca, la seconde et demie posee d avance continue de sonner apres
      // l arret.
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      expect(moteur.clicks, isNotEmpty);

      await tester.tap(find.byKey(MetronomeScreen.jouerKey));
      await tester.pump();
      expect(moteur.clicks, isEmpty);
      expect(find.text('Arrete'), findsOneWidget);
    });

    testWidgets('quitter l ecran coupe le metronome', (
      WidgetTester tester,
    ) async {
      final FakeAudioEngine moteur = await poser(tester);
      await faireSonner(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      expect(moteur.clicks, isEmpty);
      expect(moteur.stopAlls, greaterThan(0));
    });

    testWidgets('rien ne deborde en paysage', (WidgetTester tester) async {
      await poser(tester, taille: const Size(800, 400));
      expect(tester.takeException(), isNull);
    });
  });
}
