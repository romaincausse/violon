import 'dart:math' as math;

import '../music/pitch_utils.dart';

/// L'intervalle mesure entre deux cordes voisines.
class StringFifth {
  const StringFifth({
    required this.lowMidi,
    required this.highMidi,
    required this.centsFromPure,
  });

  final int lowMidi;
  final int highMidi;

  /// Ecart a la quinte juste, en cents. Positif si la quinte est trop large.
  final double centsFromPure;

  /// La quinte est trop large : la corde aigue est trop haute, ou la grave
  /// trop basse.
  bool get tooWide => centsFromPure > 0;

  String get name =>
      '${PitchUtils.noteName(lowMidi)}-${PitchUtils.noteName(highMidi)}';
}

/// Les trois quintes d'un violon, mesurees corde par corde.
///
/// **Un violoniste accorde par quintes, pas note par note.** On tire deux
/// cordes voisines ensemble et on ecoute les battements : c'est la technique
/// qu'on lui enseigne, et un accordeur qui mesure quatre hauteurs
/// independantes ne l'accompagne pas.
///
/// **Le detecteur est monophonique**, donc il n'entend pas la double corde.
/// On fait donc autrement : on mesure chaque corde a son tour, et on rend
/// l'intervalle. Ce n'est pas la meme chose que d'ecouter des battements,
/// mais ca repond a la meme question -- ma quinte est-elle juste ? -- avec ce
/// que le micro sait faire.
///
/// **La reference est la quinte JUSTE, pas la quinte temperee.** Un violon
/// s'accorde sur le rapport 3:2, soit 701,955 cents ; le piano, lui, rabote
/// ses quintes a 700 pour que les douze tonalites tiennent. Utiliser 700 ici
/// declarerait fausses des cordes accordees exactement comme il faut, a deux
/// cents pres et trois fois de suite.
class OpenStringFifths {
  const OpenStringFifths._();

  /// Sol3, re4, la4, mi5, du grave a l'aigu.
  static const List<int> strings = <int>[55, 62, 69, 76];

  /// La quinte juste, rapport 3:2.
  static final double pureFifthCents = 1200 * (math.log(3 / 2) / math.ln2);

  /// Au-dela, la quinte est dite fausse.
  ///
  /// Cinq cents : c'est a peu pres ou l'oreille commence a entendre des
  /// battements sur deux cordes tenues ensemble. En deca, personne ne le
  /// remarque, et le dire ferait recommencer un accordage deja bon.
  static const double toleranceCents = 5;

  /// Les quintes deductibles des cordes mesurees.
  ///
  /// [measuredHz] associe la note MIDI d'une corde a vide a sa frequence
  /// mesuree. Les quintes dont une corde manque ne sont pas rendues : on ne
  /// devine pas une corde qu'on n'a pas entendue.
  static List<StringFifth> from(Map<int, double> measuredHz) {
    final List<StringFifth> quintes = <StringFifth>[];
    for (int i = 0; i < strings.length - 1; i++) {
      final double? grave = measuredHz[strings[i]];
      final double? aigue = measuredHz[strings[i + 1]];
      if (grave == null || aigue == null) {
        continue;
      }
      quintes.add(
        StringFifth(
          lowMidi: strings[i],
          highMidi: strings[i + 1],
          centsFromPure: PitchUtils.centsBetween(aigue, grave) - pureFifthCents,
        ),
      );
    }
    return quintes;
  }

  static bool isInTune(StringFifth fifth) =>
      fifth.centsFromPure.abs() <= toleranceCents;
}
