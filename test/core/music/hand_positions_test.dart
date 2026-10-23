import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/finger_pattern.dart';
import 'package:violon/core/music/hand_positions.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';

/// Des noires, chacune avec son doigte ecrit ou sans.
Passage passage(List<(int, String?)> notes) => Passage(
      title: 'x',
      ticksPerBeat: 480,
      notes: <ScoreNote>[
        for (int i = 0; i < notes.length; i++)
          ScoreNote(
            id: 'n$i',
            midi: notes[i].$1,
            onsetTicks: 480 * i,
            durationTicks: 480,
            measure: 1 + i ~/ 4,
            fingering: notes[i].$2,
          ),
      ],
    );

/// "corde/position/doigt", ou "?" quand on ne sait pas.
List<String> lire(Passage p) {
  final Map<String, FingerPlacement?> m = HandPositions.of(p);
  return <String>[
    for (final ScoreNote n in p.notes)
      if (m[n.id] case final FingerPlacement f)
        '${f.stringMidi}/${f.position}/${f.finger}'
      else
        '?',
  ];
}

void main() {
  test('sans doigte, la premiere position, comme un eleve la joue', () {
    // Sol majeur sur la corde de re puis de la.
    expect(
      lire(passage(<(int, String?)>[
        (62, null),
        (64, null),
        (66, null),
        (67, null),
        (69, null),
        (71, null),
      ])),
      <String>['62/1/0', '62/1/1', '62/1/2', '62/1/3', '69/1/0', '69/1/1'],
    );
  });

  test('un doigte dit la position, et elle dure sur les notes suivantes', () {
    // Re5 au 1er doigt : troisieme position sur la corde de la ; mi5 sans
    // doigte se joue a vide ; fa#5 et sol5 restent en troisieme.
    expect(
      lire(passage(<(int, String?)>[
        (74, '1'),
        (78, null),
        (79, null),
        (76, null),
      ])),
      <String>['69/3/1', '69/3/3', '69/3/4', '76/1/0'],
    );
    // Le meme re5 au 3e doigt : premiere position.
    expect(lire(passage(<(int, String?)>[(74, '3')])), <String>['69/1/3']);
  });

  test('au-dessus de la premiere position, sans doigte, on ne sait pas', () {
    // Do6 n'est pas en premiere ; ses voisines aigues non plus. La corde a
    // vide ramene la main en bas.
    expect(
      lire(passage(<(int, String?)>[
        (66, null),
        (79, null),
        (81, null),
        (84, null),
        (81, null),
        (78, null),
        (76, null),
        (78, null),
      ])),
      <String>['62/1/2', '?', '?', '?', '?', '?', '76/1/0', '76/1/1'],
    );
  });

  test('un doigte qui ne tient nulle part ne place rien', () {
    expect(lire(passage(<(int, String?)>[(74, '4'), (76, '0')])),
        <String>['?', '76/1/0']);
  });

  test('les arrivees de demanche : la note d avant etait dans l autre position',
      () {
    final Passage p = passage(<(int, String?)>[
      (71, '1'), // si4, premiere
      (74, '1'), // re5, troisieme : arrivee
      (76, null), // mi5 a vide : pas une arrivee
      (78, '3'), // fa#5 en troisieme, apres une corde a vide
      (73, '2'), // do#5, premiere : arrivee
    ]);
    expect(HandPositions.shiftArrivals(p), <String>{'n1', 'n4'});
  });
}
