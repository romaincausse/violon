import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/live_tuning.dart';
import 'package:violon/core/scoring/played_passage.dart';

void main() {
  /// Sol majeur sur une octave, en noires : do#, fa# et les autres y sont.
  Passage gamme() {
    final PassageBuilder b = PassageBuilder();
    for (final int midi in <int>[67, 69, 71, 72, 74, 76, 78, 79]) {
      b.add(midi, NoteValue.quarter);
    }
    return b.build();
  }

  PitchEstimate joue(int midi, double cents) => PitchEstimate(
        frequencyHz:
            PitchUtils.midiToFrequency(midi) * math.pow(2, cents / 1200),
        confidence: 1,
        timestampMs: 0,
      );

  /// Fait entendre [cents] d'ecart sur la note d'index [index].
  void entendre(Passage p, LiveTuning t, int index, double cents) {
    final ScoreNote note = p.notes[index];
    for (int i = 0; i < 3; i++) {
      t.observe(note, joue(note.midi, cents));
    }
  }

  group('playedPassage', () {
    test('sans rien entendre, la partition ne bouge pas', () {
      final Passage p = gamme();
      final PlayedPassage joue = playedPassage(p, LiveTuning());

      expect(joue.heardCount, 0);
      expect(joue.movedCount, 0);
      for (int i = 0; i < p.notes.length; i++) {
        expect(joue.passage.notes[i].midi, p.notes[i].midi);
        expect(joue.notes[i].heard, isFalse);
      }
    });

    test('un demi-ton trop bas deplace la tete d un demi-ton', () {
      final Passage p = gamme();
      final LiveTuning t = LiveTuning();
      entendre(p, t, 3, -100); // do au lieu du do# attendu

      final PlayedPassage joue = playedPassage(p, t);
      expect(joue.passage.notes[3].midi, p.notes[3].midi - 1);
      expect(joue.notes[3].moved, isTrue);
      expect(joue.movedCount, 1);
    });

    test('un ecart de justesse ne deplace rien', () {
      // Trente cents est le coeur du sujet du ruban d'ecart : c'est la meme
      // note, jouee un peu bas. La deplacer dirait faux.
      final Passage p = gamme();
      final LiveTuning t = LiveTuning();
      entendre(p, t, 2, -30);
      entendre(p, t, 4, 45);

      final PlayedPassage joue = playedPassage(p, t);
      expect(joue.movedCount, 0);
      expect(joue.notes[2].heard, isTrue);
      expect(joue.notes[4].heard, isTrue);
      expect(joue.passage.notes[2].midi, p.notes[2].midi);
    });

    test('le rythme, la mesure et l identifiant sont conserves', () {
      final Passage p = gamme();
      final LiveTuning t = LiveTuning();
      entendre(p, t, 0, -200);

      final PlayedPassage joue = playedPassage(p, t);
      // C'est ce qui permet au curseur, au bandeau de mesures et au bilan de
      // continuer a parler de la meme note.
      for (int i = 0; i < p.notes.length; i++) {
        expect(joue.passage.notes[i].id, p.notes[i].id);
        expect(joue.passage.notes[i].onsetTicks, p.notes[i].onsetTicks);
        expect(joue.passage.notes[i].durationTicks, p.notes[i].durationTicks);
        expect(joue.passage.notes[i].measure, p.notes[i].measure);
      }
      expect(joue.passage.ticksPerBeat, p.ticksPerBeat);
      expect(joue.passage.writtenTempoBpm, p.writtenTempoBpm);
      expect(joue.passage.title, p.title);
    });

    test('au-dela de l octave, la note est dite non entendue', () {
      // Une erreur d octave de YIN, ou un curseur qui s est trompe de note
      // attendue. Dans les deux cas ce n est pas l enfant qui a joue ailleurs,
      // c est nous qui ne savons pas.
      final Passage p = gamme();
      final LiveTuning t = LiveTuning();
      entendre(p, t, 5, -1200);

      final PlayedPassage joue = playedPassage(p, t);
      expect(joue.notes[5].heard, isFalse);
      expect(joue.notes[5].moved, isFalse);
      expect(joue.passage.notes[5].midi, p.notes[5].midi);
    });

    test('juste en deca de l octave, la note se deplace encore', () {
      final Passage p = gamme();
      final LiveTuning t = LiveTuning();
      entendre(p, t, 1, -1100);

      final PlayedPassage joue = playedPassage(p, t);
      expect(joue.notes[1].heard, isTrue);
      expect(joue.passage.notes[1].midi, p.notes[1].midi - 11);
    });

    test('le seuil de deplacement se regle', () {
      final Passage p = gamme();
      final LiveTuning t = LiveTuning();
      entendre(p, t, 1, -300);

      expect(
        playedPassage(p, t, maxShiftSemitones: 3).notes[1].heard,
        isFalse,
      );
      expect(playedPassage(p, t, maxShiftSemitones: 4).notes[1].heard, isTrue);
    });

    test('byId retrouve une note, et ignore un identifiant inconnu', () {
      final Passage p = gamme();
      final LiveTuning t = LiveTuning();
      entendre(p, t, 0, 100);

      final PlayedPassage joue = playedPassage(p, t);
      expect(joue.byId(p.notes.first.id)?.moved, isTrue);
      expect(joue.byId('rien du tout'), isNull);
    });

    test('la note deplacee garde l ecart mesure', () {
      final Passage p = gamme();
      final LiveTuning t = LiveTuning();
      entendre(p, t, 6, -120);

      final PlayedPassage joue = playedPassage(p, t);
      // L ecart reste celui a la note ECRITE : c est lui qui sert a noter, et
      // le deplacement de la tete n en est qu une lecture.
      expect(joue.notes[6].medianCents, closeTo(-120, 1));
      expect(joue.passage.notes[6].midi, p.notes[6].midi - 1);
    });
  });
}
