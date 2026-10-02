import '../music/passage.dart';
import '../music/score_note.dart';
import 'alignment_report.dart';
import 'offline_aligner.dart';

/// Un endroit ou l'eleve ne joue pas la note suivante : il reprend, saute,
/// ou repart apres un arret ailleurs que la ou il s'etait arrete.
class Discontinuity {
  const Discontinuity({
    required this.timeMs,
    required this.noteId,
    required this.measure,
    required this.recoveryMs,
  });

  /// Debut de la premiere note jouee apres la rupture.
  final int timeMs;
  final String noteId;
  final int measure;

  /// Combien de temps le suiveur a mis a se retrouver dans la bonne mesure
  /// **et a y rester** [Reanchoring.holdMs], ou `null` s'il n'y est pas
  /// parvenu avant la rupture suivante.
  final int? recoveryMs;

  @override
  String toString() => 'Discontinuity(${timeMs}ms, $noteId m$measure, '
      '${recoveryMs == null ? 'jamais' : '${recoveryMs}ms'})';
}

/// Le re-ancrage (lot S3) : apres chaque rupture, combien de temps pour
/// retrouver sa place.
///
/// **La mesure qui manquait.** Le taux de notes bien placees dit si le
/// suiveur suit ; il ne dit pas s'il se perd longtemps a chaque reprise. Or
/// c'est le cas nominal d'un enfant qui travaille (ADR-009) : un suiveur qui
/// met trois mesures a comprendre qu'on a repris la mesure 8 colore trois
/// mesures de travers, a chaque fois.
class Reanchoring {
  Reanchoring._();

  /// Combien de temps le suiveur doit rester dans la bonne mesure pour qu'on
  /// le dise retrouve. Passer une trame dans la bonne mesure en allant
  /// ailleurs n'est pas se retrouver.
  static const int holdMs = 250;

  /// Les ruptures de [truth], et le delai de [alignment] pour chacune.
  static List<Discontinuity> measure(
    Alignment alignment,
    GroundTruth truth,
    Passage passage,
  ) {
    final Map<String, int> index = <String, int>{
      for (int i = 0; i < passage.notes.length; i++) passage.notes[i].id: i,
    };
    final Map<String, int> mesure = <String, int>{
      for (final ScoreNote n in passage.notes) n.id: n.measure,
    };
    final List<LabelledNote> jouees = <LabelledNote>[
      for (final LabelledNote l in truth.notes)
        if (l.noteId != null) l,
    ];
    final List<(int, String, int)> ruptures = <(int, String, int)>[];
    for (int k = 0; k < jouees.length; k++) {
      final int i = index[jouees[k].noteId]!;
      final bool suite = k > 0 &&
          (i == index[jouees[k - 1].noteId]! + 1 ||
              i == index[jouees[k - 1].noteId]!);
      if (!suite) {
        ruptures.add((jouees[k].timeMs, jouees[k].noteId!, k));
      }
    }

    final List<Discontinuity> sortie = <Discontinuity>[];
    for (int r = 0; r < ruptures.length; r++) {
      final (int debut, String id, int premiere) = ruptures[r];
      int k = premiere;
      final int fin = r + 1 < ruptures.length ? ruptures[r + 1].$1 : 1 << 30;
      int? delai;
      int? depuis;
      for (int t = 0; t < alignment.frameTimesMs.length; t++) {
        final int temps = alignment.frameTimesMs[t];
        if (temps < debut) {
          continue;
        }
        if (temps >= fin) {
          break;
        }
        final String? vue = alignment.frameNotes[t];
        if (vue == null) {
          // Un silence ne dit rien : il ne rompt ni ne confirme.
          continue;
        }
        // La mesure ou l'eleve est a cet instant : il a pu avancer depuis la
        // rupture, et le suiveur doit le retrouver la ou il est, pas la ou il
        // a repris.
        while (k + 1 < jouees.length && jouees[k + 1].timeMs <= temps) {
          k++;
        }
        if (mesure[vue] == mesure[jouees[k].noteId]) {
          depuis ??= temps;
          if (temps - depuis >= holdMs) {
            delai = depuis - debut;
            break;
          }
        } else {
          depuis = null;
        }
      }
      // Le passage s'acheve dans la bonne mesure avant le delai de tenue :
      // retrouve quand meme.
      if (delai == null && depuis != null) {
        delai = depuis - debut;
      }
      sortie.add(
        Discontinuity(
          timeMs: debut,
          noteId: id,
          measure: mesure[id]!,
          recoveryMs: delai,
        ),
      );
    }
    return sortie;
  }
}
