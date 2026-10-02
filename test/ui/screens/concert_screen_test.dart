import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/take_player.dart';
import 'package:violon/core/store/document_saver.dart';
import 'package:violon/core/store/take_sharer.dart';
import 'package:violon/ui/screens/concert_screen.dart';

/// Une seconde de la 440, bien au-dessus du seuil de silence.
Uint8List uneSecondeDeSon() {
  final Int16List s = Int16List(44100);
  for (int i = 0; i < s.length; i++) {
    s[i] = (0.3 * 32767 * math.sin(2 * math.pi * 440 * i / 44100)).round();
  }
  return s.buffer.asUint8List();
}

void main() {
  late FakePitchSource micro;
  late FakeTakePlayer liseur;
  late FakeTakeSharer partage;
  late FakeDocumentSaver rangement;

  Future<void> poser(WidgetTester tester) async {
    micro = FakePitchSource(const <PitchEstimate>[]);
    liseur = FakeTakePlayer();
    partage = FakeTakeSharer();
    rangement = FakeDocumentSaver();
    await tester.pumpWidget(
      MaterialApp(
        home: ConcertScreen(
          pitchSourceFactory: () async => micro,
          takePlayerFactory: () => liseur,
          sharer: partage,
          saver: rangement,
          title: 'Into the Stars',
          clock: () => DateTime(2026, 10, 2, 19, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> jouerUneSeconde(WidgetTester tester) async {
    await tester.tap(find.byKey(ConcertScreen.jouerKey));
    await tester.pump();
    micro.emitAudio(uneSecondeDeSon());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(ConcertScreen.jouerKey));
    await tester.pumpAndSettle();
  }

  group('ConcertScreen', () {
    testWidgets('il joue, c est fini, et il peut se reecouter',
        (WidgetTester tester) async {
      await poser(tester);
      expect(find.text('Quand tu veux.'), findsOneWidget);
      await jouerUneSeconde(tester);
      expect(find.textContaining('Ta prise : 0:01'), findsOneWidget);
      expect(micro.disposed, isTrue, reason: 'le micro se ferme avec la prise');

      await tester.tap(find.byKey(ConcertScreen.reecouterKey));
      await tester.pump();
      expect(liseur.joues, hasLength(1));
      expect(String.fromCharCodes(liseur.joues.single.sublist(0, 4)), 'RIFF');
      expect(find.text('Tu t ecoutes.'), findsOneWidget);
      liseur.terminer();
      await tester.pumpAndSettle();
      expect(find.textContaining('Ta prise'), findsOneWidget);
    });

    testWidgets('l envoyer passe par le partage, sous un nom lisible',
        (WidgetTester tester) async {
      await poser(tester);
      await jouerUneSeconde(tester);
      await tester.tap(find.byKey(ConcertScreen.envoyerKey));
      await tester.pumpAndSettle();
      expect(partage.shared, hasLength(1));
      expect(partage.shared.single.$1, 'concert-into-the-stars-2026-10-02.wav');
      expect(find.text('A toi de choisir a qui l envoyer.'), findsOneWidget);
    });

    testWidgets('la garder range un son, pas du texte',
        (WidgetTester tester) async {
      await poser(tester);
      await jouerUneSeconde(tester);
      await tester.tap(find.byKey(ConcertScreen.garderKey));
      await tester.pumpAndSettle();
      expect(rangement.saved, hasLength(1));
      expect(rangement.mimeTypes.single, 'audio/wav');
      expect(find.text('Rangee.'), findsOneWidget);
    });

    testWidgets('recommencer oublie la prise', (WidgetTester tester) async {
      await poser(tester);
      await jouerUneSeconde(tester);
      await tester.tap(find.byKey(ConcertScreen.recommencerKey));
      await tester.pumpAndSettle();
      expect(find.text('Quand tu veux.'), findsOneWidget);
      expect(find.byKey(ConcertScreen.envoyerKey), findsNothing);
    });

    testWidgets('sans son, rien a envoyer', (WidgetTester tester) async {
      await poser(tester);
      await tester.tap(find.byKey(ConcertScreen.jouerKey));
      await tester.pump();
      await tester.tap(find.byKey(ConcertScreen.jouerKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('Je n ai rien entendu'), findsOneWidget);
      expect(find.byKey(ConcertScreen.envoyerKey), findsNothing);
    });

    testWidgets('sans partage ni rangement, les boutons n existent pas',
        (WidgetTester tester) async {
      micro = FakePitchSource(const <PitchEstimate>[]);
      liseur = FakeTakePlayer();
      await tester.pumpWidget(
        MaterialApp(
          home: ConcertScreen(
            pitchSourceFactory: () async => micro,
            takePlayerFactory: () => liseur,
          ),
        ),
      );
      await jouerUneSeconde(tester);
      expect(find.byKey(ConcertScreen.envoyerKey), findsNothing);
      expect(find.byKey(ConcertScreen.garderKey), findsNothing);
      expect(find.byKey(ConcertScreen.reecouterKey), findsOneWidget);
    });
  });
}
