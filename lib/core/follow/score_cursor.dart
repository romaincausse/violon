import '../music/passage.dart';
import '../music/score_note.dart';

/// Curseur de lecture, pilote par l'horloge.
///
/// **Il avance sur le temps, pas sur ce qui est joue.** Le suivi adaptatif --
/// l'application qui attend la bonne note -- est un lot a part, et le plus
/// risque du projet. Ici le curseur est un metronome qui sait ou il en est
/// dans la partition : c'est suffisant pour montrer ou on devrait etre, et
/// c'est ce dont depend tout le retour visuel.
///
/// Comme [MetronomeClock], rien n'est accumule : la position se calcule
/// toujours depuis le temps absolu ecoule, sur le rationnel exact. Une
/// position obtenue par addition deriverait, et la derive se verrait sur la
/// partition.
class ScoreCursor {
  const ScoreCursor({required this.passage, required this.tempoBpm})
      : assert(tempoBpm > 0, 'un tempo est strictement positif');

  final Passage passage;
  final int tempoBpm;

  static const int _minuteUs = 60 * Duration.microsecondsPerSecond;

  /// Instant courant dans la partition, en ticks.
  int tickAt(Duration elapsed) {
    if (elapsed <= Duration.zero) {
      return passage.notes.first.onsetTicks;
    }
    final int depuisDebut =
        (elapsed.inMicroseconds * tempoBpm * passage.ticksPerBeat) ~/ _minuteUs;
    return passage.notes.first.onsetTicks + depuisDebut;
  }

  /// Duree totale du passage a ce tempo.
  ///
  /// Arrondie au **microseconde superieure**, pour que `isFinishedAt` soit
  /// vrai a cet instant precis. Une division tronquee tombait un tick avant
  /// la fin, et le curseur restait eternellement sur la derniere note a un
  /// tempo comme 92 bpm, ou aucune duree entiere ne represente un temps.
  Duration get totalDuration {
    final int ticks =
        passage.notes.last.offsetTicks - passage.notes.first.onsetTicks;
    final int diviseur = tempoBpm * passage.ticksPerBeat;
    return Duration(
      microseconds: (ticks * _minuteUs + diviseur - 1) ~/ diviseur,
    );
  }

  bool isFinishedAt(Duration elapsed) =>
      tickAt(elapsed) >= passage.notes.last.offsetTicks;

  /// Index de la note en cours, ou `null` une fois le passage termine.
  ///
  /// Une note est "en cours" de son attaque jusqu'a son relachement. Le
  /// curseur ne saute donc pas d'une note a l'autre : il reste sur la note
  /// tant qu'elle dure, ce qui est ce qu'on veut colorer.
  int? noteIndexAt(Duration elapsed) {
    final int tick = tickAt(elapsed);
    if (tick >= passage.notes.last.offsetTicks) {
      return null;
    }
    for (int i = passage.notes.length - 1; i >= 0; i--) {
      if (tick >= passage.notes[i].onsetTicks) {
        return i;
      }
    }
    return 0;
  }

  ScoreNote? noteAt(Duration elapsed) {
    final int? index = noteIndexAt(elapsed);
    return index == null ? null : passage.notes[index];
  }
}
