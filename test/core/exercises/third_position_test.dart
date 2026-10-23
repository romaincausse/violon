import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/music/finger_pattern.dart';
import 'package:violon/core/music/hand_positions.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';

/// Le catalogue en troisieme position (lot K4).
void main() {
  final List<Exercise> enTroisieme = ExerciseCatalog.ofPalier(7);

  test('un palier de plus apres le mineur, toutes familles', () {
    expect(ExerciseCatalog.palier(7).titre, 'La troisieme position');
    expect(enTroisieme.map((Exercise e) => e.genre).toSet(), <ExerciseKind>{
      ExerciseKind.motifDeDoigts,
      ExerciseKind.gamme,
      ExerciseKind.arpege,
    });
    expect(enTroisieme.every((Exercise e) => e.position == 3), isTrue);
  });

  test('la gamme de sol monte sur re et la, doigtee 1 2 3 4 1 2 3 4', () {
    final Passage p = ExerciseCatalog.byId('gamme-sol-majeur-3e')!.toPassage();
    expect(p.notes.take(8).map((ScoreNote n) => n.fingering),
        <String>['1', '2', '3', '4', '1', '2', '3', '4']);
    expect(p.notes.first.midi, 67);
    expect(p.keyFifths, 1);
    expect(ExerciseCatalog.byId('gamme-sol-majeur-3e')!.detail,
        contains('en 3e position'));
  });

  test('chaque note doigtee est lue en troisieme, sans rien deviner', () {
    for (final Exercise e in enTroisieme) {
      final Passage p = e.toPassage();
      final Map<String, FingerPlacement?> mains = HandPositions.of(p);
      for (final ScoreNote n in p.notes) {
        expect(n.fingering, isNotNull, reason: '${e.id} ${n.id}');
        final FingerPlacement? m = mains[n.id];
        expect(m, isNotNull, reason: '${e.id} ${n.id}');
        if (m!.finger > 0) {
          expect(m.position, 3, reason: '${e.id} ${n.id}');
          expect('${m.finger}', n.fingering, reason: '${e.id} ${n.id}');
        }
      }
    }
  });

  test('la premiere position n ecrit pas ses doigts', () {
    final Passage p = ExerciseCatalog.all.first.toPassage();
    expect(p.notes.every((ScoreNote n) => n.fingering == null), isTrue);
  });
}
