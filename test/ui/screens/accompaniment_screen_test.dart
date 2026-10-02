import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/meter.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/play/accompaniment.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/core/play/headphones.dart';
import 'package:violon/core/play/metronome_clock.dart';
import 'package:violon/ui/screens/accompaniment_screen.dart';

/// Deux mesures de 3/4 en sol majeur, noire = 120.
Passage valse() => Passage(
      title: 'Valse',
      notes: const <ScoreNote>[
        ScoreNote(
          id: 'n1',
          midi: 67,
          onsetTicks: 0,
          durationTicks: 1440,
          measure: 1,
        ),
        ScoreNote(
          id: 'n2',
          midi: 74,
          onsetTicks: 1440,
          durationTicks: 1440,
          measure: 2,
        ),
      ],
      ticksPerBeat: 480,
      writtenTempoBpm: 120,
      meter: const Meter(3, 4),
      keyFifths: 1,
      bars: const <Bar>[
        Bar(number: 1, startTicks: 0, durationTicks: 1440),
        Bar(number: 2, startTicks: 1440, durationTicks: 1440),
      ],
    );

void main() {
  late FakeAudioEngine moteur;

  Future<void> poser(
    WidgetTester tester, {
    List<AccompanimentNote> partition = const <AccompanimentNote>[],
    double a4 = 440,
    HeadphoneProbe? headphones,
  }) async {
    moteur = FakeAudioEngine()..clock = const Duration(seconds: 10);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AccompanimentScreen(
          passage: valse(),
          engine: moteur,
          scoreAccompaniment: partition,
          a4: a4,
          headphones: headphones,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> jouer(WidgetTester tester) async {
    await tester.tap(find.byKey(AccompanimentScreen.jouerKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  group('AccompanimentScreen', () {
    testWidgets('sans partie ecrite, des accords, et le piano du morceau grise',
        (WidgetTester tester) async {
      await poser(tester);
      final ChoiceChip piano = tester.widget<ChoiceChip>(
        find.byKey(AccompanimentScreen.sourceKey(AccompanimentSource.score)),
      );
      expect(piano.onSelected, isNull);
      final ChoiceChip accords = tester.widget<ChoiceChip>(
        find.byKey(AccompanimentScreen.sourceKey(AccompanimentSource.chords)),
      );
      expect(accords.selected, isTrue);
      expect(moteur.notes, isEmpty, reason: 'rien ne sonne sans qu on demande');
    });

    testWidgets('jouer charge l instrument, pose le decompte puis les notes',
        (WidgetTester tester) async {
      await poser(tester);
      await jouer(tester);

      expect(moteur.prepared, contains('piano'));
      // Un decompte d'une mesure de 3/4 a 120 : trois clics, une demi-seconde
      // d'ecart, apres la marge de depart, sur l'horloge du moteur.
      expect(moteur.clicksAt.map((FakeClick c) => c.delay), <Duration>[
        const Duration(milliseconds: 10300),
        const Duration(milliseconds: 10800),
        const Duration(milliseconds: 11300),
      ]);
      expect(moteur.clicksAt.first.accent, PulseAccent.downbeat);
      // La premiere basse tombe apres le decompte : sol, la tonique.
      final FakeNote basse = moteur.notes.first;
      expect(basse.at, const Duration(milliseconds: 11800));
      expect(basse.instrument, 'piano');
      expect(
        PitchUtils.frequencyToMidi(basse.frequencyHz).round() % 12,
        7,
      );

      await tester.tap(find.byKey(AccompanimentScreen.jouerKey));
      await tester.pumpAndSettle();
      expect(moteur.stopAlls, greaterThan(0));
    });

    testWidgets('la melodie, sur l instrument choisi, au diapason mesure', (
      WidgetTester tester,
    ) async {
      await poser(tester, a4: 442);
      await tester.tap(
        find.byKey(AccompanimentScreen.sourceKey(AccompanimentSource.melody)),
      );
      await tester.tap(find.byKey(AccompanimentScreen.instrumentKey('violon')));
      await tester.pumpAndSettle();
      await jouer(tester);

      final FakeNote sol = moteur.notes.first;
      expect(sol.instrument, 'violon');
      expect(sol.frequencyHz,
          closeTo(PitchUtils.midiToFrequency(67, a4: 442), 1e-6));
      expect(sol.duration, const Duration(milliseconds: 1500));
    });

    testWidgets('la partie ecrite du morceau, quand elle existe', (
      WidgetTester tester,
    ) async {
      // Au casque : sur le haut-parleur, la basse serait remontee avant
      // meme d'atteindre l'instrument (ADR-017), et c'est la tessiture de
      // l'instrument qu'on veut voir agir ici.
      await poser(
        tester,
        partition: const <AccompanimentNote>[
          AccompanimentNote(midi: 28, onsetTicks: 0, durationTicks: 1440),
        ],
        headphones: FakeHeadphoneProbe(Headphones.wired),
      );
      final ChoiceChip piano = tester.widget<ChoiceChip>(
        find.byKey(AccompanimentScreen.sourceKey(AccompanimentSource.score)),
      );
      expect(piano.selected, isTrue);
      await jouer(tester);
      expect(moteur.notes.single.at, const Duration(milliseconds: 11800));
      // Mi1 est sous la tessiture du piano de test : une octave plus haut
      // plutot qu'un echantillon ralenti jusqu'a l'informe.
      expect(
        PitchUtils.frequencyToMidi(moteur.notes.single.frequencyHz).round(),
        40,
      );
    });

    testWidgets('quitter l ecran coupe le son', (WidgetTester tester) async {
      await poser(tester);
      await jouer(tester);
      final int avant = moteur.stopAlls;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(moteur.stopAlls, greaterThan(avant));
    });

    testWidgets('sur le haut-parleur la basse remonte, au casque non',
        (WidgetTester tester) async {
      Future<int> basse(HeadphoneProbe sonde) async {
        moteur = FakeAudioEngine()..clock = const Duration(seconds: 10);
        await tester.pumpWidget(
          MaterialApp(
            home: AccompanimentScreen(
              passage: valse(),
              engine: moteur,
              headphones: sonde,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await jouer(tester);
        final int midi =
            PitchUtils.frequencyToMidi(moteur.notes.first.frequencyHz).round();
        await tester.tap(find.byKey(AccompanimentScreen.jouerKey));
        await tester.pumpAndSettle();
        return midi;
      }

      // Sol2 ecrit : le haut-parleur du telephone ne le sort pas, il monte
      // d'une octave (ADR-017). Au casque, on joue ce qui est ecrit.
      expect(await basse(FakeHeadphoneProbe()), 55);
      expect(await basse(FakeHeadphoneProbe(Headphones.wired)), 43);
    });

    testWidgets('un accord s egrene, la basse seule reste a l heure',
        (WidgetTester tester) async {
      // Une mesure a deux temps : la basse puis l'accord tombent tous deux
      // dans l'horizon de la premiere planification.
      final Passage polka = Passage(
        title: 'Polka',
        notes: const <ScoreNote>[
          ScoreNote(
              id: 'n1',
              midi: 67,
              onsetTicks: 0,
              durationTicks: 960,
              measure: 1),
          ScoreNote(
              id: 'n2',
              midi: 74,
              onsetTicks: 960,
              durationTicks: 960,
              measure: 2),
        ],
        ticksPerBeat: 480,
        writtenTempoBpm: 120,
        meter: const Meter(2, 4),
        keyFifths: 1,
        bars: const <Bar>[
          Bar(number: 1, startTicks: 0, durationTicks: 960),
          Bar(number: 2, startTicks: 960, durationTicks: 960),
        ],
      );
      moteur = FakeAudioEngine()..clock = const Duration(seconds: 10);
      await tester.pumpWidget(
        MaterialApp(home: AccompanimentScreen(passage: polka, engine: moteur)),
      );
      await tester.pumpAndSettle();
      await jouer(tester);
      // Deux clics de decompte (1 s), puis la basse seule, exactement a
      // l'heure : 10 s + 300 ms de marge + 1 s.
      expect(moteur.notes.first.at, const Duration(milliseconds: 11300));
      // L'accord du deuxieme temps, 500 ms plus tard : ses notes ne partent
      // pas toutes au meme instant, et s'etalent sur moins de vingt
      // millisecondes.
      final List<Duration> accord = <Duration>[
        for (final FakeNote n in moteur.notes)
          if (n.at >= const Duration(milliseconds: 11800) &&
              n.at < const Duration(milliseconds: 11900))
            n.at,
      ];
      expect(accord.length, 3);
      expect(accord.toSet().length, 3);
      expect(accord.first, const Duration(milliseconds: 11800));
      expect(accord.last, lessThan(const Duration(milliseconds: 11820)));
      await tester.tap(find.byKey(AccompanimentScreen.jouerKey));
      await tester.pumpAndSettle();
    });
  });
}
