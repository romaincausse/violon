import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/meter.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/score/score_layout.dart';
import 'package:violon/core/score/staff_geometry.dart';
import 'package:violon/core/score/staff_layout.dart';
import 'package:violon/core/score/stems_and_beams.dart';

const int tpb = 480;
const int c = tpb ~/ 2; // une croche
const int mesure68 = 6 * c;

/// Un morceau en 6/8, re majeur, avec ses mesures : chaque mesure est une
/// liste de (midi, croches), midi nul pour un silence.
Passage morceau(
  List<List<(int, int)>> mesures, {
  int? keyFifths = 2,
  Meter meter = const Meter(6, 8),
  int croches = 6,
}) {
  final List<ScoreNote> notes = <ScoreNote>[];
  final List<Bar> bars = <Bar>[];
  int t = 0;
  for (int m = 0; m < mesures.length; m++) {
    bars.add(Bar(number: m + 1, startTicks: t, durationTicks: croches * c));
    int u = t;
    for (final (int midi, int d) in mesures[m]) {
      if (midi > 0) {
        notes.add(
          ScoreNote(
            id: 'n${notes.length + 1}',
            midi: midi,
            onsetTicks: u,
            durationTicks: d * c,
            measure: m + 1,
          ),
        );
      }
      u += d * c;
    }
    t += croches * c;
  }
  return Passage(
    title: 'essai',
    notes: notes,
    ticksPerBeat: tpb,
    meter: meter,
    keyFifths: keyFifths,
    bars: bars,
  );
}

List<int> durees(StaffLayout l) =>
    <int>[for (final PlacedNote p in l.notes) p.durationTicks ~/ c];

