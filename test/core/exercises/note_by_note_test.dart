import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/note_by_note.dart';
import 'package:violon/core/music/finger_pattern.dart';

void main() {
  /// Trois poses : re a vide, mi au premier doigt, fa# au deuxieme.
  List<FingerPlacement> troisNotes() => <FingerPlacement>[
        const FingerPlacement(stringMidi: 62, finger: 0, midi: 62),
        const FingerPlacement(stringMidi: 62, finger: 1, midi: 64),
        const FingerPlacement(stringMidi: 62, finger: 2, midi: 66),
      ];

  NoteByNote poser() => NoteByNote(placements: troisNotes());

  /// Joue [midi] assez longtemps pour valider, a partir de [depuis].
  void jouer(NoteByNote n, double midi, {Duration depuis = Duration.zero}) {
    for (int i = 0; i < n.confirmations; i++) {
      n.hear(midi, depuis + Duration(milliseconds: i * 46));
    }
  }

  group('NoteByNote', () {
    test('au depart, on attend la premiere note et l aide est muette', () {
      final NoteByNote n = poser();
      expect(n.index, 0);
      expect(n.expected?.midi, 62);
      expect(n.showHelp, isFalse);
      expect(n.isFinished, isFalse);
    });

    test('la bonne note fait avancer', () {
      final NoteByNote n = poser();
      jouer(n, 62);
      expect(n.index, 1);
      expect(n.expected?.midi, 64);
      expect(n.toRework, isEmpty);
    });

    test('une seule trame ne suffit pas', () {
      // L'enfant cherche : il traverse la bonne note en glissant, et une
      // trame validerait ce passage au vol.
      final NoteByNote n = poser();
      n.hear(62, Duration.zero);
      expect(n.index, 0);
    });

    test('deux trames justes separees par une fausse ne valident pas', () {
      final NoteByNote n = poser();
      n.hear(62, Duration.zero);
      n.hear(64, const Duration(milliseconds: 46));
      n.hear(62, const Duration(milliseconds: 92));
      expect(n.index, 0);
    });

    test('la mauvaise note n avance pas, et ne punit pas', () {
      final NoteByNote n = poser();
      for (int i = 0; i < 20; i++) {
        n.hear(66, Duration(milliseconds: i * 46));
      }
      expect(n.index, 0);
      expect(n.toRework, isEmpty);
    });

    test('la tolerance est celle de partout ailleurs', () {
      final NoteByNote n = poser();
      // Trente cents sous le re : juste, comme le dirait le ruban d ecart.
      jouer(n, 62 - 0.30);
      expect(n.index, 1);
    });

    test('au-dela de la tolerance, ce n est plus la note', () {
      final NoteByNote n = poser();
      jouer(n, 62 - 0.40);
      expect(n.index, 0);
    });

    test('l aide arrive apres quelques secondes de recherche', () {
      final NoteByNote n = poser();
      n.wait(n.helpAfter - const Duration(milliseconds: 1));
      expect(n.showHelp, isFalse);
      n.wait(n.helpAfter);
      expect(n.showHelp, isTrue);
      // Et elle n'a rien fait avancer : elle aide, elle ne juge pas.
      expect(n.index, 0);
    });

    test('puis on passe, sans qu on ait rien a demander', () {
      // **Bloquer oui, impasse non.** L'enfant n'a jamais a demander la
      // permission d'avancer.
      final NoteByNote n = poser();
      n.wait(n.skipAfter);
      expect(n.index, 1);
      expect(n.showHelp, isFalse);
      expect(n.toRework, <int>[0]);
    });

    test('la note manquee devient la prochaine tache', () {
      // Elle ne disparait pas : c'est le mecanisme que le projet met au
      // centre.
      final NoteByNote n = poser();
      n.wait(n.skipAfter);
      jouer(n, 64, depuis: n.skipAfter);
      n.wait(n.skipAfter * 2 + const Duration(seconds: 1));
      expect(n.toRework, <int>[0, 2]);
      expect(n.found, 1);
    });

    test('l horloge repart a chaque note', () {
      final NoteByNote n = poser();
      jouer(n, 62, depuis: const Duration(seconds: 3));
      // Trois secondes se sont ecoulees, mais pas sur CETTE note.
      n.wait(const Duration(seconds: 3, milliseconds: 500));
      expect(n.showHelp, isFalse);
    });

    test('le motif se termine, et on ne le pousse pas plus loin', () {
      final NoteByNote n = poser();
      jouer(n, 62);
      jouer(n, 64);
      jouer(n, 66);
      expect(n.isFinished, isTrue);
      expect(n.expected, isNull);
      expect(n.showHelp, isFalse);
      expect(n.found, 3);

      // Plus rien ne bouge, et surtout rien ne deborde.
      n.wait(const Duration(minutes: 1));
      jouer(n, 62);
      expect(n.index, n.total);
      expect(n.toRework, isEmpty);
    });

    test('recommencer efface tout', () {
      final NoteByNote n = poser();
      n.wait(n.skipAfter);
      expect(n.toRework, isNotEmpty);
      n.reset();
      expect(n.index, 0);
      expect(n.toRework, isEmpty);
      expect(n.showHelp, isFalse);
    });
  });
}
