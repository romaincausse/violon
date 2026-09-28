import 'meter.dart';
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
    this.meter,
    this.keyFifths,
    this.bars,
  }) : assert(notes.isNotEmpty, 'un passage contient au moins une note');

  final String title;
  final List<ScoreNote> notes;

  /// Resolution temporelle : nombre de ticks pour une noire.
  final int ticksPerBeat;

  /// Tempo indique sur la partition, a la noire. Le dernier tour d'une
  /// session s'y fait.
  final int writtenTempoBpm;

  /// Chiffrage, s'il est connu. Un passage saisi ou un exercice genere n'en
  /// porte pas : la gravure groupe alors par noire, comme elle l'a toujours
  /// fait.
  final Meter? meter;

  /// Armure, en nombre de quintes : 2 pour re majeur, -1 pour fa majeur.
  ///
  /// `null` quand on ne la connait pas : la gravure ecrit alors chaque
  /// alteration devant sa note, ce qui est juste, seulement plus charge.
  final int? keyFifths;

  /// Les mesures, silences compris, quand on les connait.
  ///
  /// `null` pour un passage fait de notes jointives : les barres s'y deduisent
  /// d'un changement de numero de mesure. Un morceau importe les porte
  /// toujours, parce qu'une mesure de silence n'a aucune note pour la
  /// signaler.
  final List<Bar>? bars;

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
    return withNotes(notes.sublist(safeStart, safeEnd));
  }

  /// Le meme passage, reduit a [subset] : chiffrage, armure et tempo suivent,
  /// et seules les mesures que ces notes touchent sont gardees.
  Passage withNotes(List<ScoreNote> subset, {String? title}) {
    final List<Bar>? toutes = bars;
    return Passage(
      title: title ?? this.title,
      notes: subset,
      ticksPerBeat: ticksPerBeat,
      writtenTempoBpm: writtenTempoBpm,
      meter: meter,
      keyFifths: keyFifths,
      bars: toutes == null
          ? null
          : <Bar>[
              for (final Bar b in toutes)
                if (b.number >= subset.first.measure &&
                    b.number <= subset.last.measure &&
                    b.startTicks < subset.last.offsetTicks &&
                    b.endTicks > subset.first.onsetTicks)
                  b,
            ],
    );
  }
}
