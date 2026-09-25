import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';

void main() {
  group('NoteValue.exactly', () {
    test('retrouve les figures simples', () {
      expect(NoteValue.exactly(480, 480)?.value, NoteValue.quarter);
      expect(NoteValue.exactly(480, 480)?.dotted, isFalse);
      expect(NoteValue.exactly(1920, 480)?.value, NoteValue.whole);
      expect(NoteValue.exactly(120, 480)?.value, NoteValue.sixteenth);
    });

    test('retrouve les figures pointees', () {
      expect(NoteValue.exactly(720, 480)?.value, NoteValue.quarter);
      expect(NoteValue.exactly(720, 480)?.dotted, isTrue);
      expect(NoteValue.exactly(360, 480)?.value, NoteValue.eighth);
      expect(NoteValue.exactly(360, 480)?.dotted, isTrue);
    });

    test('rend null sur une duree qui n est aucune figure', () {
      // Une noire et demie n existe pas : c est une blanche pointee ou rien.
      expect(NoteValue.exactly(600, 480), isNull);
      expect(NoteValue.exactly(0, 480), isNull);
      expect(NoteValue.exactly(3840, 480), isNull);
    });

    test('aucune duree ne designe deux figures differentes', () {
      final Map<int, String> vues = <int, String>{};
      for (final NoteValue value in NoteValue.values) {
        for (final bool dotted in <bool>[false, true]) {
          final int ticks = value.ticksIn(480, dotted: dotted);
          expect(vues.containsKey(ticks), isFalse,
              reason: '$ticks ticks : ${value.name} et ${vues[ticks]}');
          vues[ticks] = value.name;
        }
      }
    });
  });
}
