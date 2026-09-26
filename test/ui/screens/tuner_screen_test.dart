import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/microphone_pitch_source.dart';
import 'package:violon/core/audio/pitch_source.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/tuner.dart';
import 'package:violon/ui/screens/tuner_screen.dart';
import 'package:violon/ui/widgets/tuner_gauge.dart';
import 'package:violon/ui/widgets/tuning_colors.dart';

import '../../core/audio/fake_capture.dart';

/// La phrase affichee a l'enfant.
String consigne(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('tuner-consigne'))).data!;

void main() {
  /// Un signal PCM d'une hauteur donnee, assez long pour plusieurs trames.
  Uint8ListBuilder sinus(double frequenceHz, int trames) =>
      Uint8ListBuilder(frequenceHz, trames);

  Future<FakeCapture> poser(
    WidgetTester tester, {
    double a4 = 440,
    ValueChanged<double>? onA4Changed,
  }) async {
    final FakeCapture micro = FakeCapture();
    await tester.pumpWidget(
      MaterialApp(
        home: TunerScreen(
          pitchSourceFactory: () async =>
              MicrophonePitchSource(micro) as PitchSource,
          a4: a4,
          onA4Changed: onA4Changed ?? (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return micro;
  }

  /// Joue une hauteur pendant [trames] trames.
  ///
  /// **Une trame a la fois.** L'analyse ne garde que quatre trames en attente
  /// et jette les plus anciennes sous pression : tout envoyer d'un bloc en
  /// perdrait la majorite, ce qu'un vrai micro ne fait pas puisqu'il les
  /// livre au fil du temps.
  Future<void> jouer(
    WidgetTester tester,
    FakeCapture micro,
    double frequenceHz, {
    int trames = 6,
  }) async {
    for (int i = 0; i < trames; i++) {
      micro.controleur.add(sinus(frequenceHz, 1).build());
      await tester.pump();
      await tester.pump();
    }
  }

  group('TunerScreen', () {
    testWidgets('sans son, il invite a jouer une corde', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      expect(find.text('Joue une corde a vide'), findsOneWidget);
      expect(find.byType(TunerGauge), findsOneWidget);
    });

    testWidgets('les quatre cordes sont proposees', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      for (final String nom in <String>['Sol', 'Re', 'La', 'Mi']) {
        expect(find.text(nom), findsOneWidget);
      }
    });

    testWidgets('un la juste est annonce juste', (WidgetTester tester) async {
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 440);

      expect(find.text('La4'), findsOneWidget);
      expect(consigne(tester), 'Juste. Ne touche plus a rien.');
    });

    testWidgets('une corde basse annonce son ecart en cents', (
      WidgetTester tester,
    ) async {
      // 435 Hz, soit une vingtaine de cents sous le la.
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 435);

      expect(find.text('La4'), findsOneWidget);
      expect(find.textContaining('cents'), findsOneWidget);
      final String texte =
          tester.widget<Text>(find.byKey(const Key('tuner-cents'))).data!;
      expect(texte.startsWith('-'), isTrue, reason: 'trop bas : $texte');
    });

    testWidgets('une corde haute le dit aussi', (WidgetTester tester) async {
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 446);

      final String texte =
          tester.widget<Text>(find.byKey(const Key('tuner-cents'))).data!;
      expect(texte.startsWith('+'), isTrue, reason: 'trop haut : $texte');
    });

    testWidgets('un petit ecart renvoie au tendeur, et nomme la corde', (
      WidgetTester tester,
    ) async {
      // 435 Hz : une vingtaine de cents sous le la. Le tendeur a la course
      // qu'il faut, et il est bien plus sur qu'une cheville.
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 435);

      expect(consigne(tester), 'Serre le tendeur du la');
      expect(find.byKey(const Key('tuner-rappel')), findsNothing);
    });

    testWidgets(
        'un gros ecart envoie a la cheville, avec le rappel qui va avec', (
      WidgetTester tester,
    ) async {
      // 420 Hz : quatre-vingts cents sous le la. Le tendeur arriverait en
      // butee ; c'est la cheville, et la cheville s'enfonce en tournant.
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 420);

      expect(consigne(tester), 'Serre la cheville du la');
      expect(find.byKey(const Key('tuner-rappel')), findsOneWidget);
    });

    testWidgets('une corde trop haute s entend dire de desserrer', (
      WidgetTester tester,
    ) async {
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 448);

      expect(consigne(tester), startsWith('Desserre'));
    });

    testWidgets('une corde juste dit de ne plus y toucher', (
      WidgetTester tester,
    ) async {
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 440);

      expect(consigne(tester), 'Juste. Ne touche plus a rien.');
      expect(find.byKey(const Key('tuner-rappel')), findsNothing);
    });

    // Les memes trois couleurs que la partition et le ruban : une consigne
    // qui en prendrait une quatrieme serait une couleur de plus a apprendre.
    //
    // **Une prise par cas.** Enchainer 435 puis 448 sur le meme ecran ferait
    // sauter la hauteur d'une cinquantaine de cents, et le lisseur -- a juste
    // titre -- declarerait la note instable au lieu de la juger.
    for (final (double hz, Color attendue, String cas) in <(
      double,
      Color,
      String,
    )>[
      (435, TuningColors.low, 'trop bas'),
      (448, TuningColors.high, 'trop haut'),
      (440, TuningColors.inTune, 'juste'),
    ]) {
      testWidgets('la consigne porte la couleur du sens : $cas', (
        WidgetTester tester,
      ) async {
        final FakeCapture micro = await poser(tester);
        await jouer(tester, micro, hz);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('tuner-consigne')))
              .style
              ?.color,
          attendue,
        );
      });
    }

    testWidgets('sans rien entendre, la consigne invite a jouer', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      expect(consigne(tester), 'Joue une corde a vide');
    });

    testWidgets('l ecran tient en paysage, rappel compris', (
      WidgetTester tester,
    ) async {
      // La consigne a ajoute soixante points de hauteur a un ecran qui n'en
      // avait pas de reste. En paysage, la barre systeme prise en compte, il
      // reste moins de trois cent trente points.
      await tester.binding.setSurfaceSize(const Size(743, 330));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, 420);

      expect(find.byKey(const Key('tuner-rappel')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('le diapason de reference est affiche', (
      WidgetTester tester,
    ) async {
      await poser(tester, a4: 442);
      expect(find.text('Diapason 442 Hz'), findsOneWidget);
    });

    testWidgets('un la a 442 est juste quand la reference est 442', (
      WidgetTester tester,
    ) async {
      // La regle de justesse relative : juger contre l'accord reel de
      // l'instrument, pas contre un chiffre.
      final FakeCapture micro = await poser(tester, a4: 442);
      await jouer(tester, micro, 442);
      expect(consigne(tester), 'Juste. Ne touche plus a rien.');
    });

    testWidgets('on peut adopter le diapason mesure', (
      WidgetTester tester,
    ) async {
      double? adopte;
      final FakeCapture micro = await poser(
        tester,
        onA4Changed: (double v) => adopte = v,
      );
      // Une seule mesure ne suffit plus : le diapason ne se confirme qu'apres
      // une serie, faute de quoi le bruit d'une piece proposerait d'en
      // changer. Une corde tenue une seconde donne largement la serie.
      await jouer(tester, micro, 442, trames: 24);

      final Finder bouton = find.textContaining('Adopter');
      expect(bouton, findsOneWidget);
      await tester.tap(bouton);
      await tester.pump();

      expect(adopte, closeTo(442, 1.5));
    });

    testWidgets('un micro refuse le dit clairement', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TunerScreen(
            pitchSourceFactory: () async => throw const MicPermissionDenied(),
            a4: 440,
            onA4Changed: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Micro refuse'), findsOneWidget);
    });

    testWidgets('quitter l ecran libere le micro', (
      WidgetTester tester,
    ) async {
      final FakeCapture micro = await poser(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // La liberation est asynchrone : on laisse l'horloge avancer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(micro.liberations, 1);
    });
  });

  group('TunerGauge', () {
    testWidgets('sans lecture, aucune aiguille n est peinte', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TunerGauge(reading: null))),
      );
      expect(find.byKey(const Key('tuner-gauge')), findsOneWidget);
    });

    testWidgets('l aiguille se colle au bord au-dela de l etendue', (
      WidgetTester tester,
    ) async {
      // Une corde tres fausse ne doit pas dessiner hors de l'ecran.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TunerGauge(
              reading: TunerReading(
                frequencyHz: PitchUtils.midiToFrequency(69),
                stringMidi: 69,
                centsOffset: -240,
                inTune: false,
                steady: true,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('quintes', () {
    testWidgets('sans deux cordes entendues, il invite a les jouer', (
      WidgetTester tester,
    ) async {
      await poser(tester);
      expect(
        find.text('Joue deux cordes voisines pour verifier tes quintes.'),
        findsOneWidget,
      );
    });

    testWidgets('deux cordes accordees en quinte juste donnent "juste"', (
      WidgetTester tester,
    ) async {
      // Un violon s'accorde sur le rapport 3:2, pas sur la quinte temperee
      // du piano. La corde de re est donc a deux cents au-dessus du tempere.
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, PitchUtils.midiToFrequency(55));
      await jouer(
        tester,
        micro,
        PitchUtils.midiToFrequency(55) * 3 / 2,
      );
      await tester.pump();

      expect(find.byKey(const Key('tuner-quintes')), findsOneWidget);
      expect(find.text('Sol3-Re4'), findsOneWidget);
      expect(find.text('juste'), findsWidgets);
    });

    testWidgets('une corde trop haute donne une quinte large', (
      WidgetTester tester,
    ) async {
      final FakeCapture micro = await poser(tester);
      await jouer(tester, micro, PitchUtils.midiToFrequency(55));
      await jouer(
        tester,
        micro,
        PitchUtils.midiToFrequency(55) * 3 / 2 * 1.012,
      );
      await tester.pump();

      expect(find.text('large'), findsOneWidget);
    });
  });
}

/// Fabrique un signal PCM 16 bits d'une sinusoide.
class Uint8ListBuilder {
  Uint8ListBuilder(this.frequenceHz, this.trames);

  final double frequenceHz;
  final int trames;

  Uint8List build() {
    const int sampleRate = 44100;
    final int n = 2048 * trames;
    final Uint8List bytes = Uint8List(n * 2);
    final ByteData vue = ByteData.view(bytes.buffer);
    for (int i = 0; i < n; i++) {
      final double v = math.sin(2 * math.pi * frequenceHz * i / sampleRate);
      vue.setInt16(i * 2, (v * 30000).round(), Endian.little);
    }
    return bytes;
  }
}
