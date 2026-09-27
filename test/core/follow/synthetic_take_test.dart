import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/synthetic_take.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';

/// Huit noires, deux mesures : sol la si do re re re re.
Passage passage({int tempo = 60}) {
  final PassageBuilder b = PassageBuilder();
  for (final int midi in <int>[67, 69, 71, 72, 74, 74, 74, 74]) {
    b.add(midi, NoteValue.quarter);
  }
  return Passage(
    title: 'test',
    notes: b.notes,
    ticksPerBeat: b.ticksPerBeat,
    writtenTempoBpm: tempo,
  );
}

/// Un scenario sans aucun alea, pour tester les durees a la milliseconde.
TakeScript exact(Passage p) => TakeScript(
      p,
      timingJitter: Duration.zero,
      intonationSpreadCents: 0,
    );

List<String> etiquettes(SyntheticTake prise) =>
    <String>[for (final PlayedNote n in prise.notes) n.label];

void main() {
  group('TakeScript', () {
    test('une reprise rejoue les memes notes, dans l ordre joue', () {
      final SyntheticTake prise = (exact(passage())
            ..play('n1', 'n4')
            ..play('n3', 'n5'))
          .build();
      expect(etiquettes(prise),
          <String>['n1', 'n2', 'n3', 'n4', 'n3', 'n4', 'n5']);
    });

    test('au tempo ecrit, une noire a 60 dure une seconde', () {
      final SyntheticTake prise = (exact(passage())..play('n1', 'n2')).build();
      expect(prise.notes[0].sound.start, const Duration(seconds: 1));
      expect(prise.notes[0].sound.duration, const Duration(seconds: 1));
      expect(prise.notes[1].sound.start, const Duration(seconds: 2));
      expect(prise.length, const Duration(seconds: 4));
    });

    test('changer de tempo en cours de prise raccourcit la suite', () {
      final SyntheticTake prise = (exact(passage())
            ..play('n1', 'n1')
            ..tempo(120)
            ..play('n2', 'n2'))
          .build();
      expect(prise.notes[1].sound.duration, const Duration(milliseconds: 500));
    });

    test('au-dela d un demi-demi-ton, la note est fausse ; en deca, non', () {
      final SyntheticTake prise = (exact(passage())
            ..play(
              'n1',
              'n3',
              centsOff: <String, double>{'n2': 70, 'n3': -30},
            ))
          .build();
      expect(etiquettes(prise), <String>['n1', 'n2 faux', 'n3']);
      expect(prise.notes[1].sound.midi, closeTo(69.7, 1e-9));
    });

    test('une note sautee disparait sans creuser de silence', () {
      final SyntheticTake prise =
          (exact(passage())..play('n1', 'n4', skip: <String>{'n2'})).build();
      expect(etiquettes(prise), <String>['n1', 'n3', 'n4']);
      expect(prise.notes[1].sound.start, prise.notes[0].sound.end);
    });

    test('une note ajoutee s annote x', () {
      final SyntheticTake prise = (exact(passage())
            ..play('n1', 'n1')
            ..extra(70)
            ..play('n2', 'n2'))
          .build();
      expect(etiquettes(prise), <String>['n1', 'x', 'n2']);
    });

    test('dans une liaison, seule la premiere note attaque', () {
      final SyntheticTake prise =
          (exact(passage())..play('n1', 'n3', slurred: true)).build();
      expect(
        <bool>[for (final PlayedNote n in prise.notes) n.sound.attack],
        <bool>[true, false, false],
      );
    });

    test('la meme graine rejoue la meme prise', () {
      SyntheticTake prise(int graine) =>
          (TakeScript(passage(), seed: graine)..play('n1', 'n8')).build();
      expect(prise(3).audacityLabels(), prise(3).audacityLabels());
      expect(prise(3).audacityLabels(), isNot(prise(4).audacityLabels()));
    });

    test('l imprecision de tous les jours ne rend jamais une note fausse', () {
      final SyntheticTake prise = (TakeScript(
        passage(),
        seed: 11,
        intonationSpreadCents: 15,
      )..play('n1', 'n8'))
          .build();
      expect(prise.notes.where((PlayedNote n) => n.wrong), isEmpty);
    });

    test('une note absente ou un fragment a l envers est refuse', () {
      expect(() => exact(passage()).play('n1', 'n99'), throwsArgumentError);
      expect(() => exact(passage()).play('n4', 'n2'), throwsArgumentError);
      expect(() => exact(passage()).tempo(0), throwsArgumentError);
    });

    test('le rendu couvre toute la prise, silences compris', () {
      final SyntheticTake prise = (exact(passage())..play('n1', 'n1')).build();
      expect(prise.render(ViolinSynth()), hasLength(3 * 44100));
    });
  });

  group('SyntheticTake.audacityLabels', () {
    test('une etiquette ponctuelle par note, au format d Audacity', () {
      final SyntheticTake prise = (exact(passage())..play('n1', 'n2')).build();
      expect(
        prise.audacityLabels(),
        '1.000000\t1.000000\tn1\n'
        '2.000000\t2.000000\tn2\n',
      );
    });

    test('un silence de plus d une seconde est une region arret', () {
      final SyntheticTake prise = (exact(passage())
            ..play('n1', 'n1')
            ..pause(const Duration(milliseconds: 1500))
            ..play('n1', 'n1')
            ..pause(const Duration(milliseconds: 500))
            ..play('n2', 'n2'))
          .build();
      expect(
        prise.audacityLabels(),
        '1.000000\t1.000000\tn1\n'
        '2.000000\t3.500000\tarret\n'
        '3.500000\t3.500000\tn1\n'
        '5.000000\t5.000000\tn2\n',
      );
    });
  });
}
