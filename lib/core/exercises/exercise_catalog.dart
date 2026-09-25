import '../music/finger_pattern.dart';
import '../music/pitch_utils.dart';
import '../music/scale_pattern.dart';
import 'exercise.dart';
import 'method_source.dart';

/// Un palier de difficulte : quelques exercices qui font travailler la meme
/// chose.
class Palier {
  const Palier({
    required this.numero,
    required this.titre,
    required this.intention,
  });

  final int numero;

  /// Ce que le palier s'appelle, en trois mots.
  final String titre;

  /// Ce qu'on y travaille, en une phrase. Affiche sous le titre : un palier
  /// dont on ne sait pas a quoi il sert n'est qu'un numero.
  final String intention;
}

/// Le catalogue d'exercices.
///
/// **La progression n'est pas inventee, elle est reprise.** Sevcik, Schradieck
/// et Hrimaly sont ordonnes par difficulte croissante depuis les annees 1880 :
/// les doigts avant les gammes, une octave avant deux, le majeur avant le
/// mineur. Cet ordre a fait ses preuves sur quatre generations de violonistes,
/// et c'est celui que le professeur suivra de son cote. Reinventer un ordre
/// maison aurait ete du travail en plus pour un resultat moins bon.
///
/// **Ce que le catalogue ne contient pas encore** : les etudes melodiques
/// (Wohlfahrt, Kayser, Mazas). Ce sont des morceaux ecrits, qui ne se generent
/// pas -- voir [MethodSource.all].
class ExerciseCatalog {
  const ExerciseCatalog._();

  /// La note la plus grave du violon : le sol de la corde grave.
  static const int plusGraveJouable = 55;

  /// La note la plus aigue atteignable sans quitter la premiere position : le
  /// quatrieme doigt sur la corde de mi.
  ///
  /// Le catalogue s'y tient volontairement. Une gamme de trois octaves
  /// demanderait de demanger jusqu'a la septieme position, ce qui n'est pas le
  /// programme d'une quatrieme annee : l'ajouter aurait fait un catalogue plus
  /// impressionnant et moins utilisable.
  static const int plusAiguEnPremierePosition = 83;

  static const List<Palier> paliers = <Palier>[
    Palier(
      numero: 1,
      titre: 'La main se pose',
      intention: 'Un seul ecartement de doigts, sur les quatre cordes',
    ),
    Palier(
      numero: 2,
      titre: 'Les autres ecartements',
      intention: 'Le demi-ton change de place, la main doit le suivre',
    ),
    Palier(
      numero: 3,
      titre: 'Une octave',
      intention: 'La premiere gamme, d une corde a l autre',
    ),
    Palier(
      numero: 4,
      titre: 'Deux octaves',
      intention: 'La gamme traverse les quatre cordes et revient',
    ),
    Palier(
      numero: 5,
      titre: 'Les arpeges',
      intention: 'Des sauts, sans gamme pour rattraper l oreille',
    ),
    Palier(
      numero: 6,
      titre: 'Le mineur',
      intention: 'Harmonique et melodique, la ou les doigts hesitent',
    ),
  ];