void main() {
  group('figures en 6/8', () {
    test('une croche liee a une noire pointee, pas une blanche a cheval', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(66, 1), (67, 1), (69, 4)],
        ]),
      );
      expect(durees(l), <int>[1, 1, 1, 3]);
      expect(l.notes[2].tiedToNext, isTrue);
      expect(l.notes[3].isContinuation, isTrue);
      expect(identical(l.notes[2].note, l.notes[3].note), isTrue);
    });

    test('une noire pointee liee a une croche, pas une blanche', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(62, 4), (64, 1), (66, 1)],
        ]),
      );
      expect(durees(l), <int>[3, 1, 1, 1]);
    });

    test('l hemiole garde ses trois noires', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(67, 2), (66, 2), (64, 2)],
        ]),
      );
      expect(durees(l), <int>[2, 2, 2]);
    });

    test('une note par-dessus la barre se coupe a la barre', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(69, 6)],
          <(int, int)>[],
        ]).withNotes(<ScoreNote>[
          const ScoreNote(
            id: 'n1',
            midi: 69,
            onsetTicks: 0,
            durationTicks: 2 * mesure68,
            measure: 1,
          ),
        ]),
      );
      expect(durees(l), <int>[6, 6]);
      expect(l.notes.map((PlacedNote p) => p.measure), <int>[1, 2]);
      expect(l.notes.first.tiedToNext, isTrue);
      expect(l.barlineXSpaces.first, lessThan(l.notes[1].xSpaces));
    });
  });

  group('silences', () {
    test('un trou devient un silence, une mesure vide une pause', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(71, 3), (0, 3)],
          <(int, int)>[(0, 6)],
          <(int, int)>[(69, 6)],
        ]),
      );
      expect(l.rests, hasLength(2));
      expect(l.rests[0].durationTicks, 3 * c);
      expect(l.rests[0].wholeBar, isFalse);
      expect(l.rests[1].wholeBar, isTrue);
      // La pause se pose au milieu de sa mesure.
      expect(
        l.rests[1].xSpaces,
        closeTo((l.barlineXSpaces[0] + l.barlineXSpaces[1]) / 2, 1),
      );
      expect(l.barlineXSpaces, hasLength(3));
    });

    test('un silence coupe la ligature', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(71, 1), (0, 1), (71, 1), (69, 3)],
        ]),
      );
      expect(StemsAndBeams.of(l).beams, isEmpty);
      expect(l.rests.single.durationTicks, c);
    });

    test('un passage sans mesures ne grave aucun silence', () {
      final Passage p = morceau(<List<(int, int)>>[
        <(int, int)>[(71, 3), (0, 3)],
        <(int, int)>[(69, 6)],
      ]);
      final Passage sansMesures = Passage(
        title: 'x',
        notes: p.notes,
        ticksPerBeat: tpb,
      );
      expect(StaffLayout.of(sansMesures).rests, isEmpty);
    });
  });

  group('ligatures', () {
    test('six croches en 6/8 font deux groupes de trois', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(71, 1), (71, 1), (71, 1), (74, 1), (74, 1), (74, 1)],
        ]),
      );
      expect(
        StemsAndBeams.of(l).beams.map((Beam b) => b.noteIndices.length),
        <int>[3, 3],
      );
    });

    test('six croches en 3/4 font trois groupes de deux', () {
      final StaffLayout l = StaffLayout.of(
        morceau(
          <List<(int, int)>>[
            <(int, int)>[(71, 1), (71, 1), (71, 1), (74, 1), (74, 1), (74, 1)],
          ],
          meter: const Meter(3, 4),
        ),
      );
      expect(
        StemsAndBeams.of(l).beams.map((Beam b) => b.noteIndices.length),
        <int>[2, 2, 2],
      );
    });
  });

  group('alterations selon l armure', () {
    test('en re majeur, fa# et do# ne portent rien, do becarre si', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(66, 1), (73, 1), (72, 1), (72, 1), (73, 2)],
          <(int, int)>[(72, 6)],
        ]),
      );
      expect(l.notes.map((PlacedNote p) => p.accidental), <Accidental>[
        Accidental.none, // fa#, dans l armure
        Accidental.none, // do#, dans l armure
        Accidental.natural, // do becarre
        Accidental.none, // le becarre vaut jusqu a la barre
        Accidental.sharp, // retour au do#, a redire
        Accidental.natural, // nouvelle mesure : le becarre est a redire
      ]);
    });

    test('en fa majeur, la touche noire s ecrit si bemol', () {
      final StaffLayout l = StaffLayout.of(
        morceau(
          <List<(int, int)>>[
            <(int, int)>[(70, 3), (71, 3)],
          ],
          keyFifths: -1,
        ),
      );
      expect(l.notes[0].step, 0, reason: 'si bemol, sur la ligne du milieu');
      expect(l.notes[0].accidental, Accidental.none);
      expect(l.notes[1].step, 0);
      expect(l.notes[1].accidental, Accidental.natural);
    });

    test('la tete liee ne repete pas l alteration', () {
      final StaffLayout l = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(66, 1), (65, 4), (64, 1)],
        ]),
      );
      expect(l.notes.map((PlacedNote p) => p.accidental), <Accidental>[
        Accidental.none,
        Accidental.natural,
        Accidental.none,
        Accidental.none,
      ]);
    });
  });

  group('tete de ligne', () {
    test('armure et chiffrage font de la place avant la premiere note', () {
      final StaffLayout avec = StaffLayout.of(
        morceau(<List<(int, int)>>[
          <(int, int)>[(69, 6)],
        ]),
      );
      final StaffLayout sans = StaffLayout.of(
        morceau(
          <List<(int, int)>>[
            <(int, int)>[(69, 6)],
          ],
          keyFifths: null,
        ),
        showTimeSignature: false,
      );
      expect(sans.notes.first.xSpaces, 9);
      expect(
        avec.notes.first.xSpaces,
        closeTo(
          9 +
              2 * StaffLayout.keyAccidentalSpaces +
              StaffLayout.timeSignatureSpaces,
          1e-9,
        ),
      );
      expect(avec.meter, const Meter(6, 8));
      expect(sans.meter, isNull);
    });

    test('le chiffrage ne se grave que sur le premier systeme', () {
      final ScoreLayout l = ScoreLayout.of(
        morceau(<List<(int, int)>>[
          for (int i = 0; i < 8; i++) <(int, int)>[(69, 6)],
        ]),
        maxWidthSpaces: 60,
      );
      expect(l.systemCount, greaterThan(1));
      expect(l.systems.first.layout.meter, const Meter(6, 8));
      expect(
        l.systems.skip(1).map((StaffSystem s) => s.layout.meter),
        everyElement(isNull),
      );
      expect(
        l.systems.map((StaffSystem s) => s.layout.keyFifths),
        everyElement(2),
      );
    });

    test('une mesure de silence peut ouvrir un systeme', () {
      final ScoreLayout l = ScoreLayout.of(
        morceau(<List<(int, int)>>[
          for (int i = 0; i < 6; i++)
            i.isOdd ? <(int, int)>[(0, 6)] : <(int, int)>[(69, 6)],
        ]),
        maxWidthSpaces: 50,
      );
      final int barres = l.systems.fold(
        0,
        (int n, StaffSystem s) => n + s.barlineXSpaces.length,
      );
      expect(barres, 6, reason: 'aucune mesure perdue d un systeme a l autre');
    });
  });

  group('StaffGeometry.spell', () {
    test('suit l armure, puis la couleur de la tonalite', () {
      SpelledPitch s(int midi, int? k) =>
          StaffGeometry.spell(midi, keyFifths: k);
      expect(s(70, -1).letter, 6, reason: 'si bemol en fa majeur');
      expect(s(70, -1).alter, -1);
      expect(s(70, 2).letter, 5, reason: 'la diese en re majeur');
      expect(s(72, 2).alter, 0, reason: 'do becarre en re majeur');
      expect(s(71, -7).letter, 0, reason: 'do bemol en do bemol majeur');
      expect(s(71, -7).octave, 5);
      expect(s(61, null).alter, 1, reason: 'sans armure, des dieses');
    });

    test('l armure se grave dans l ordre des dieses et des bemols', () {
      expect(StaffGeometry.keySignatureSteps(2), <int>[4, 1]);
      expect(StaffGeometry.keySignatureSteps(-3), <int>[0, 3, -1]);
      expect(StaffGeometry.keySignatureSteps(0), isEmpty);
    });
  });
}
