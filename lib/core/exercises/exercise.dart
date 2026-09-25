import '../music/finger_pattern.dart';
import '../music/note_value.dart';
import '../music/passage.dart';
import '../music/passage_builder.dart';
import '../music/scale_pattern.dart';
import 'method_source.dart';

/// Ce qu'un exercice fait travailler.
enum ExerciseKind {
  motifDeDoigts('Motif de doigts'),
  gamme('Gamme'),
  arpege('Arpege');

  const ExerciseKind(this.label);

  final String label;
}

/// Un exercice du catalogue.
///
/// **Un exercice n'est pas un passage : c'est de quoi en fabriquer un.** Il se
/// declare avec quelques parametres -- une tonique, un nombre d'octaves, un
/// ecartement de doigts -- et rend un [Passage] au tempo qu'on lui demande. Ce
/// qui veut dire qu'un exercice ne coute rien a stocker, se rejoue a n'importe
/// quel tempo, et n'a besoin d'aucune saisie prealable.
///
/// C'est ce qui fait de ce jalon le meilleur rapport effet/cout du plan : la
/// justesse est exactement ce qu'un eleve travaille dans ses gammes, et
/// l'application n'a rien a importer pour la mesurer.
sealed class Exercise {
  const Exercise({
    required this.id,
    required this.titre,
    required this.source,
    required this.palier,
    required this.tempoVise,
    this.conseil,
  })  : assert(palier >= 1, 'les paliers sont numerotes a partir de 1'),
        assert(tempoVise > 0, 'un tempo vise est strictement positif');

  final String id;

  /// Titre affiche, ecrit a la main dans le catalogue.
  ///
  /// **Pas genere**, et pour une raison precise : les noms de notes de
  /// l'application s'ecrivent avec des dieses. Un titre calcule dirait donc
  /// "gamme de la# majeur" la ou la partition et le professeur disent "si
  /// bemol majeur". Le catalogue ecrit le nom que l'enfant entend en cours.
  final String titre;

  final MethodSource source;

  /// Palier de difficulte, a partir de 1. C'est l'ordre des methodes, pas le
  /// notre : voir [ExerciseCatalog].
  final int palier;

  /// Tempo a tenir proprement pour que l'exercice compte comme acquis, en
  /// battements par minute.
  final int tempoVise;

  /// Une phrase de conseil, quand l'exercice a un piege connu.
  final String? conseil;

  ExerciseKind get genre;

  /// Les hauteurs de l'exercice, dans l'ordre.
  List<int> get midis;

  /// Ce qui distingue cet exercice des autres, en une ligne.
  String get detail;

  int get noteCount => midis.length;

  int get lowestMidi => midis.reduce((int a, int b) => a < b ? a : b);
  int get highestMidi => midis.reduce((int a, int b) => a > b ? a : b);

  /// Fabrique le passage a jouer.
  ///
  /// [tempoBpm] est le tempo de travail : en dessous du tempo vise on
  /// s'installe, au tempo vise l'exercice compte. Par defaut, le tempo vise.
  Passage toPassage({int? tempoBpm}) => gravePar(
        midis,
        titre: titre,
        tempoBpm: tempoBpm ?? tempoVise,
      );
}

/// Une gamme ou un arpege, decline sur une tonique et un nombre d'octaves.
final class ScaleExercise extends Exercise {
  const ScaleExercise({
    required super.id,
    required super.titre,
    required super.source,
    required super.palier,
    required super.tempoVise,
    required this.pattern,
    required this.tonicMidi,
    this.octaves = 2,
    super.conseil,
  });

  final ScalePattern pattern;

  /// Tonique de depart, en MIDI. 55 est le sol de la corde grave.
  final int tonicMidi;

  final int octaves;

  @override
  ExerciseKind get genre => pattern == ScalePattern.arpegeMajeur ||
          pattern == ScalePattern.arpegeMineur
      ? ExerciseKind.arpege
      : ExerciseKind.gamme;

  @override
  List<int> get midis =>
      pattern.midis(tonicMidi: tonicMidi, octaves: octaves, retour: true);

  @override
  String get detail => octaves == 1
      ? '${pattern.label} - une octave'
      : '${pattern.label} - $octaves octaves';
}

/// Un motif de doigts promene sur plusieurs cordes.
final class MotifExercise extends Exercise {
  const MotifExercise({
    required super.id,
    required super.titre,
    required super.source,
    required super.palier,
    required super.tempoVise,
    required this.motif,
    required this.pattern,
    required this.strings,
    super.conseil,
  });

  final FingerMotif motif;
  final FingerPattern pattern;

  /// Les cordes parcourues, du grave a l'aigu.
  final List<int> strings;

  @override
  ExerciseKind get genre => ExerciseKind.motifDeDoigts;

  @override
  List<int> get midis => motif.midis(pattern: pattern, strings: strings);

  @override
  String get detail => '${pattern.label} - ${motif.label}';
}

/// Grave une suite de hauteurs en croches, la derniere note completant la
/// mesure.
///
/// **La derniere note absorbe le reste, et ce n'est pas un detail de
/// presentation.** Une gamme de deux octaves aller-retour fait vingt-neuf
/// notes : en croches, ca tombe a un demi-temps de la fin d'une mesure. Laisser
/// la mesure incomplete donnerait une derniere case a moitie vide dans le
/// bandeau de mesures, et un score de mesure calcule sur trois notes au lieu de
/// huit.
///
/// La duree obtenue doit etre celle d'une **vraie figure**, sans quoi le
/// graveur dessinerait n'importe quoi : `ScoreNote` ne stocke qu'une duree en
/// ticks et la tete de note s'en deduit. D'ou le [StateError] plutot qu'un
/// arrondi silencieux -- un exercice qui ne se grave pas est un bogue du
/// catalogue, et un test le dit.
Passage gravePar(
  List<int> midis, {
  required String titre,
  required int tempoBpm,
  int beatsPerMeasure = 4,
  int ticksPerBeat = 480,
}) {
  if (midis.isEmpty) {
    throw ArgumentError.value(midis, 'midis', 'un exercice a des notes');
  }
  final PassageBuilder builder = PassageBuilder(
    ticksPerBeat: ticksPerBeat,
    beatsPerMeasure: beatsPerMeasure,
  );
  for (final int midi in midis.take(midis.length - 1)) {
    builder.add(midi, NoteValue.eighth);
  }

  final int reste =
      builder.ticksPerMeasure - builder.totalTicks % builder.ticksPerMeasure;
  final ({NoteValue value, bool dotted})? figure =
      NoteValue.exactly(reste, ticksPerBeat);
  if (figure == null) {
    throw StateError(
      'la derniere note de "$titre" vaudrait $reste ticks, '
      'qui n est aucune figure : ${midis.length} notes en croches',
    );
  }
  builder.add(midis.last, figure.value, dotted: figure.dotted);

  return builder.build(title: titre, writtenTempoBpm: tempoBpm);
}