  /// Tous les exercices, **dans l'ordre de difficulte**. Cet ordre est le
  /// contrat du catalogue : la progression et la prochaine tache s'y fient.
  static const List<Exercise> all = <Exercise>[
    // --- Palier 1 : un seul ecartement, celui du majeur ---------------------
    MotifExercise(
      id: 'motif-en-ligne-2-3',
      titre: 'Les doigts en ligne',
      source: MethodSource.sevcik,
      palier: 1,
      tempoVise: 60,
      motif: FingerMotif.enLigne,
      pattern: FingerPattern.deuxTroisSerres,
      strings: PitchUtils.violinOpenStrings,
    ),
    MotifExercise(
      id: 'motif-verification-2-3',
      titre: 'Chaque doigt, puis la corde',
      source: MethodSource.sevcik,
      palier: 1,
      tempoVise: 60,
      motif: FingerMotif.verification,
      pattern: FingerPattern.deuxTroisSerres,
      strings: PitchUtils.violinOpenStrings,
      conseil: 'La corde a vide est la reference. Si le doigt sonne autrement '
          'qu elle, c est le doigt qui a tort.',
    ),
    MotifExercise(
      id: 'motif-tierces-2-3',
      titre: 'Les doigts par tierces',
      source: MethodSource.schradieck,
      palier: 1,
      tempoVise: 60,
      motif: FingerMotif.enTierces,
      pattern: FingerPattern.deuxTroisSerres,
      strings: PitchUtils.violinOpenStrings,
    ),

    // --- Palier 2 : le demi-ton se deplace ---------------------------------
    MotifExercise(
      id: 'motif-en-ligne-1-2',
      titre: 'Les doigts en ligne, 1-2 serres',
      source: MethodSource.sevcik,
      palier: 2,
      tempoVise: 66,
      motif: FingerMotif.enLigne,
      pattern: FingerPattern.unDeuxSerres,
      strings: PitchUtils.violinOpenStrings,
    ),
    MotifExercise(
      id: 'motif-en-ligne-3-4',
      titre: 'Les doigts en ligne, 3-4 serres',
      source: MethodSource.sevcik,
      palier: 2,
      tempoVise: 66,
      motif: FingerMotif.enLigne,
      pattern: FingerPattern.troisQuatreSerres,
      strings: PitchUtils.violinOpenStrings,
      conseil: 'Le troisieme doigt monte d un demi-ton. C est l ecartement '
          'que la main oublie.',
    ),
    MotifExercise(
      id: 'motif-en-ligne-0-1',
      titre: 'Les doigts en ligne, premier doigt bas',
      source: MethodSource.sevcik,
      palier: 2,
      tempoVise: 66,
      motif: FingerMotif.enLigne,
      pattern: FingerPattern.zeroUnSerres,
      strings: PitchUtils.violinOpenStrings,
    ),
    MotifExercise(
      id: 'motif-verification-3-4',
      titre: 'Le troisieme doigt, verifie',
      source: MethodSource.sevcik,
      palier: 2,
      tempoVise: 66,
      motif: FingerMotif.verification,
      pattern: FingerPattern.troisQuatreSerres,
      strings: PitchUtils.violinOpenStrings,
    ),

    // --- Palier 3 : une octave ---------------------------------------------
    ScaleExercise(
      id: 'gamme-sol-majeur-1',
      titre: 'Gamme de sol majeur',
      source: MethodSource.hrimaly,
      palier: 3,
      tempoVise: 72,
      pattern: ScalePattern.majeur,
      tonicMidi: 55,
      octaves: 1,
    ),
    ScaleExercise(
      id: 'gamme-re-majeur-1',
      titre: 'Gamme de re majeur',
      source: MethodSource.hrimaly,
      palier: 3,
      tempoVise: 72,
      pattern: ScalePattern.majeur,
      tonicMidi: 62,
      octaves: 1,
    ),
    ScaleExercise(
      id: 'gamme-la-majeur-1',
      titre: 'Gamme de la majeur',
      source: MethodSource.hrimaly,
      palier: 3,
      tempoVise: 72,
      pattern: ScalePattern.majeur,
      tonicMidi: 69,
      octaves: 1,
    ),

    // --- Palier 4 : deux octaves -------------------------------------------
    ScaleExercise(
      id: 'gamme-sol-majeur-2',
      titre: 'Gamme de sol majeur, deux octaves',
      source: MethodSource.hrimaly,
      palier: 4,
      tempoVise: 80,
      pattern: ScalePattern.majeur,
      tonicMidi: 55,
    ),
    ScaleExercise(
      id: 'gamme-la-majeur-2',
      titre: 'Gamme de la majeur, deux octaves',
      source: MethodSource.hrimaly,
      palier: 4,
      tempoVise: 80,
      pattern: ScalePattern.majeur,
      tonicMidi: 57,
    ),
    ScaleExercise(
      id: 'gamme-si-bemol-majeur-2',
      titre: 'Gamme de si bemol majeur, deux octaves',
      source: MethodSource.hrimaly,
      palier: 4,
      tempoVise: 80,
      pattern: ScalePattern.majeur,
      tonicMidi: 58,
      conseil: 'Le quatrieme doigt reste bas sur la corde de mi.',
    ),

    // --- Palier 5 : les arpeges --------------------------------------------
    ScaleExercise(
      id: 'arpege-sol-majeur-2',
      titre: 'Arpege de sol majeur, deux octaves',
      source: MethodSource.hrimaly,
      palier: 5,
      tempoVise: 80,
      pattern: ScalePattern.arpegeMajeur,
      tonicMidi: 55,
      conseil: 'Rien entre les notes : l oreille n a pas de gamme pour se '
          'rattraper.',
    ),
    ScaleExercise(
      id: 'arpege-la-majeur-2',
      titre: 'Arpege de la majeur, deux octaves',
      source: MethodSource.hrimaly,
      palier: 5,
      tempoVise: 80,
      pattern: ScalePattern.arpegeMajeur,
      tonicMidi: 57,
    ),
    ScaleExercise(
      id: 'arpege-sol-mineur-2',
      titre: 'Arpege de sol mineur, deux octaves',
      source: MethodSource.hrimaly,
      palier: 5,
      tempoVise: 80,
      pattern: ScalePattern.arpegeMineur,
      tonicMidi: 55,
    ),

    // --- Palier 6 : le mineur ----------------------------------------------
    ScaleExercise(
      id: 'gamme-sol-mineur-harmonique-2',
      titre: 'Gamme de sol mineur harmonique',
      source: MethodSource.hrimaly,
      palier: 6,
      tempoVise: 76,
      pattern: ScalePattern.mineurHarmonique,
      tonicMidi: 55,
      conseil: 'Un ton et demi entre la sixte et la septieme. C est cet '
          'intervalle qui sonne mineur harmonique.',
    ),
    ScaleExercise(
      id: 'gamme-la-mineur-harmonique-2',
      titre: 'Gamme de la mineur harmonique',
      source: MethodSource.hrimaly,
      palier: 6,
      tempoVise: 76,
      pattern: ScalePattern.mineurHarmonique,
      tonicMidi: 57,
    ),
    ScaleExercise(
      id: 'gamme-sol-mineur-melodique-2',
      titre: 'Gamme de sol mineur melodique',
      source: MethodSource.hrimaly,
      palier: 6,
      tempoVise: 76,
      pattern: ScalePattern.mineurMelodique,
      tonicMidi: 55,
      conseil: 'La sixte et la septieme montent en montant, et redescendent '
          'en descendant.',
    ),
  ];

  static int get palierCount => paliers.length;

  static List<Exercise> ofPalier(int numero) =>
      all.where((Exercise e) => e.palier == numero).toList(growable: false);

  static Palier palier(int numero) =>
      paliers.firstWhere((Palier p) => p.numero == numero);

  static Exercise? byId(String id) =>
      all.where((Exercise e) => e.id == id).firstOrNull;
}
