import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/demo_passage.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/practice/variation.dart';
import 'package:violon/core/practice/variation_generator.dart';

Passage unevenPassage() {
  return Passage(
    title: 'rythme irregulier',
    ticksPerBeat: 480,
    notes: <ScoreNote>[
      const ScoreNote(
          id: 'a', midi: 67, onsetTicks: 0, durationTicks: 480, measure: 1),
      const ScoreNote(
          id: 'b', midi: 69, onsetTicks: 480, durationTicks: 240, measure: 1),
      const ScoreNote(
          id: 'c', midi: 71, onsetTicks: 720, durationTicks: 720, measure: 1),
    ],
  );
}

void main() {
  const VariationGenerator generator = VariationGenerator();

  group('applicableTo', () {
    test('propose les variations rythmiques sur des notes egales', () {
      final List<Variation> variations =
          generator.applicableTo(buildDemoPassage());
      expect(
        variations.any((Variation v) => v.kind == VariationKind.rhythm),
        isTrue,
      );
    });

    test('ecarte les variations rythmiques sur un rythme deja irregulier', () {
      final List<Variation> variations =
          generator.applicableTo(unevenPassage());
      expect(
        variations.any((Variation v) => v.kind == VariationKind.rhythm),
        isFalse,
      );
    });

    test('ecarte la segmentation sur un passage trop court', () {
      final List<Variation> variations =
          generator.applicableTo(unevenPassage());
      expect(
        variations.any((Variation v) => v.kind == VariationKind.segmentation),
        isFalse,
      );
    });

    test('ne produit jamais deux fois le meme identifiant', () {
      final List<Variation> variations =
          generator.applicableTo(buildDemoPassage());
      final Set<String> ids = variations.map((Variation v) => v.id).toSet();
      expect(ids.length, variations.length);
    });

    test('mentionne la note la plus aigue dans la consigne d\'ecoute', () {
      final List<Variation> variations =
          generator.applicableTo(buildDemoPassage());
      final Variation listen =
          variations.firstWhere((Variation v) => v.id == 'listen_intonation');
      expect(listen.instruction, contains('Re5'));
    });
  });

  group('buildSession', () {
    test('produit exactement le nombre de tours demande', () {
      expect(
        generator.buildSession(buildDemoPassage(), rounds: 10, seed: 1).length,
        10,
      );
    });

    test('termine toujours au tempo ecrit', () {
      final List<Variation> session =
          generator.buildSession(buildDemoPassage(), rounds: 10, seed: 42);
      expect(session.last.id, VariationGenerator.asWritten.id);
    });

    test('est deterministe a graine egale', () {
      final List<Variation> a =
          generator.buildSession(buildDemoPassage(), rounds: 10, seed: 7);
      final List<Variation> b =
          generator.buildSession(buildDemoPassage(), rounds: 10, seed: 7);
      expect(
        a.map((Variation v) => v.id),
        b.map((Variation v) => v.id),
      );
    });

    test('ne repete jamais la meme variation deux tours de suite', () {
      for (int seed = 0; seed < 30; seed++) {
        final List<Variation> session = generator.buildSession(
          buildDemoPassage(),
          rounds: 20,
          seed: seed,
        );
        for (int i = 1; i < session.length - 1; i++) {
          expect(
            session[i].id == session[i - 1].id,
            isFalse,
            reason: 'doublon consecutif au tour $i (graine $seed)',
          );
        }
      }
    });

    test('gere une session d\'un seul tour', () {
      final List<Variation> session =
          generator.buildSession(buildDemoPassage(), rounds: 1);
      expect(session, <Variation>[VariationGenerator.asWritten]);
    });

    test('refuse un nombre de tours invalide', () {
      expect(
        () => generator.buildSession(buildDemoPassage(), rounds: 0),
        throwsArgumentError,
      );
    });
  });
}
