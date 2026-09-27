import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';

/// Deux mesures de 2/4 : sol la | re re.
Passage passage() {
  final PassageBuilder b = PassageBuilder(beatsPerMeasure: 2);
  for (final int midi in <int>[67, 69, 74, 74]) {
    b.add(midi, NoteValue.quarter);
  }
  return Passage(title: 't', notes: b.notes, ticksPerBeat: 480);
}

/// Des trames fabriquees a la main, sans audio : ce qu'on teste ici est la
/// decision de l'aligneur, pas l'oreille. Chaque morceau dure [trames] trames
/// de 23 ms ; `null` est un silence.
class Jeu {
  final List<FeatureFrame> frames = <FeatureFrame>[];

  void joue(double? midi, {int trames = 12, bool attaque = true}) {
    for (int i = 0; i < trames; i++) {
      frames.add(
        FeatureFrame(
          timeMs: frames.length * 23,
          midi: midi,
          rms: midi == null ? 0.001 : 0.2,
          onset: attaque && i == 0 && midi != null,
        ),
      );
    }
  }

  void silence({int trames = 50}) => joue(null, trames: trames);
}

/// La suite des notes reconnues.
List<String> reconnues(Jeu jeu, {Set<String> liees = const <String>{}}) =>
    <String>[
      for (final AlignedNote n in OfflineAligner(passage(), slurredInto: liees)
          .align(jeu.frames)
          .notes)
        n.noteId,
    ];

void main() {
  group('OfflineAligner', () {
    test('un passage joue d un bout a l autre', () {
      final Jeu jeu = Jeu()
        ..silence(trames: 20)
        ..joue(67)
        ..joue(69)
        ..joue(74)
        ..joue(74)
        ..silence(trames: 20);
      expect(reconnues(jeu), <String>['n1', 'n2', 'n3', 'n4']);
    });

    test('deux notes a la meme hauteur se comptent par leurs attaques', () {
      // YIN ne voit qu'un re continu : seule l'attaque d'archet separe n3 de
      // n4. Sans elle, l'aligneur ne compterait qu'une note.
      final Jeu jeu = Jeu()
        ..joue(67)
        ..joue(69)
        ..joue(74)
        ..joue(74);
      expect(reconnues(jeu), <String>['n1', 'n2', 'n3', 'n4']);
    });

    test('un arret puis la reprise de la mesure', () {
      final Jeu jeu = Jeu()
        ..joue(67)
        ..joue(69)
        ..joue(74)
        ..silence()
        ..joue(74)
        ..joue(74);
      expect(reconnues(jeu), <String>['n1', 'n2', 'n3', 'n3', 'n4']);
    });

    test('un retour au debut sans s arreter', () {
      final Jeu jeu = Jeu()
        ..joue(67)
        ..joue(69)
        ..joue(74)
        ..joue(67)
        ..joue(69)
        ..joue(74)
        ..joue(74);
      expect(
        reconnues(jeu),
        <String>['n1', 'n2', 'n3', 'n1', 'n2', 'n3', 'n4'],
      );
    });

    test('une note fausse ne fait pas perdre la position', () {
      // Le la joue quarante cents trop haut reste le la.
      final Jeu jeu = Jeu()
        ..joue(67)
        ..joue(69.4)
        ..joue(74)
        ..joue(74);
      expect(reconnues(jeu), <String>['n1', 'n2', 'n3', 'n4']);
    });

    test('une note ajoutee ne fait pas avancer', () {
      final Jeu jeu = Jeu()
        ..joue(67)
        ..joue(64, trames: 6)
        ..joue(69)
        ..joue(74)
        ..joue(74);
      expect(reconnues(jeu), <String>['n1', 'n2', 'n3', 'n4']);
    });

    test('une erreur d octave de YIN est toleree', () {
      final Jeu jeu = Jeu()
        ..joue(67)
        ..joue(81)
        ..joue(74)
        ..joue(74);
      expect(reconnues(jeu), <String>['n1', 'n2', 'n3', 'n4']);
    });

    test('dans une liaison, le changement de hauteur suffit a avancer', () {
      final Jeu jeu = Jeu()
        ..joue(67)
        ..joue(69, attaque: false)
        ..joue(74)
        ..joue(74);
      expect(
        reconnues(jeu, liees: <String>{'n2'}),
        <String>['n1', 'n2', 'n3', 'n4'],
      );
    });

    test('une prise vide ne reconnait rien', () {
      expect(OfflineAligner(passage()).align(<FeatureFrame>[]).notes, isEmpty);
      expect(reconnues(Jeu()..silence()), isEmpty);
    });

    test('une note reconnue porte ses instants de debut et de fin', () {
      final Jeu jeu = Jeu()
        ..silence(trames: 10)
        ..joue(67, trames: 20)
        ..silence(trames: 30);
      final List<AlignedNote> notes =
          OfflineAligner(passage()).align(jeu.frames).notes;
      expect(notes, hasLength(1));
      expect(notes.single.startMs, 230);
      expect(notes.single.endMs, 690);
    });
  });
}
