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

  /// Le tempo dans l'unite du temps battu, pour l'afficher et le battre.
  /// Sans chiffrage, c'est le tempo a la noire.
  int get pulseBpm =>
      meter?.pulseBpm(writtenTempoBpm, ticksPerBeat) ?? writtenTempoBpm;

  /// Temps battus par mesure, ou `null` sans chiffrage.
  int? get pulsesPerMeasure => meter?.pulsesPerMeasure(ticksPerBeat);

  /// L'indication de tempo telle qu'elle s'ecrit : "92 bpm" a la noire,
  /// "noire pointee = 94" quand le temps battu est une autre figure.
  String get tempoText {
    final Meter? m = meter;
    if (m == null || m.beatTicks(ticksPerBeat) == ticksPerBeat) {
      return '$writtenTempoBpm bpm';
    }
    return '${m.pulseName(ticksPerBeat)} = $pulseBpm';
  }

  /// Le meme passage, a un autre tempo exprime en temps battus.
  ///
  /// **Ralentir un passage ne change que son tempo** : les notes, les mesures
  /// et la gravure restent celles du papier. C'est ce que fait un metronome
  /// qu'on regle plus bas, pas une autre partition.
  Passage withPulseBpm(int pulse) =>
      withTempoBpm(meter?.quarterBpm(pulse, ticksPerBeat) ?? pulse);

  /// Le meme passage a un autre tempo, a la noire : pour relire un tempo
  /// range, sans l'aller-retour par les temps battus qui l'arrondirait.
  Passage withTempoBpm(int quarterBpm) => Passage(
        title: title,
        notes: notes,
        ticksPerBeat: ticksPerBeat,
        writtenTempoBpm: quarterBpm,
        meter: meter,
        keyFifths: keyFifths,
        bars: bars,
      );

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

  /// Le meme passage, reduit a [subset] : chiffrage, armure et tempo suivent.
  ///
  /// Les mesures gardees sont celles que ces notes **touchent dans le
  /// temps**, pas celles dont elles portent le numero : une note liee
  /// par-dessus la barre emmene la mesure suivante avec elle. [alsoBars]
  /// ajoute des mesures sans note, pour un extrait qui finit sur un silence.
  Passage withNotes(
    List<ScoreNote> subset, {
    String? title,
    bool Function(Bar bar)? alsoBars,
  }) {
    final List<Bar>? toutes = bars;
    int debut = subset.first.onsetTicks;
    int fin = subset.first.offsetTicks;
    for (final ScoreNote n in subset) {
      if (n.onsetTicks < debut) {
        debut = n.onsetTicks;
      }
      if (n.offsetTicks > fin) {
        fin = n.offsetTicks;
      }
    }
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
                if ((b.startTicks < fin && b.endTicks > debut) ||
                    (alsoBars?.call(b) ?? false))
                  b,
            ],
    );
  }
}
