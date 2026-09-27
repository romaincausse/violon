import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/score/score_fit.dart';
import 'package:violon/core/score/score_layout.dart';

void main() {
  /// Un exercice de motif : [combien] mesures de quatre croches.
  Passage exercice(int combien) {
    final PassageBuilder b = PassageBuilder(beatsPerMeasure: 2);
    for (int i = 0; i < combien * 4; i++) {
      b.add(67 + (i % 8), NoteValue.eighth);
    }
    return b.build();
  }

  group('scoreFits', () {
    test('une mesure tient dans une boite large et haute', () {
      expect(
        scoreFits(exercice(1), widthSpaces: 60, heightSpaces: 30),
        isTrue,
      );
    });

    test('la largeur peut refuser a elle seule', () {
      // Deux mesures sur une ligne, dans une boite haute et etroite.
      expect(
        scoreFits(
          exercice(2),
          widthSpaces: 18,
          heightSpaces: 200,
          maxSystems: 1,
        ),
        isFalse,
      );
    });

    test('la hauteur peut refuser a elle seule', () {
      expect(
        scoreFits(exercice(4), widthSpaces: 300, heightSpaces: 6),
        isFalse,
      );
    });

    test('checkWidth relache la largeur, pour le mode defilement', () {
      // En defilement, deborder en largeur est le principe meme : c'est le
      // doigt qui parcourt la ligne.
      final Passage p = exercice(2);
      expect(
        scoreFits(p, widthSpaces: 10, heightSpaces: 40, maxSystems: 1),
        isFalse,
      );
      expect(
        scoreFits(
          p,
          widthSpaces: double.infinity,
          heightSpaces: 40,
          maxSystems: 1,
          checkWidth: false,
        ),
        isTrue,
      );
    });

    test('alsoCover peut faire refuser une boite qui passait', () {
      // La partition de ce qui a ete joue dessine en clair la hauteur ecrite :
      // la reserve doit la contenir, et elle peut ne plus tenir.
      final Passage p = exercice(1);
      final ScoreLayout l = ScoreLayout.of(p, maxWidthSpaces: 200);
      final double juste = SystemMetrics.of(l).stackHeightSpaces(l.systemCount);
      expect(scoreFits(p, widthSpaces: 200, heightSpaces: juste), isTrue);
      expect(
        scoreFits(
          p,
          widthSpaces: 200,
          heightSpaces: juste,
          alsoCover: const <int>[-30],
        ),
        isFalse,
      );
    });
  });
}
