import '../music/passage.dart';
import '../music/score_note.dart';
import 'live_tuning.dart';

/// Ce qu'on sait d'une mesure apres l'avoir entendue.
class MeasureScore {
  const MeasureScore({
    required this.measure,
    required this.score,
    required this.heardNotes,
    required this.noteCount,
  });

  /// Numero de mesure tel qu'il est imprime sur la partition.
  final int measure;

  /// Note sur cent, ou `null` si rien n'a ete entendu.
  final int? score;

  /// Notes de la mesure effectivement mesurees.
  final int heardNotes;

  /// Notes que la mesure contient.
  final int noteCount;

  bool get heard => score != null;

  /// Part de la mesure reellement entendue, entre 0 et 1.
  ///
  /// Un score etabli sur une note sur six ne vaut pas celui d'une mesure
  /// entendue en entier : l'affichage doit pouvoir faire la difference.
  double get coverage => noteCount == 0 ? 0 : heardNotes / noteCount;
}

/// Note chaque mesure du passage, a partir des notes deja entendues.
///
/// **La mesure est l'unite de travail d'un professeur.** C'est elle qu'on
/// designe, qu'on boucle et qu'on rejoue ; c'est donc elle qu'il faut savoir
/// noter, pas seulement la note isolee.
///
/// **Moyenne des notes entendues, sans compter les autres.** Compter pour
/// zero une note qu'on n'a pas entendue punirait un silence, un archet rate
/// ou un micro trop loin comme une fausse note -- la meme regle que pour le
/// score d'ensemble.
///
/// Les mesures sans aucune note entendue sont rendues quand meme, avec un
/// score nul : l'affichage a besoin de connaitre toutes les mesures du
/// passage, y compris celles qui restent a jouer.
List<MeasureScore> scoreByMeasure(Passage passage, LiveTuning tuning) {
  final Map<int, List<ScoreNote>> parMesure = <int, List<ScoreNote>>{};
  for (final ScoreNote note in passage.notes) {
    parMesure.putIfAbsent(note.measure, () => <ScoreNote>[]).add(note);
  }

  final List<MeasureScore> resultat = <MeasureScore>[];
  for (int mesure = passage.firstMeasure;
      mesure <= passage.lastMeasure;
      mesure++) {
    final List<ScoreNote> notes = parMesure[mesure] ?? const <ScoreNote>[];
    final List<int> notees = <int>[
      for (final ScoreNote n in notes)
        if (tuning.scoreFor(n.id) != null) tuning.scoreFor(n.id)!,
    ];
    resultat.add(
      MeasureScore(
        measure: mesure,
        score: notees.isEmpty
            ? null
            : (notees.reduce((int a, int b) => a + b) / notees.length).round(),
        heardNotes: notees.length,
        noteCount: notes.length,
      ),
    );
  }
  return resultat;
}
