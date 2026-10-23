import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/exercises/echo_game.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/demo_passage.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/core/store/game_records.dart';
import 'package:violon/ui/screens/echo_screen.dart';
import 'package:violon/ui/screens/games_screen.dart';
import 'package:violon/ui/screens/long_tone_screen.dart';
import 'package:violon/ui/screens/pulse_screen.dart';

const List<int> pool = <int>[60, 62, 64, 65, 67, 69, 71, 72];

void main() {
  late FakePitchSource micro;
  late FakeAudioEngine moteur;

  Future<FakePitchSource> nouveauMicro() async =>
      micro = FakePitchSource(const <PitchEstimate>[]);

  /// Une hauteur tenue [ms] millisecondes, une estimation toutes les 20 ms.
  Future<void> tenir(WidgetTester tester, double midi, int de, int ms) async {
    for (int t = de; t < de + ms; t += 20) {
      // Le jeu a pu juger et refermer le micro avant la fin de la note.
      if (micro.disposed) {
        return;
      }
      micro.emit(PitchEstimate(
        frequencyHz: PitchUtils.midiToFrequency(midi),
        confidence: 1,
        timestampMs: t,
      ));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('GamesScreen', () {
    testWidgets('les records se lisent, et un nouveau record se range',
        (WidgetTester tester) async {
      final FakeGameStore store = FakeGameStore(const GameRecords(
        echoBest: 4,
        pulseBest: 70,
        evenBowBestMs: 5300,
      ));
      moteur = FakeAudioEngine();
      await tester.pumpWidget(MaterialApp(
        home: GamesScreen(
          passage: buildDemoPassage(),
          engine: moteur,
          pitchSourceFactory: nouveauMicro,
          store: store,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Record : 4 notes'), findsOneWidget);
      expect(find.text('Record : 70 sur 100'), findsOneWidget);
      expect(find.text('Record : 5.3 s'), findsOneWidget);
      expect(find.text('Pas encore de record'), findsOneWidget);

      // Une note tenue : le record se range des qu'il monte.
      await tester.tap(find.byKey(GamesScreen.tenueKey));
      await tester.pumpAndSettle();
      expect(find.byType(LongToneScreen), findsOneWidget);
    });
  });

  group('EchoScreen', () {
    testWidgets('elle joue le motif au violon, il le rejoue, il s allonge',
        (WidgetTester tester) async {
      moteur = FakeAudioEngine()..clock = const Duration(seconds: 5);
      int? record;
      await tester.pumpWidget(MaterialApp(
        home: EchoScreen(
          pool: pool,
          engine: moteur,
          pitchSourceFactory: nouveauMicro,
          seed: 7,
          onBest: (int n) => record = n,
        ),
      ));
      final List<int> motif = EchoGame(pool: pool, seed: 7).motif;
      expect(find.text('2 notes'), findsOneWidget);
      await tester.tap(find.byKey(EchoScreen.ecouterKey));
      await tester.pump();
      await tester.pump();
      expect(moteur.prepared, contains('violon'));
      expect(moteur.notes.map((FakeNote n) => n.instrument).toSet(),
          <String>{'violon'});
      expect(moteur.notes, hasLength(2));
      // La marge, deux notes, la queue : puis le micro s'ouvre.
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();
      expect(find.text('A toi.'), findsOneWidget);
      await tenir(tester, motif[0].toDouble(), 0, 400);
      await tenir(tester, motif[1].toDouble(), 400, 400);
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(EchoScreen.messageKey)).data,
        'C est ca : 2 notes. La suivante en a 3.',
      );
      expect(find.text('3 notes'), findsOneWidget);
      expect(record, 2);
      expect(micro.disposed, isTrue, reason: 'le micro se referme');
    });

    testWidgets('une erreur ne fait que raccourcir, jamais en dessous de deux',
        (WidgetTester tester) async {
      moteur = FakeAudioEngine();
      await tester.pumpWidget(MaterialApp(
        home: EchoScreen(
          pool: pool,
          engine: moteur,
          pitchSourceFactory: nouveauMicro,
          seed: 7,
        ),
      ));
      final List<int> motif = EchoGame(pool: pool, seed: 7).motif;
      await tester.tap(find.byKey(EchoScreen.ecouterKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();
      final int faux = motif[0] == 60 ? 62 : 60;
      await tenir(tester, motif[0].toDouble(), 0, 400);
      await tenir(tester, faux.toDouble(), 400, 400);
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(EchoScreen.messageKey)).data,
        'Les 1 premieres etaient justes. On reecoute, en 2 notes.',
      );
      expect(find.text('2 notes'), findsOneWidget);
    });
  });

  group('LongToneScreen', () {
    testWidgets('la tenue juste se compte, le record monte',
        (WidgetTester tester) async {
      int? record;
      await tester.pumpWidget(MaterialApp(
        home: LongToneScreen(
          notes: const <int>[69, 71, 72],
          pitchSourceFactory: nouveauMicro,
          onBest: (int ms) => record = ms,
        ),
      ));
      // La corde a vide n'est pas proposee : elle donne l'accord.
      expect(find.byKey(LongToneScreen.noteKey(69)), findsNothing);
      await tester.tap(find.byKey(LongToneScreen.commencerKey));
      await tester.pump();
      await tester.pump();
      await tenir(tester, 71.03, 0, 1500);
      expect(
        tester.widget<Text>(find.byKey(LongToneScreen.ecartKey)).data,
        '+3 cents',
      );
      expect(record, greaterThanOrEqualTo(1400));
      await tester.tap(find.byKey(LongToneScreen.commencerKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('Record : 1.'), findsOneWidget);
    });
  });

  group('LongToneScreen, cordes a vide', () {
    /// Un archet de [ms] a niveau constant, puis un silence : le juge du son
    /// rend son verdict.
    Future<void> archet(WidgetTester tester, int de, int ms) async {
      for (int t = de; t < de + ms + 200; t += 23) {
        final bool sonne = t < de + ms;
        micro.emitFeature(FeatureFrame(
          timeMs: t,
          midi: sonne ? 69 : null,
          rms: sonne ? 0.05 : 0.001,
          onset: t == de,
        ));
        await tester.pump(const Duration(milliseconds: 23));
      }
    }

    testWidgets('seul le son compte, et la minute finit sur la gamme',
        (WidgetTester tester) async {
      int? record;
      await tester.pumpWidget(MaterialApp(
        home: LongToneScreen(
          notes: const <int>[71],
          openStrings: true,
          budget: const Duration(seconds: 3),
          pitchSourceFactory: nouveauMicro,
          onEvenBowBest: (int ms) => record = ms,
        ),
      ));
      // Les quatre cordes, et pas d'ecart en cents : la corde donne l'accord.
      for (final int m in LongToneScreen.cordes) {
        expect(find.byKey(LongToneScreen.noteKey(m)), findsOneWidget);
      }
      expect(find.byKey(LongToneScreen.ecartKey), findsNothing);
      await tester.tap(find.byKey(LongToneScreen.commencerKey));
      await tester.pump();
      await tester.pump();
      await archet(tester, 0, 2000);
      expect(
        tester.widget<Text>(find.byKey(LongToneScreen.archetKey)).data,
        startsWith('Archet de 2.0 s, son egal'),
      );
      expect(record, greaterThanOrEqualTo(1900));
      expect(find.textContaining('Archet egal le plus long : 2.0 s'),
          findsOneWidget);
      // Le temps joue s'epuise : le micro se ferme, la gamme suit.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('La minute est faite.'), findsOneWidget);
      expect(find.text('Passer a la gamme'), findsOneWidget);
      expect(micro.disposed, isTrue);
    });
  });

  group('PulseScreen', () {
    testWidgets('quatre clics, puis huit temps joues seuls, et un score',
        (WidgetTester tester) async {
      moteur = FakeAudioEngine()..clock = const Duration(seconds: 2);
      int? record;
      await tester.pumpWidget(MaterialApp(
        home: PulseScreen(
          bpm: 100,
          engine: moteur,
          pitchSourceFactory: nouveauMicro,
          onBest: (int s) => record = s,
        ),
      ));
      await tester.tap(find.byKey(PulseScreen.jouerKey));
      await tester.pump();
      await tester.pump();
      expect(moteur.clicksAt.map((FakeClick c) => c.delay.inMilliseconds),
          <int>[2300, 2900, 3500, 4100]);
      // Le micro s'ouvre sur le dernier clic : la marge et trois temps.
      await tester.pump(const Duration(milliseconds: 2150));
      await tester.pump();
      expect(find.text('A toi : huit temps.'), findsOneWidget);
      for (int k = 0; k < 8; k++) {
        micro.emitFeature(FeatureFrame(
          timeMs: 600 + 600 * k,
          midi: 62,
          rms: 0.1,
          onset: true,
        ));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(PulseScreen.messageKey)).data,
        'Tu as tenu 100 pour 100 : pile au tempo. Regularite a 0 ms pres. '
        '100 sur 100.',
      );
      expect(record, 100);
    });
  });
}
