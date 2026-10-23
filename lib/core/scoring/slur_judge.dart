import '../follow/offline_aligner.dart';
import '../follow/performance_features.dart';
import '../music/finger_pattern.dart';
import '../music/hand_positions.dart';
import '../music/passage.dart';
import '../music/score_note.dart';

/// Les liaisons respectees (lot K8) : sous une liaison, l'archet ne change
/// pas.
///
/// **Un changement d'archet est un creux d'energie, pas une attaque.** Sous
/// une liaison, changer de note fait aussi une attaque du flux spectral ; ce
/// qui casse la liaison, c'est l'archet qui s'arrete et repart. Sur le banc,
/// la meme gamme jouee liee (prise 02) et detachee (prise 01) le montre : les
/// creux des notes liees font 3,6 et 4,4 dB, ceux des notes detachees 6 a
/// 11. Au-dela de [breakDb], la liaison est cassee.
///
/// **Un changement de corde sous une liaison n'est pas jugee** : l'archet
/// passe d'une corde a l'autre, l'energie bouge, et rien ne dit qu'il a
/// change de sens.
///
/// **On juge les liaisons cassees, pas l'inverse.** Une note detachee
/// entendue liee demanderait de prouver une absence de creux, et le detecteur
/// en manque un sur quatre : ce serait accuser sur un silence de la mesure.
class SlurJudge {
  const SlurJudge._();

  /// Un creux plus profond est un changement d'archet.
  static const double breakDb = 6;

  /// Autour du debut de la note, la ou le changement d'archet tombe.
  static const int windowMs = 120;

  /// Les notes liees ou l'archet a change, dans l'ordre du passage.
  static List<ScoreNote> broken({
    required Passage passage,
    required Set<String> slurredInto,
    required Alignment alignment,
    required List<FeatureFrame> frames,
  }) {
    if (slurredInto.isEmpty) {
      return const <ScoreNote>[];
    }
    // Le debut de chaque note, a sa premiere trame.
    final Map<String, int> debuts = <String, int>{};
    for (int t = 0; t < alignment.frameNotes.length; t++) {
      final String? id = alignment.frameNotes[t];
      if (id != null && !debuts.containsKey(id)) {
        debuts[id] = alignment.frameTimesMs[t];
      }
    }
    final Map<String, FingerPlacement?> mains = HandPositions.of(passage);
    final List<ScoreNote> cassees = <ScoreNote>[];
    for (int i = 1; i < passage.notes.length; i++) {
      final ScoreNote n = passage.notes[i];
      final int? debut = debuts[n.id];
      if (!slurredInto.contains(n.id) || debut == null) {
        continue;
      }
      final int? corde = mains[n.id]?.stringMidi;
      final int? avant = mains[passage.notes[i - 1].id]?.stringMidi;
      if (corde != null && avant != null && corde != avant) {
        continue;
      }
      final bool creux = frames.any(
        (FeatureFrame f) =>
            (f.timeMs - debut).abs() <= windowMs &&
            (f.bowDipDb ?? 0) >= breakDb,
      );
      if (creux) {
        cassees.add(n);
      }
    }
    return cassees;
  }
}
