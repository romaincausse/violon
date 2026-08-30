import 'score_note.dart';

/// Un extrait de partition selectionne pour le travail en boucle.
///
/// Typiquement 2 a 4 mesures : c'est l'unite de travail du boucleur.
class Passage {
  Passage({
    required this.title,
    required this.notes,
    required this.ticksPerBeat,
    this.writtenTempoBpm = 80,
  }) : assert(notes.isNotEmpty, 'un passage contient au moins une note');

  final String title;
  final List<ScoreNote> notes;

  /// Resolution temporelle : nombre de ticks pour une noire.
  final int ticksPerBeat;

  /// Tempo indique sur la partition. Le dernier tour d'une session s'y fait.
  final int writtenTempoBpm;

  int get firstMeasure => notes.first.measure;
  int get lastMeasure => notes.last.measure;
  int get measureCount => lastMeasure - firstMeasure + 1;
  int get noteCount => notes.length;

  int get lowestMidi => notes
      .map((ScoreNote n) => n.midi)
      .reduce((int a, int b) => a < b ? a : b);
  int get highestMidi => notes
      .map((ScoreNote n) => n.midi)
      .reduce((int a, int b) => a > b ? a : b);

  /// Vrai si le passage contient au moins [minRun] notes consecutives de
  /// meme duree. C'est la condition pour appliquer une variation rythmique
  /// (pointe, groupes) : sur un rythme deja irregulier, ca n'a pas de sens.
  bool hasEvenRun({int minRun = 4}) {
    if (notes.length < minRun) {
      return false;
    }
    int run = 1;
    for (int i = 1; i < notes.length; i++) {
      if (notes[i].durationTicks == notes[i - 1].durationTicks) {
        run++;
        if (run >= minRun) {
          return true;
        }
      } else {
        run = 1;
      }
    }
    return false;
  }

  /// Sous-passage borne par les index de notes, utilise par la segmentation.
  Passage slice(int start, int count) {
    final int safeStart = start.clamp(0, notes.length - 1);
    final int safeEnd = (safeStart + count).clamp(safeStart + 1, notes.length);
    return Passage(
      title: title,
      notes: notes.sublist(safeStart, safeEnd),
      ticksPerBeat: ticksPerBeat,
      writtenTempoBpm: writtenTempoBpm,
    );
  }
}
