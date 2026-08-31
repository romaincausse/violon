import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/score_cursor.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';

void main() {
  /// Quatre noires, a 60 bpm : une note par seconde.
  Passage quatreNoires() {
    final PassageBuilder b = PassageBuilder();
    for (final int midi in <int>[67, 69, 71, 72]) {
      b.add(midi, NoteValue.quarter);
    }
    return b.build();
  }

  group('ScoreCursor', () {
    test('a 60 bpm, une noire passe en une seconde', () {
      final ScoreCursor c = ScoreCursor(
        passage: quatreNoires(),
        tempoBpm: 60,
      );
      expect(c.tickAt(Duration.zero), 0);
      expect(c.tickAt(const Duration(seconds: 1)), 480);
      expect(c.tickAt(const Duration(seconds: 2)), 960);
    });

    test('le curseur reste sur la note tant qu elle dure', () {
      final ScoreCursor c = ScoreCursor(
        passage: quatreNoires(),
        tempoBpm: 60,
      );
      // Il ne saute pas d'une attaque a l'autre : c'est la note tenue qu'on
      // veut colorer.
      expect(c.noteIndexAt(const Duration(milliseconds: 10)), 0);
      expect(c.noteIndexAt(const Duration(milliseconds: 990)), 0);
      expect(c.noteIndexAt(const Duration(milliseconds: 1010)), 1);
      expect(c.noteIndexAt(const Duration(milliseconds: 3500)), 3);
    });

    test('avant le depart, on est sur la premiere note', () {
      final ScoreCursor c = ScoreCursor(
        passage: quatreNoires(),
        tempoBpm: 60,
      );
      expect(c.noteIndexAt(const Duration(seconds: -2)), 0);
      expect(c.tickAt(const Duration(seconds: -2)), 0);
    });

    test('apres la derniere note, il n y a plus de note courante', () {
      final ScoreCursor c = ScoreCursor(
        passage: quatreNoires(),
        tempoBpm: 60,
      );
      expect(c.isFinishedAt(const Duration(milliseconds: 3999)), isFalse);
      expect(c.noteIndexAt(const Duration(milliseconds: 3999)), 3);

      expect(c.isFinishedAt(const Duration(seconds: 4)), isTrue);
      expect(c.noteIndexAt(const Duration(seconds: 4)), isNull);
    });

    test('la duree totale suit le tempo', () {
      expect(
        ScoreCursor(passage: quatreNoires(), tempoBpm: 60).totalDuration,
        const Duration(seconds: 4),
      );
      expect(
        ScoreCursor(passage: quatreNoires(), tempoBpm: 120).totalDuration,
        const Duration(seconds: 2),
      );
    });

    test('un tempo non divisible ne fait pas deriver le curseur', () {
      // Meme piege que le metronome : a 92 bpm aucune duree entiere ne
      // represente un temps. Le calcul passe par le rationnel exact.
      final ScoreCursor c = ScoreCursor(
        passage: quatreNoires(),
        tempoBpm: 92,
      );
      // Au bout de la duree totale exacte, on est pile a la fin.
      expect(c.isFinishedAt(c.totalDuration), isTrue);
      expect(
        c.isFinishedAt(c.totalDuration - const Duration(milliseconds: 5)),
        isFalse,
      );
    });

    test('un passage qui ne commence pas a zero reste aligne', () {
      // Un passage saisi a partir de la mesure 12 commence quand meme a
      // l'onset 0 dans son propre repere : le curseur ne doit pas decaler.
      final PassageBuilder b = PassageBuilder(firstMeasure: 12);
      b.add(67, NoteValue.half);
      b.add(69, NoteValue.half);
      final ScoreCursor c = ScoreCursor(passage: b.build(), tempoBpm: 60);

      expect(c.noteIndexAt(const Duration(seconds: 1)), 0);
      expect(c.noteIndexAt(const Duration(seconds: 3)), 1);
      expect(c.totalDuration, const Duration(seconds: 4));
    });
  });
}
