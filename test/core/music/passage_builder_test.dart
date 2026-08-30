import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/score_note.dart';

void main() {
  group('NoteValue', () {
    test('les durees suivent les figures', () {
      expect(NoteValue.whole.ticksIn(480), 1920);
      expect(NoteValue.half.ticksIn(480), 960);
      expect(NoteValue.quarter.ticksIn(480), 480);
      expect(NoteValue.eighth.ticksIn(480), 240);
      expect(NoteValue.sixteenth.ticksIn(480), 120);
    });

    test('les initiales de figure sont toutes distinctes', () {
      final Set<String> initiales =
          NoteValue.values.map((NoteValue v) => v.shortLabel).toSet();
      expect(initiales.length, NoteValue.values.length);
      expect(NoteValue.quarter.shortLabel, 'N');
    });

    test('le point ajoute la moitie de la duree', () {
      expect(NoteValue.quarter.ticksIn(480, dotted: true), 720);
      expect(NoteValue.eighth.ticksIn(480, dotted: true), 360);
    });

    test('meme pointee, la figure la plus breve reste entiere', () {
      // 480 est un multiple de 8 : une double pointee tombe juste.
      expect(NoteValue.sixteenth.ticksIn(480, dotted: true), 180);
    });
  });

  group('PassageBuilder', () {
    test('un constructeur vide ne produit pas de passage', () {
      final PassageBuilder b = PassageBuilder();
      expect(b.isEmpty, isTrue);
      expect(b.build, throwsStateError);
    });

    test('les onsets sont le cumul des durees precedentes', () {
      final PassageBuilder b = PassageBuilder();
      b.add(67, NoteValue.quarter);
      b.add(69, NoteValue.eighth);
      b.add(71, NoteValue.eighth);

      expect(
        b.notes.map((ScoreNote n) => n.onsetTicks).toList(),
        <int>[0, 480, 720],
      );
      expect(b.totalTicks, 960);
    });

    test('les mesures se deduisent de l onset et du chiffrage', () {
      final PassageBuilder b = PassageBuilder(
        beatsPerMeasure: 4,
        firstMeasure: 12,
      );
      // Quatre noires remplissent la mesure 12, la cinquieme ouvre la 13.
      for (int i = 0; i < 5; i++) {
        b.add(67, NoteValue.quarter);
      }
      expect(
        b.notes.map((ScoreNote n) => n.measure).toList(),
        <int>[12, 12, 12, 12, 13],
      );
      expect(b.lastMeasure, 13);
    });

    test('un chiffrage a trois temps change la barre de mesure', () {
      final PassageBuilder b = PassageBuilder(
        beatsPerMeasure: 3,
        firstMeasure: 1,
      );
      for (int i = 0; i < 4; i++) {
        b.add(67, NoteValue.quarter);
      }
      expect(
        b.notes.map((ScoreNote n) => n.measure).toList(),
        <int>[1, 1, 1, 2],
      );
    });

    test('une note a cheval sur la barre appartient a sa mesure de depart', () {
      final PassageBuilder b = PassageBuilder(beatsPerMeasure: 4);
      b.add(67, NoteValue.half); // temps 1-2
      b.add(69, NoteValue.half); // temps 3-4
      b.add(71, NoteValue.whole); // ouvre la mesure 2 et deborde sur la 3
      expect(b.notes.last.measure, 2);
    });

    test('annuler la derniere note rend les ticks', () {
      final PassageBuilder b = PassageBuilder();
      b.add(67, NoteValue.quarter);
      b.add(69, NoteValue.quarter);
      b.removeLast();

      expect(b.noteCount, 1);
      expect(b.totalTicks, 480);

      // La note suivante reprend exactement la place liberee.
      b.add(71, NoteValue.quarter);
      expect(b.notes.last.onsetTicks, 480);
    });

    test('annuler sur un constructeur vide ne leve rien', () {
      final PassageBuilder b = PassageBuilder();
      expect(b.removeLast, returnsNormally);
      expect(b.isEmpty, isTrue);
    });

    test('le titre par defaut reprend le vocabulaire de la partition', () {
      final PassageBuilder b = PassageBuilder(firstMeasure: 12);
      b.add(67, NoteValue.whole);
      expect(b.suggestedTitle, 'Mesure 12');

      b.add(69, NoteValue.whole);
      expect(b.suggestedTitle, 'Mesures 12 a 13');
      expect(b.build().title, 'Mesures 12 a 13');
    });

    test('un titre saisi l emporte, un titre blanc non', () {
      final PassageBuilder b = PassageBuilder(firstMeasure: 4);
      b.add(67, NoteValue.quarter);
      expect(b.build(title: 'Gavotte').title, 'Gavotte');
      expect(b.build(title: '   ').title, 'Mesure 4');
    });

    test('le passage construit est detache du constructeur', () {
      final PassageBuilder b = PassageBuilder();
      b.add(67, NoteValue.quarter);
      final Passage p = b.build();

      b.add(69, NoteValue.quarter);
      expect(p.noteCount, 1, reason: 'le passage rendu ne doit pas bouger');
      expect(b.noteCount, 2);
    });

    test('le passage produit alimente le boucleur', () {
      final PassageBuilder b = PassageBuilder(firstMeasure: 12);
      // Huit croches conjointes : de quoi declencher les variations
      // rythmiques, qui exigent une suite de notes de meme duree.
      for (final int midi in <int>[67, 69, 71, 72, 74, 72, 71, 69]) {
        b.add(midi, NoteValue.eighth);
      }
      final Passage p = b.build(writtenTempoBpm: 92);

      expect(p.noteCount, 8);
      expect(p.hasEvenRun(), isTrue);
      expect(p.lowestMidi, 67);
      expect(p.highestMidi, 74);
      expect(p.writtenTempoBpm, 92);
      expect(p.measureCount, 1);
    });
  });
}
