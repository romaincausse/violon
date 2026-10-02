import 'accompaniment.dart';

/// Ce qu'un haut-parleur de telephone peut rendre (ADR-017).
///
/// Une basse d'accompagnement s'ecrit a l'octave du violoncelle : mi2, sol2,
/// 80 a 120 Hz. Un haut-parleur de telephone ne descend pas la : il n'en sort
/// qu'un vrombissement, et le fondement de l'harmonie manque. Au casque, rien
/// a changer ; sur le haut-parleur, on remonte d'une octave ce qui passe
/// dessous, comme un pianiste qui jouerait sur un piano sans basses.
class SpeakerVoicing {
  const SpeakerVoicing._();

  /// En dessous, le haut-parleur du S22 ne rend plus la fondamentale : do3,
  /// 131 Hz. Entendu, pas calcule.
  static const int floorMidi = 48;

  /// Les [notes], celles sous [floor] remontees par octaves.
  static List<AccompanimentNote> raise(
    List<AccompanimentNote> notes, {
    int floor = floorMidi,
  }) =>
      <AccompanimentNote>[
        for (final AccompanimentNote n in notes)
          n.midi >= floor
              ? n
              : AccompanimentNote(
                  midi: n.midi + 12 * ((floor - n.midi + 11) ~/ 12),
                  onsetTicks: n.onsetTicks,
                  durationTicks: n.durationTicks,
                  velocity: n.velocity,
                ),
      ];
}
