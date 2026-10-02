import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/alignment_report.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/proposed_labels.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';

void main() {
  // Mesure 1 : re re mi ; mesure 2 : fa# re.
  final Passage passage = Passage(
    title: 't',
    ticksPerBeat: 480,
    writtenTempoBpm: 60,
    notes: const <ScoreNote>[
      ScoreNote(
          id: 'n1', midi: 62, onsetTicks: 0, durationTicks: 480, measure: 1),
      ScoreNote(
          id: 'n2', midi: 62, onsetTicks: 480, durationTicks: 480, measure: 1),
      ScoreNote(
          id: 'n3', midi: 64, onsetTicks: 960, durationTicks: 480, measure: 1),
      ScoreNote(
          id: 'n4', midi: 66, onsetTicks: 1440, durationTicks: 480, measure: 2),
      ScoreNote(
          id: 'n5', midi: 62, onsetTicks: 1920, durationTicks: 480, measure: 2),
    ],
  );

  String etiquettes(String corrige) =>
      ProposedLabels.resolve(corrige, passage).$1;

  test('propose un marqueur lisible par note reconnue', () {
    final Alignment a = Alignment(
      frameTimesMs: <int>[0, 100, 200, 300],
      frameNotes: <String?>['n1', 'n1', null, 'n4'],
    );
    expect(
      ProposedLabels.propose(a, passage),
      '0.000\t0.000\tm1 re n1\n0.300\t0.300\tm2 fa# n4\n',
    );
  });

  test('un marqueur non corrige garde son identifiant', () {
    expect(etiquettes('1.0\t1.0\tm1 re n2\n'), '1.0\t1.0\tn2\n');
  });

  test('une correction sans identifiant retrouve la note dans la mesure', () {
    final (String e, List<String> deduites) = ProposedLabels.resolve(
      '1.0\t1.0\tm1 re n1\n2.0\t2.0\tm2 fa#\n',
      passage,
    );
    expect(e, '1.0\t1.0\tn1\n2.0\t2.0\tn4\n');
    expect(deduites.single, contains('n4'));
  });

  test('un identifiant qui contredit le nom corrige est ignore', () {
    // L'annotateur a remplace "re" par "mi" sans effacer n1.
    expect(etiquettes('1.0\t1.0\tm1 mi n1\n'), '1.0\t1.0\tn3\n');
  });

  test('parmi deux notes du meme nom, la suivante dans le jeu', () {
    expect(
      etiquettes('1.0\t1.0\tm1 re n1\n2.0\t2.0\tm1 re\n'),
      '1.0\t1.0\tn1\n2.0\t2.0\tn2\n',
    );
    // Une reprise : apres n2, un "re" de mesure 1 ne peut plus etre devant,
    // on revient au premier.
    expect(
      etiquettes('1.0\t1.0\tm1 re n2\n2.0\t2.0\tm1 re\n'),
      '1.0\t1.0\tn2\n2.0\t2.0\tn1\n',
    );
  });

  test('x, ?, arret et faux passent tels quels', () {
    expect(
      etiquettes('1.0\t1.0\tx\n2.0\t2.0\t?\n3.0\t4.0\tarret\n'
          '5.0\t5.0\tm1 mi faux\n'),
      '1.0\t1.0\tx\n2.0\t2.0\t?\n3.0\t4.0\tarret\n5.0\t5.0\tn3 faux\n',
    );
    // Le resultat se relit par le parseur du banc.
    expect(
      GroundTruth.parseAudacity(etiquettes('5.0\t5.0\tm1 mi faux\n'))
          .notes
          .single
          .wrong,
      isTrue,
    );
  });

  test('les accents et les bemols s ecrivent comme on veut', () {
    expect(ProposedLabels.classe('Ré'), 2);
    expect(ProposedLabels.classe('solb'), 6);
    expect(ProposedLabels.classe('fa#'), 6);
    expect(ProposedLabels.classe('ut'), isNull);
  });

  test('un marqueur illisible ou introuvable est une erreur dite', () {
    expect(() => etiquettes('1.0\t1.0\tbla\n'), throwsFormatException);
    expect(() => etiquettes('1.0\t1.0\tm2 mi\n'), throwsFormatException);
  });
}
