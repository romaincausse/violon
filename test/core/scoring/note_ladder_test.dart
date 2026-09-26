import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/scoring/note_ladder.dart';

void main() {
  group('NoteLadder', () {
    test('elle ne contient que les notes de l exercice', () {
      // Pas un clavier chromatique : sur un motif la-re, deux barreaux, et
      // entre eux le vide qui les separe vraiment.
      final NoteLadder echelle = NoteLadder(notes: <int>[69, 62, 69]);
      expect(echelle.steps, <int>[62, 69]);
    });

    test('l echelle laisse de l air au-dessus et en dessous', () {
      // Sans marge, le barreau le plus haut collerait au bord et son
      // contenant serait coupe en deux.
      final NoteLadder echelle = NoteLadder(notes: <int>[62, 69]);
      expect(echelle.lowMidi, 61);
      expect(echelle.highMidi, 70);
    });

    test('une seule note garde une echelle mesurable', () {
      // Sans etendue minimale, la hauteur de l'echelle serait nulle -- et la
      // division qui place le trait, impossible.
      final NoteLadder echelle = NoteLadder(notes: <int>[69]);
      expect(echelle.highMidi - echelle.lowMidi, greaterThanOrEqualTo(3));
      expect(echelle.fractionOf(69), closeTo(0.5, 0.001));
    });

    test('le grave est en bas, l aigu en haut', () {
      final NoteLadder echelle = NoteLadder(notes: <int>[62, 69]);
      expect(echelle.fractionOf(62), lessThan(echelle.fractionOf(69)));
      expect(echelle.fractionOf(61), 0);
      expect(echelle.fractionOf(70), 1);
    });

    test('une erreur d octave se colle au bord, sans sortir du cadre', () {
      // On voit d'un coup qu'on n'est pas du tout sur la note, sans avoir a
      // lire un chiffre.
      final NoteLadder echelle = NoteLadder(notes: <int>[62, 69]);
      expect(echelle.fractionOf(81), 1);
      expect(echelle.fractionOf(50), 0);
    });

    test('un barreau est atteint quand on est dedans', () {
      // Le barreau vaut le meme bareme que le verdict en direct : s'il ne le
      // valait plus, il mentirait a l'oeil.
      final NoteLadder echelle = NoteLadder(notes: <int>[62, 69]);
      expect(echelle.reachedBy(69), 69);
      expect(echelle.reachedBy(69.3), 69, reason: '30 cents au-dessus');
      expect(echelle.reachedBy(68.6), isNull, reason: '40 cents en dessous');
    });

    test('entre deux barreaux, on ne nomme rien', () {
      // Dire "presque un do" serait inventer une note que personne n'a jouee.
      final NoteLadder echelle = NoteLadder(notes: <int>[62, 69]);
      expect(echelle.reachedBy(65.5), isNull);
      expect(echelle.nearest(65.5), isNotNull);
    });

    test('elle sait rester vide', () {
      final NoteLadder echelle = NoteLadder(notes: <int>[]);
      expect(echelle.isEmpty, isTrue);
      expect(echelle.reachedBy(69), isNull);
      expect(echelle.highMidi, greaterThan(echelle.lowMidi));
    });
  });
}
