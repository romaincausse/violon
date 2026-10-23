import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/music/finger_pattern.dart';
import 'package:violon/core/music/hand_positions.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';

/// Trois octaves (lot K6).
void main() {
  /// La position de chaque note, lue par la main (K3) sur le doigte ecrit.
  List<int> positions(String id) {
    final Passage p = ExerciseCatalog.byId(id)!.toPassage();
    final Map<String, FingerPlacement?> mains = HandPositions.of(p);
    return <int>[for (final ScoreNote n in p.notes) mains[n.id]!.position];
  }

  test('chaque note a son doigt, et le doigte tient dans la main', () {
    for (final Exercise e in ExerciseCatalog.ofPalier(9)) {
      final ScaleExercise g = e as ScaleExercise;
      expect(g.fingers, hasLength(g.midis.length), reason: g.id);
      final Passage p = g.toPassage();
      final Map<String, FingerPlacement?> mains = HandPositions.of(p);
      for (final ScoreNote n in p.notes) {
        expect(mains[n.id], isNotNull, reason: '${g.id} ${n.id}');
        expect('${mains[n.id]!.finger}', n.fingering,
            reason: '${g.id} ${n.id}');
      }
    }
  });

  test('la gamme monte en premiere, troisieme, sixieme, et redescend', () {
    final List<int> p = positions('gamme-sol-majeur-3');
    expect(p.sublist(15, 18), <int>[3, 3, 3], reason: 'la5 si5 do6');
    expect(p.sublist(18, 22), <int>[6, 6, 6, 6], reason: 're6 a sol6');
    expect(p.last, 1);
    // Les cordes a vide sont en premiere ; les autres notes de la premiere
    // octave aussi.
    expect(p.take(15).every((int x) => x == 1), isTrue);
  });

  test('les demanches se jugent a l arrivee (K5)', () {
    final Passage p = ExerciseCatalog.byId('gamme-sol-majeur-3')!.toPassage();
    final Set<String> arrivees = HandPositions.shiftArrivals(p);
    // La5 et re6 en montant ; do6 et sol5 en descendant.
    expect(
      <int>[
        for (final ScoreNote n in p.notes)
          if (arrivees.contains(n.id)) n.midi,
      ],
      <int>[81, 86, 84, 79],
    );
  });

  test('le sol6 est le haut du catalogue', () {
    expect(
      ExerciseCatalog.all.map((Exercise e) => e.highestMidi).reduce(
            (int a, int b) => a > b ? a : b,
          ),
      ExerciseCatalog.plusAiguEnSixiemePosition,
    );
    expect(ExerciseCatalog.byId('gamme-sol-majeur-3')!.detail,
        contains('jusqu en 6e position'));
  });
}
