import 'dart:math' as math;

import '../music/pitch_utils.dart';

/// Le bourdon : une note tenue, et sa quinte si on la veut.
///
/// **L'exercice de justesse le plus efficace qui existe pour un instrument a
/// cordes.** Jouer contre un bourdon fait entendre les battements : l'enfant
/// corrige tout seul, a l'oreille, sans qu'aucune application ne lui dise qu'il
/// est faux. C'est l'exact inverse d'un score, et c'est pour ca que ca marche.
class Drone {
  const Drone({
    required this.pitchClass,
    this.a4 = PitchUtils.defaultA4,
    this.withFifth = true,
  }) : assert(pitchClass >= 0 && pitchClass < 12, 'douze notes dans l octave');

  /// 0 pour do, 11 pour si.
  final int pitchClass;

  /// Diapason de reference.
  ///
  /// **Celui qui a ete mesure sur les cordes a vide, pas 440.** Un bourdon a
  /// 440 contre un violon accorde a 442 ferait battre l'instrument contre la
  /// reference : l'enfant corrigerait vers le faux, en toute bonne foi, en
  /// faisant precisement ce qu'on lui demande.
  final double a4;

  /// Faire sonner aussi la quinte.
  final bool withFifth;

  /// Octave du bourdon, en MIDI : do3 a si3.
  ///
  /// C'est le bas du violon, pas son milieu. Un bourdon dans le registre ou
  /// l'enfant joue se confondrait avec sa note, et les battements
  /// deviendraient illisibles.
  ///
  /// Consequence heureuse : le bourdon de sol sonne **exactement la corde de
  /// sol a vide**, et celui de re la corde de re. L'enfant peut donc verifier
  /// le bourdon contre son propre instrument -- et une corde a vide ne peut
  /// pas etre jouee faux.
  static const int _octave = 48;

  /// Rapport de la quinte pure, `3/2`.
  ///
  /// **Pure, pas temperee.** Un bourdon est une reference pour l'oreille, et
  /// l'oreille cherche l'endroit ou les battements disparaissent : ils ne
  /// disparaissent qu'au rapport exact. Une quinte temperee, deux cents plus
  /// bas, battrait en permanence contre la quinte juste du violoniste -- qui
  /// aurait raison, et s'entendrait dire le contraire. Meme raison que pour
  /// les quintes a vide de l'accordeur.
  static const double pureFifth = 3 / 2;

  int get midi => _octave + pitchClass;

  double get tonicHz => PitchUtils.midiToFrequency(midi, a4: a4);

  /// La quinte, ou `null` si on ne la veut pas.
  double? get fifthHz => withFifth ? tonicHz * pureFifth : null;

  /// Ce qu'il faut faire sonner.
  List<double> get frequencies => <double>[
        tonicHz,
        if (fifthHz != null) fifthHz!,
      ];

  /// Ecart de la quinte pure a la quinte temperee, en cents. Environ 1,955.
  static double get fifthVersusTemperedCents =>
      1200 * (math.log(pureFifth) / math.ln2) - 700;

  /// Noms francais, avec les deux orthographes des touches noires.
  ///
  /// **Un bourdon se choisit d'apres la tonalite du morceau**, et une partition
  /// ecrit "si bemol" la ou l'application nommerait "la#". Afficher les deux
  /// coute une ligne et evite de faire chercher.
  static const List<String> names = <String>[
    'Do',
    'Do# / Reb',
    'Re',
    'Re# / Mib',
    'Mi',
    'Fa',
    'Fa# / Solb',
    'Sol',
    'Sol# / Lab',
    'La',
    'La# / Sib',
    'Si',
  ];

  String get label => names[pitchClass];

  /// Le sol, tonalite de depart du violon : c'est sa corde grave, et la
  /// tonalite de la premiere gamme du catalogue.
  static const int sol = 7;

  Drone copyWith({int? pitchClass, double? a4, bool? withFifth}) => Drone(
        pitchClass: pitchClass ?? this.pitchClass,
        a4: a4 ?? this.a4,
        withFifth: withFifth ?? this.withFifth,
      );
}
