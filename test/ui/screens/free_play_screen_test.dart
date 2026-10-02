import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/audio/pitch_source.dart';
import 'package:violon/core/audio/take_player.dart';
import 'package:violon/ui/screens/free_play_screen.dart';

/// Une source factice qui compte ses ouvertures et ses fermetures.
///
/// C'est ce qui permet de defendre l'ADR-008 : pendant qu'on se reecoute, le
/// micro doit etre **ferme**, et rouvert apres.
class _SourceEspionnee implements PitchSource {
  _SourceEspionnee(this._vraie);

  final FakePitchSource _vraie;
  int demarrages = 0;
  int arrets = 0;

  bool get ouverte => demarrages > arrets;

  void emitAudio(Uint8List octets) => _vraie.emitAudio(octets);

  @override
  Stream<Uint8List> get audio => _vraie.audio;

  @override
  Stream<PitchEstimate> get pitches => _vraie.pitches;

  @override
  Stream<FeatureFrame> get features => _vraie.features;

  @override
  Stream<SmoothedPitch> get smoothedPitches => _vraie.smoothedPitches;

  @override
  String get sourceLabel => _vraie.sourceLabel;

  @override
  int get droppedFrames => _vraie.droppedFrames;

  @override
  int get latencyMs => _vraie.latencyMs;

  @override
  Future<void> start() async {
    demarrages++;
    await _vraie.start();
  }

  @override
  Future<void> stop() async {
    arrets++;
    await _vraie.stop();
  }

  @override
  Future<void> dispose() => _vraie.dispose();
}

/// Une seconde de sinus, assez fort pour ne pas passer pour du silence.
Uint8List son({int sampleRate = 44100, double secondes = 0.5}) {
  final int n = (sampleRate * secondes).round();
  final Int16List e = Int16List(n);
  for (int i = 0; i < n; i++) {
    e[i] = (math.sin(2 * math.pi * 440 * i / sampleRate) * 16000).round();
  }
  return Uint8List.view(e.buffer);
}

void main() {
  late _SourceEspionnee micro;
  late FakeTakePlayer liseur;

  Future<void> poser(WidgetTester tester) async {
    micro = _SourceEspionnee(FakePitchSource(const <PitchEstimate>[]));
    liseur = FakeTakePlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: FreePlayScreen(
          pitchSourceFactory: () async => micro,
          takePlayerFactory: () => liseur,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Le bouton de relecture, tel qu'il est a l'ecran.
  FilledButton bouton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(FreePlayScreen.reecouteKey));

  Future<void> jouer(WidgetTester tester) async {
    micro.emitAudio(son());
    await tester.pump();
    await tester.pump();
  }

  group('FreePlayScreen', () {
    testWidgets('sans rien avoir entendu, on ne peut pas se reecouter', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      expect(find.text('Se reecouter'), findsOneWidget);
      expect(bouton(tester).onPressed, isNull);
    });

    testWidgets('du silence ne reveille pas le bouton', (
      WidgetTester tester,
    ) async {
      // Le bruit d'une dalle posee sur un pupitre n'est pas une phrase a
      // reecouter.
      await poser(tester);
      micro.emitAudio(Uint8List(44100));
      await tester.pump();
      expect(bouton(tester).onPressed, isNull);
    });

    testWidgets('des qu on a joue, on peut s entendre', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await jouer(tester);
      expect(bouton(tester).onPressed, isNotNull);
    });

    testWidgets('se reecouter ferme le micro, puis le rouvre', (
      WidgetTester tester,
    ) async {
      // **L'ADR-008 a la lettre.** Laisser le micro ouvert pendant la
      // relecture lui ferait reentendre le haut-parleur, et le retour en
      // direct se mettrait a commenter l'application elle-meme.
      await poser(tester);
      await jouer(tester);
      expect(micro.ouverte, isTrue);

      await tester.tap(find.byKey(FreePlayScreen.reecouteKey));
      await tester.pump();
      expect(micro.ouverte, isFalse, reason: 'ferme pendant la relecture');
      expect(liseur.joues, hasLength(1));
      expect(find.text('tu t ecoutes'), findsOneWidget);

      liseur.terminer();
      await tester.pump();
      await tester.pump();
      expect(micro.ouverte, isTrue, reason: 'rouvert apres');
    });

    testWidgets('on peut couper la relecture en cours', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await jouer(tester);
      await tester.tap(find.byKey(FreePlayScreen.reecouteKey));
      await tester.pump();
      expect(find.text('Arreter'), findsOneWidget);

      await tester.tap(find.byKey(FreePlayScreen.reecouteKey));
      await tester.pump();
      await tester.pump();
      expect(liseur.arrets, 1);
      expect(find.text('Se reecouter'), findsOneWidget);
    });

    testWidgets('ce qu on vient d entendre n est plus a reecouter', (
      WidgetTester tester,
    ) async {
      // "Ce que tu viens de jouer" veut dire depuis la derniere ecoute :
      // sans cet oubli, la fois suivante rejouerait la precedente collee
      // devant.
      await poser(tester);
      await jouer(tester);
      await tester.tap(find.byKey(FreePlayScreen.reecouteKey));
      await tester.pump();
      liseur.terminer();
      await tester.pump();
      await tester.pump();

      expect(bouton(tester).onPressed, isNull);
    });

    testWidgets('quitter l ecran libere le liseur', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      expect(liseur.disposed, isTrue);
    });
  });
}
