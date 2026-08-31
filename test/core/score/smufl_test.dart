import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/score/smufl.dart';
import 'package:violon/core/score/stems_and_beams.dart';

void main() {
  group('Smufl', () {
    test('les points de code sont ceux de la norme SMuFL', () {
      // Verifies contre la specification SMuFL 1.4. Une erreur ici ne fait
      // pas planter l'application : elle affiche un autre symbole musical,
      // ce qui est bien plus difficile a reperer qu'un crash.
      expect(Smufl.gClef.codeUnitAt(0), 0xE050);
      expect(Smufl.noteheadWhole.codeUnitAt(0), 0xE0A2);
      expect(Smufl.noteheadHalf.codeUnitAt(0), 0xE0A3);
      expect(Smufl.noteheadBlack.codeUnitAt(0), 0xE0A4);
      expect(Smufl.accidentalSharp.codeUnitAt(0), 0xE262);
      expect(Smufl.augmentationDot.codeUnitAt(0), 0xE1E7);
      expect(Smufl.flag8thUp.codeUnitAt(0), 0xE240);
      expect(Smufl.flag8thDown.codeUnitAt(0), 0xE241);
      expect(Smufl.flag16thUp.codeUnitAt(0), 0xE242);
      expect(Smufl.flag16thDown.codeUnitAt(0), 0xE243);
    });

    test('la taille de police vaut quatre interlignes', () {
      expect(Smufl.fontSizeForSpace(10), 40);
      expect(Smufl.fontSizeForSpace(7.5), 30);
    });

    test('chaque figure a sa tete', () {
      expect(Smufl.noteheadFor(NoteHead.whole), Smufl.noteheadWhole);
      expect(Smufl.noteheadFor(NoteHead.half), Smufl.noteheadHalf);
      expect(Smufl.noteheadFor(NoteHead.filled), Smufl.noteheadBlack);
    });

    test('le crochet suit le sens de la hampe', () {
      expect(Smufl.flagFor(1, StemDirection.up), Smufl.flag8thUp);
      expect(Smufl.flagFor(1, StemDirection.down), Smufl.flag8thDown);
      expect(Smufl.flagFor(2, StemDirection.up), Smufl.flag16thUp);
      expect(Smufl.flagFor(2, StemDirection.down), Smufl.flag16thDown);
    });

    test('une note sans crochet n a pas de glyphe', () {
      expect(Smufl.flagFor(0, StemDirection.up), isNull);
      // Une ronde vaut -1 crochet : elle n'a meme pas de hampe.
      expect(Smufl.flagFor(-1, StemDirection.up), isNull);
    });

    test('au-dela de la double croche, on retombe sur la triple', () {
      // Le modele s'arrete a la double, mais une duree calculee peut
      // descendre plus bas. Mieux vaut un glyphe approche qu'aucun symbole.
      expect(Smufl.flagFor(4, StemDirection.up), Smufl.flag32ndUp);
    });
  });
}
