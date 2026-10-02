import 'accompaniment_plan.dart';

/// Ce qui separe une boite a musique d'un pianiste (ADR-017).
///
/// Un accord dont les trois notes partent au meme echantillon, a la meme
/// force, lues dans le meme enregistrement, sonne mecanique : rien n'y bouge.
/// Un pianiste egrene un accord de bas en haut sur quelques millisecondes, et
/// ne frappe jamais deux notes exactement pareil. On fait les deux, a peine :
/// l'oreille doit sentir une main, pas entendre un arpege.
///
/// **Deterministe.** Chaque ecart se tire d'un hachage de l'instant et de la
/// note, jamais de l'horloge ni d'un tirage : deux tours d'une boucle sonnent
/// pareil, et un test peut l'attendre. Une note seule garde son instant
/// exact -- c'est sur elle que le plan et les tests comptent.
class Humanizer {
  const Humanizer({
    this.rollMs = 6,
    this.maxRollMs = 18,
    this.velocitySpread = 0.06,
  });

  /// Retard d'une note d'accord sur celle du dessous.
  final int rollMs;

  /// Au-dela, un accord s'entend egrene : on n'y va pas, meme a six notes.
  final int maxRollMs;

  /// Variation de force, en part de la force ecrite : six pour cent, c'est a
  /// peine un demi-decibel.
  final double velocitySpread;

  List<TimedNote> apply(List<TimedNote> notes) {
    final Map<int, List<TimedNote>> parInstant = <int, List<TimedNote>>{};
    for (final TimedNote n in notes) {
      parInstant.putIfAbsent(n.at.inMicroseconds, () => <TimedNote>[]).add(n);
    }
    final List<TimedNote> sortie = <TimedNote>[];
    for (final List<TimedNote> accord in parInstant.values) {
      accord.sort((TimedNote a, TimedNote b) => a.midi.compareTo(b.midi));
      for (int i = 0; i < accord.length; i++) {
        final TimedNote n = accord[i];
        final int retard = (i * rollMs).clamp(0, maxRollMs);
        final double force =
            (n.velocity * (1 + velocitySpread * _bruit(n))).clamp(0.0, 1.0);
        sortie.add(
          TimedNote(
            at: n.at + Duration(milliseconds: retard),
            duration: n.duration,
            midi: n.midi,
            velocity: force,
          ),
        );
      }
    }
    sortie.sort((TimedNote a, TimedNote b) => a.at.compareTo(b.at));
    return sortie;
  }

  /// Entre -1 et 1, toujours le meme pour la meme note au meme instant.
  static double _bruit(TimedNote n) {
    int h = (n.at.inMicroseconds ^ (n.midi * 0x9E3779B1)) & 0xFFFFFFFF;
    h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0xFFFFFFFF;
    h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0xFFFFFFFF;
    h = h ^ (h >> 16);
    return (h & 0xFFFF) / 0xFFFF * 2 - 1;
  }
}
