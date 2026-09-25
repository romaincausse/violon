import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/scale_pattern.dart';

void main() {
  group('ScalePattern', () {
    test('une octave de sol majeur monte et redescend', () {
      expect(
        ScalePattern.majeur.midis(tonicMidi: 55),
        <int>[
          55, 57, 59, 60, 62, 64, 66, 67, // sol la si do re mi fa# sol
          66, 64, 62, 60, 59, 57, 55,
        ],
      );
    });

    test('le sommet n est joue qu une fois', () {
      final List<int> notes = ScalePattern.majeur.midis(tonicMidi: 55);
      expect(notes.where((int m) => m == 67).length, 1);
    });

    test('deux octaves enchainent sans repeter la note de jonction', () {
      final List<int> notes =
          ScalePattern.majeur.midis(tonicMidi: 55, octaves: 2);
      expect(notes.first, 55);
      expect(notes[14], 79);
      expect(notes.last, 55);
      for (int i = 1; i < notes.length; i++) {
        expect(notes[i], isNot(notes[i - 1]),
            reason: 'deux notes identiques a la suite en position $i');
      }
    });

    test('sans retour, la gamme s arrete en haut', () {
      expect(
        ScalePattern.majeur.midis(tonicMidi: 62, retour: false),
        <int>[62, 64, 66, 67, 69, 71, 73, 74],
      );
    });

    test('noteCount annonce ce que midis produit', () {
      for (final ScalePattern pattern in ScalePattern.values) {
        for (final int octaves in <int>[1, 2]) {
          for (final bool retour in <bool>[false, true]) {
            expect(
              pattern.noteCount(octaves: octaves, retour: retour),
              pattern
                  .midis(tonicMidi: 55, octaves: octaves, retour: retour)
                  .length,
              reason: '$pattern $octaves octaves, retour $retour',
            );
          }
        }
      }
    });

    test('le mineur melodique descend par le mineur naturel', () {
      // La faute a ne pas commettre : redescendre la formule montante
      // afficherait un fa# et un mi becarre que le professeur n a pas
      // demandes, et l enfant se verrait compter faux ce qu il joue juste.
      final List<int> notes = ScalePattern.mineurMelodique.midis(tonicMidi: 57);
      expect(notes.sublist(0, 8), <int>[57, 59, 60, 62, 64, 66, 68, 69]);
      expect(notes.sublist(8), <int>[67, 65, 64, 62, 60, 59, 57]);
      expect(ScalePattern.mineurMelodique.asymetrique, isTrue);
    });

    test('les autres formules se descendent comme elles se montent', () {
      for (final ScalePattern pattern in ScalePattern.values) {
        if (pattern == ScalePattern.mineurMelodique) {
          continue;
        }
        expect(pattern.asymetrique, isFalse, reason: pattern.name);
        final List<int> notes = pattern.midis(tonicMidi: 60);
        expect(notes, notes.reversed.toList(), reason: pattern.name);
      }
    });

    test('le mineur harmonique a un ton et demi entre sixte et septieme', () {
      final List<int> degres = ScalePattern.mineurHarmonique.montee;
      expect(degres[6] - degres[5], 3);
    });

    test('les arpeges ne prennent que trois degres', () {
      expect(ScalePattern.arpegeMajeur.midis(tonicMidi: 55, octaves: 2),
          <int>[55, 59, 62, 67, 71, 74, 79, 74, 71, 67, 62, 59, 55]);
    });
  });
}
