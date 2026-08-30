import 'dart:math';

import '../music/passage.dart';
import '../music/pitch_utils.dart';
import 'variation.dart';

/// Construit la liste des variations applicables a un passage, puis en tire
/// une session melangee.
///
/// Le melange est volontaire : l'enfant ne sait pas ce qui l'attend au tour
/// suivant, ce qui suffit a casser la monotonie. La graine est injectable
/// pour que les tests soient deterministes.
class VariationGenerator {
  const VariationGenerator();

  /// Variation finale imposee : on termine toujours au tempo ecrit, comme
  /// sur la partition, pour sentir que le passage est devenu facile.
  static const Variation asWritten = Variation(
    id: 'as_written',
    kind: VariationKind.tempo,
    label: 'Au tempo, comme ecrit',
    instruction: 'Le vrai tempo. Tu vas voir, ca passe tout seul maintenant.',
  );

  /// Toutes les variations pertinentes pour ce passage.
  List<Variation> applicableTo(Passage passage) {
    final List<Variation> variations = <Variation>[
      const Variation(
        id: 'legato',
        kind: VariationKind.articulation,
        label: 'Tout lie',
        instruction: 'Un seul archet, le son ne s\'arrete jamais.',
        tempoFactor: 0.9,
      ),
      const Variation(
        id: 'detache',
        kind: VariationKind.articulation,
        label: 'Detache',
        instruction: 'Un coup d\'archet par note, archet entier.',
      ),
      const Variation(
        id: 'staccato',
        kind: VariationKind.articulation,
        label: 'Staccato',
        instruction: 'Notes courtes et nettes, archet qui s\'arrete.',
        tempoFactor: 0.9,
      ),
      const Variation(
        id: 'tempo_slow',
        kind: VariationKind.tempo,
        label: 'Au ralenti',
        instruction: 'Tres lent. Chaque note doit etre parfaite.',
        tempoFactor: 0.7,
      ),
      const Variation(
        id: 'tempo_push',
        kind: VariationKind.tempo,
        label: 'Un cran plus vite',
        instruction: 'Un peu au-dessus de ton tempo. Ose.',
        tempoFactor: 1.15,
      ),
      Variation(
        id: 'listen_intonation',
        kind: VariationKind.attention,
        label: 'Oreille',
        instruction:
            'Ecoute la justesse du ${PitchUtils.noteName(passage.highestMidi)}.',
      ),
      const Variation(
        id: 'watch_bow',
        kind: VariationKind.attention,
        label: 'Archet',
        instruction: 'Regarde ton archet : reste-t-il droit ?',
      ),
      const Variation(
        id: 'eyes_closed',
        kind: VariationKind.attention,
        label: 'Les yeux fermes',
        instruction: 'Sans regarder. Fie-toi a ton oreille et a ta main.',
        tempoFactor: 0.8,
      ),
      const Variation(
        id: 'open_string_rhythm',
        kind: VariationKind.technique,
        label: 'Rythme seul',
        instruction: 'Le rythme sur une corde a vide, sans la main gauche.',
      ),
      const Variation(
        id: 'left_hand_only',
        kind: VariationKind.technique,
        label: 'Main gauche seule',
        instruction: 'Sans archet. Les doigts tombent bien en place ?',
        tempoFactor: 0.8,
      ),
    ];

    // Les variations rythmiques n'ont de sens que sur des notes egales.
    if (passage.hasEvenRun()) {
      variations.addAll(const <Variation>[
        Variation(
          id: 'dotted',
          kind: VariationKind.rhythm,
          label: 'Rythme pointe',
          instruction: 'Long - court, long - court.',
          durationPattern: <double>[1.5, 0.5],
          tempoFactor: 0.9,
        ),
        Variation(
          id: 'reverse_dotted',
          kind: VariationKind.rhythm,
          label: 'Pointe inverse',
          instruction: 'Court - long, court - long.',
          durationPattern: <double>[0.5, 1.5],
          tempoFactor: 0.9,
        ),
        Variation(
          id: 'group_of_three',
          kind: VariationKind.rhythm,
          label: 'Par trois',
          instruction: 'Trois notes rapides, puis une longue. Et on repart.',
          durationPattern: <double>[0.5, 0.5, 0.5, 1.5],
          tempoFactor: 0.9,
        ),
      ]);
    }

    // La segmentation demande un passage assez long pour etre decoupe.
    if (passage.noteCount >= 5) {
      final int half = (passage.noteCount / 2).ceil();
      variations.addAll(<Variation>[
        Variation(
          id: 'first_half',
          kind: VariationKind.segmentation,
          label: 'Le debut seulement',
          instruction: 'Juste les $half premieres notes.',
          noteStart: 0,
          noteCount: half,
        ),
        Variation(
          id: 'from_the_end',
          kind: VariationKind.segmentation,
          label: 'Par la fin',
          instruction:
              'Les $half dernieres notes. On finit toujours en terrain connu.',
          noteStart: passage.noteCount - half,
          noteCount: half,
        ),
      ]);
    }

    return variations;
  }

  /// Compose une session de [rounds] tours.
  ///
  /// Le dernier tour est toujours [asWritten]. Si le passage offre moins de
  /// variations que de tours, on recycle sans jamais repeter deux fois de
  /// suite la meme.
  List<Variation> buildSession(
    Passage passage, {
    int rounds = 10,
    int? seed,
  }) {
    if (rounds < 1) {
      throw ArgumentError.value(rounds, 'rounds', 'doit etre >= 1');
    }
    if (rounds == 1) {
      return <Variation>[asWritten];
    }

    final Random random = seed == null ? Random() : Random(seed);
    final List<Variation> pool = applicableTo(passage);
    final List<Variation> session = <Variation>[];

    List<Variation> remaining = <Variation>[];
    while (session.length < rounds - 1) {
      if (remaining.isEmpty) {
        remaining = List<Variation>.of(pool)..shuffle(random);
        // Evite de rejouer la meme variation a cheval sur deux tirages.
        if (session.isNotEmpty &&
            remaining.length > 1 &&
            remaining.first.id == session.last.id) {
          final Variation first = remaining.removeAt(0);
          remaining.add(first);
        }
      }
      session.add(remaining.removeAt(0));
    }

    session.add(asWritten);
    return session;
  }
}
