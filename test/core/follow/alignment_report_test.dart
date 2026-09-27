import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/alignment_report.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';

/// Deux mesures de 2/4 : n1 n2 | n3 n4.
Passage passage() {
  final PassageBuilder b = PassageBuilder(beatsPerMeasure: 2);
  for (final int midi in <int>[67, 69, 71, 72]) {
    b.add(midi, NoteValue.quarter);
  }
  return Passage(title: 't', notes: b.notes, ticksPerBeat: 480);
}

/// Un alignement fabrique : une trame toutes les 10 ms, chaque morceau donne
/// sa note et sa duree en millisecondes.
Alignment alignement(List<(String?, int)> morceaux) {
  final List<int> temps = <int>[];
  final List<String?> notes = <String?>[];
  for (final (String? id, int duree) in morceaux) {
    for (int i = 0; i < duree ~/ 10; i++) {
      temps.add(temps.length * 10);
      notes.add(id);
    }
  }
  return Alignment(frameTimesMs: temps, frameNotes: notes);
}

void main() {
  group('GroundTruth.parseAudacity', () {
    test('lit toutes les etiquettes du protocole', () {
      final GroundTruth v = GroundTruth.parseAudacity(
        '1.000000\t1.000000\tn1\n'
        '1.500000\t1.500000\tn2 faux\n'
        '2.000000\t3.500000\tarret\n'
        '3.500000\t3.500000\tx\n'
        '4.000000\t4.000000\t?\n'
        '\\\t100.0\t4000.0\n',
      );
      expect(v.notes, hasLength(4));
      expect(v.notes[0].noteId, 'n1');
      expect(v.notes[1].wrong, isTrue);
      expect(v.notes[2].extra, isTrue);
      expect(v.notes[3].doubtful, isTrue);
      expect(v.notes[3].extra, isFalse);
      expect(v.stops, <(int, int)>[(2000, 3500)]);
    });

    test('une etiquette illisible est une erreur, pas une ligne sautee', () {
      expect(
        () => GroundTruth.parseAudacity('1.0\t1.0\tn1 fau\n'),
        throwsFormatException,
      );
      expect(
        () => GroundTruth.parseAudacity('un\tdeux\tn1\n'),
        throwsFormatException,
      );
      expect(
          () => GroundTruth.parseAudacity('1.0\tn1\n'), throwsFormatException);
    });
  });

  group('AlignmentReport', () {
    test('un alignement parfait vaut cent pour cent', () {
      final AlignmentReport r = AlignmentReport.evaluate(
        alignement(<(String?, int)>[('n1', 500), ('n2', 500)]),
        GroundTruth.parseAudacity('0.0\t0.0\tn1\n0.5\t0.5\tn2\n'),
        passage(),
      );
      expect(r.counted, 2);
      expect(r.noteRate, 1);
      expect(r.measureRate, 1);
    });

    test('la bonne mesure et la bonne note se comptent a part', () {
      // n2 pris pour n1 : meme mesure, mauvaise note. n3 pris pour n1 :
      // mauvaise mesure.
      final AlignmentReport r = AlignmentReport.evaluate(
        alignement(<(String?, int)>[('n1', 1500)]),
        GroundTruth.parseAudacity('0.0\t0.0\tn1\n0.5\t0.5\tn2\n1.0\t1.0\tn3\n'),
        passage(),
      );
      expect(r.rightNote, 1);
      expect(r.rightMeasure, 2);
      expect(r.misses.map((NoteVerdict v) => v.label.noteId),
          <String>['n2', 'n3']);
    });

    test('une note fausse compte comme la note visee', () {
      final AlignmentReport r = AlignmentReport.evaluate(
        alignement(<(String?, int)>[('n1', 500)]),
        GroundTruth.parseAudacity('0.0\t0.0\tn1 faux\n'),
        passage(),
      );
      expect(r.rightNote, 1);
    });

    test('x et ? sont hors du denominateur', () {
      final AlignmentReport r = AlignmentReport.evaluate(
        alignement(<(String?, int)>[('n1', 500), ('n2', 500), ('n3', 500)]),
        GroundTruth.parseAudacity('0.0\t0.0\tn1\n0.5\t0.5\tx\n1.0\t1.0\t?\n'),
        passage(),
      );
      expect(r.counted, 1);
      expect(r.extras, 1);
      expect(r.doubtful, 1);
    });

    test('une note ajoutee n est une faute que si elle fait avancer', () {
      final GroundTruth v = GroundTruth.parseAudacity(
          '0.0\t0.0\tn1\n0.5\t0.5\tx\n1.0\t1.0\tn2\n');
      final AlignmentReport reste = AlignmentReport.evaluate(
        alignement(<(String?, int)>[('n1', 1000), ('n2', 500)]),
        v,
        passage(),
      );
      final AlignmentReport avance = AlignmentReport.evaluate(
        alignement(<(String?, int)>[('n1', 500), ('n2', 1000)]),
        v,
        passage(),
      );
      expect(reste.extrasTakenForNotes, 0);
      expect(avance.extrasTakenForNotes, 1);
    });

    test('un silence de l aligneur est une note manquee', () {
      final AlignmentReport r = AlignmentReport.evaluate(
        alignement(<(String?, int)>[(null, 1000)]),
        GroundTruth.parseAudacity('0.0\t0.0\tn1\n'),
        passage(),
      );
      expect(r.rightMeasure, 0);
      expect(r.misses.single.alignedId, isNull);
    });

    test('la fenetre d une note s arrete au debut d un arret', () {
      // n1 tenu 300 ms, puis un arret : ce que l'aligneur fait pendant
      // l'arret ne doit pas voter pour n1.
      final AlignmentReport r = AlignmentReport.evaluate(
        alignement(<(String?, int)>[('n1', 300), ('n2', 1500)]),
        GroundTruth.parseAudacity('0.0\t0.0\tn1\n0.3\t1.8\tarret\n'),
        passage(),
      );
      expect(r.rightNote, 1);
    });
  });
}
