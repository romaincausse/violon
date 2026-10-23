import '../follow/take_follower.dart';
import '../music/meter.dart';
import '../music/passage.dart';
import '../play/accompaniment_plan.dart';
import '../score/staff_layout.dart';
import 'work_loop.dart';

/// La dictee d'une mesure (lot L2) : l'application joue une mesure du
/// morceau, l'eleve la rejoue d'oreille.
///
/// Le solfege contextualise : pas une dictee de conservatoire sur une
/// melodie inconnue, mais une mesure de ce qu'il travaille, qu'il connait
/// deja par les yeux et qu'il apprend ici par l'oreille. **Mesure apres
/// mesure, dans l'ordre**, et on revient au debut quand le passage est
/// epuise.
///
/// Juger est strict ici aussi, mais sur une seule chose : les hauteurs. Le
/// rythme n'est pas le sujet d'une dictee de hauteurs, et une mesure rejouee
/// lentement est une mesure entendue.
class DictationDrill {
  DictationDrill({required this.passage, this.minTuning = 80})
      : _mesures = StaffLayout.barsOf(passage);

  final Passage passage;

  /// Justesse exigee, sur cent, pour que la mesure compte comme entendue.
  final int minTuning;

  final List<Bar> _mesures;
  int _index = 0;
  int _entendues = 0;

  /// La mesure en cours.
  int get measure => _mesures[_index].number;

  /// Combien de mesures ont ete rejouees juste depuis le debut.
  int get heard => _entendues;

  /// La mesure en cours, seule, telle que le suiveur l'attend.
  Passage get excerpt =>
      WorkLoop.excerpt(passage, BarSelection(measure, measure))!;

  /// Les notes a faire sonner, depuis le debut de la mesure, au tempo du
  /// passage.
  List<TimedNote> get notesToPlay {
    final Passage x = excerpt;
    final int debut = x.notes.first.onsetTicks;
    Duration ticks(int n) => Duration(
          microseconds:
              n * 60 * 1000000 ~/ (x.writtenTempoBpm * x.ticksPerBeat),
        );
    return <TimedNote>[
      for (final note in x.notes)
        TimedNote(
          at: ticks(note.onsetTicks - debut),
          duration: ticks(note.durationTicks),
          midi: note.midi,
          velocity: 0.8,
        ),
    ];
  }

  /// Duree de la mesure jouee.
  Duration get playingLength {
    final List<TimedNote> n = notesToPlay;
    return n.isEmpty ? Duration.zero : n.last.at + n.last.duration;
  }

  /// L'eleve a rejoue : la mesure est-elle entendue ? Si oui, on passe a la
  /// suivante.
  bool judge(TakeFollower essai) {
    // La note se calcule sur la prise entiere, archet pose (ADR-010).
    final int? justesse = essai.rescore().overallScore;
    final bool ok =
        essai.reachedEnd && justesse != null && justesse >= minTuning;
    if (ok) {
      _entendues++;
      _index = (_index + 1) % _mesures.length;
    }
    return ok;
  }

  /// Passer a la suivante sans l'avoir entendue : c'est son droit.
  void skip() => _index = (_index + 1) % _mesures.length;
}
