import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/meter.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/play/accompaniment.dart';
import 'package:violon/core/play/harmonizer.dart';

/// Une melodie mesure par mesure : chaque mesure est une liste de
/// (midi, noires), en [meter].
Passage melodie(
  List<List<(int, int)>> mesures, {
  int? keyFifths,
  Meter meter = const Meter(4, 4),
}) {
  final List<ScoreNote> notes = <ScoreNote>[];
  final List<Bar> bars = <Bar>[];
  final int longueur = meter.ticksPerMeasure(480);
  int t = 0;
  for (int m = 0; m < mesures.length; m++) {
    bars.add(Bar(number: m + 1, startTicks: t, durationTicks: longueur));
    int u = t;
    for (final (int midi, int noires) in mesures[m]) {
      notes.add(
        ScoreNote(
          id: 'n${notes.length + 1}',
          midi: midi,
          onsetTicks: u,
          durationTicks: noires * 480,
          measure: m + 1,
        ),
      );
      u += noires * 480;
    }
    t += longueur;
  }
  return Passage(
    title: 'x',
    notes: notes,
    ticksPerBeat: 480,
    meter: meter,
    keyFifths: keyFifths,
    bars: bars,
  );
}

void main() {
  group('tonalite', () {
    test('l armure donne le majeur, la sensible le relatif mineur', () {
      // Re majeur qui finit sur si : toujours re majeur, faute de la diese.
      final Passage re = melodie(<List<(int, int)>>[
        <(int, int)>[(62, 1), (66, 1), (69, 1), (71, 1)],
      ], keyFifths: 2);
      expect(Harmonizer.keyOf(re), const KeyGuess(2, minor: false));
      // Si mineur : le la diese le signe.
      final Passage si = melodie(<List<(int, int)>>[
        <(int, int)>[(71, 1), (74, 1), (70, 1), (71, 1)],
      ], keyFifths: 2);
      expect(Harmonizer.keyOf(si), const KeyGuess(11, minor: true));
    });

    test('sans armure, la tonalite la plus compatible avec les notes', () {
      final Passage sol = melodie(<List<(int, int)>>[
        <(int, int)>[(67, 1), (71, 1), (74, 1), (66, 1)],
        <(int, int)>[(67, 4)],
      ]);
      expect(Harmonizer.keyOf(sol), const KeyGuess(7, minor: false));
    });
  });

  group('accords', () {
    test('I - IV - V - I sur une melodie qui les dessine', () {
      final Passage p = melodie(<List<(int, int)>>[
        <(int, int)>[(60, 2), (64, 2)],
        <(int, int)>[(65, 2), (69, 2)],
        <(int, int)>[(67, 2), (71, 2)],
        <(int, int)>[(72, 4)],
      ], keyFifths: 0);
      final List<Chord> c = Harmonizer.chordsFor(p);
      // Deux tranches par mesure a quatre temps, et le meme accord dans les
      // deux : on ne change pas au milieu sans raison.
      expect(c.map((Chord x) => x.degree), <int>[0, 0, 3, 3, 4, 4, 0, 0]);
    });

    test('la septieme baissee appelle le VII bemol, pas un accord qui heurte',
        () {
      // Do - mi - sol en re majeur : l'accord de do, emprunte.
      final Passage p = melodie(<List<(int, int)>>[
        <(int, int)>[(62, 4)],
        <(int, int)>[(60, 1), (64, 1), (67, 2)],
        <(int, int)>[(62, 4)],
      ], keyFifths: 2);
      final List<Chord> c = Harmonizer.chordsFor(p);
      expect(c[2].degree, 6);
      expect(c[2].tones, <int>[0, 4, 7], reason: 'do - mi - sol');
    });

    test('en 3/4 une tranche par mesure, en 6/8 deux', () {
      expect(
        Harmonizer.slicesOf(
          melodie(<List<(int, int)>>[
            <(int, int)>[(67, 3)],
          ], meter: const Meter(3, 4)),
        ),
        <(int, int)>[(0, 1440)],
      );
      expect(
        Harmonizer.slicesOf(
          melodie(<List<(int, int)>>[
            <(int, int)>[(67, 3)],
          ], meter: const Meter(6, 8)),
        ),
        <(int, int)>[(0, 720), (720, 1440)],
      );
    });

    test('toujours le meme accompagnement pour le meme passage', () {
      final Passage p = melodie(<List<(int, int)>>[
        <(int, int)>[(67, 1), (69, 1), (71, 1), (72, 1)],
        <(int, int)>[(74, 2), (71, 2)],
      ], keyFifths: 1);
      String rendu() => Harmonizer.accompaniment(p).join(',');
      expect(rendu(), rendu());
    });
  });

  group('motif', () {
    test('en 3/4 : la basse, puis deux accords', () {
      final List<AccompanimentNote> n = Harmonizer.accompaniment(
        melodie(<List<(int, int)>>[
          <(int, int)>[(67, 3)],
        ], keyFifths: 1, meter: const Meter(3, 4)),
      );
      final List<int> attaques =
          n.map((AccompanimentNote x) => x.onsetTicks).toSet().toList();
      expect(attaques, <int>[0, 480, 960]);
      final AccompanimentNote basse = n.first;
      expect(basse.midi % 12, 7, reason: 'sol, la fondamentale');
      expect(basse.midi, lessThan(55), reason: 'sous le violon');
      expect(
          n.where((AccompanimentNote x) => x.onsetTicks == 480), hasLength(3));
    });

    test('en 6/8 : basse sur le premier temps, accord sur le second', () {
      final List<AccompanimentNote> n = Harmonizer.accompaniment(
        melodie(<List<(int, int)>>[
          <(int, int)>[(62, 3)],
        ], keyFifths: 2, meter: const Meter(6, 8)),
      );
      expect(
        n.map((AccompanimentNote x) => x.onsetTicks).toSet(),
        <int>{0, 720},
      );
    });

    test('les accords bougent le moins possible d une tranche a l autre', () {
      final List<AccompanimentNote> n = Harmonizer.accompaniment(
        melodie(<List<(int, int)>>[
          <(int, int)>[(60, 4)],
          <(int, int)>[(65, 4)],
          <(int, int)>[(67, 4)],
          <(int, int)>[(60, 4)],
        ], keyFifths: 0),
      );
      final List<int> aigus = <int>[
        for (final AccompanimentNote x in n)
          if (x.midi >= 52) x.midi,
      ];
      expect(
          aigus.reduce((int a, int b) => a > b ? a : b) -
              aigus.reduce((int a, int b) => a < b ? a : b),
          lessThanOrEqualTo(12));
    });
  });
}
