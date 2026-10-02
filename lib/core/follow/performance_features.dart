import 'dart:math' as math;
import 'dart:typed_data';

import '../music/pitch_utils.dart';
import 'feature_extractor.dart';

/// Ce que l'oreille retient d'une trame : une hauteur, une energie, et si une
/// note vient de commencer.
class FeatureFrame {
  const FeatureFrame({
    required this.timeMs,
    required this.midi,
    required this.rms,
    required this.onset,
    this.analysed = true,
  });

  /// Debut de la trame, depuis le debut de la prise.
  final int timeMs;

  /// Hauteur entendue, en MIDI fractionnaire **rapporte a l'accord reel** de
  /// l'instrument. Nulle si rien de fiable : silence, changement d'archet,
  /// bruit.
  final double? midi;

  /// Energie efficace de la trame.
  final double rms;

  /// Une attaque a ete detectee pendant cette trame.
  final bool onset;

  /// Faux quand l'analyse de hauteur a ete sautee faute de temps (S1).
  ///
  /// Une trame non analysee n'est pas un silence : on ne sait pas ce qui
  /// sonnait. L'energie et l'attaque, elles, sont toujours la.
  final bool analysed;

  bool get voiced => midi != null;

  /// La meme trame, rapportee a un autre accord.
  ///
  /// L'analyse en direct rend ses hauteurs par rapport a 440 Hz ; le suiveur
  /// les veut par rapport au la que l'instrument donne vraiment.
  FeatureFrame retuned({required double fromA4, required double toA4}) {
    final double? m = midi;
    if (m == null || fromA4 == toA4) {
      return this;
    }
    return FeatureFrame(
      timeMs: timeMs,
      midi: m - 12 * math.log(toA4 / fromA4) / math.ln2,
      rms: rms,
      onset: onset,
      analysed: analysed,
    );
  }
}

/// Transforme une prise entiere en une suite de [FeatureFrame].
///
/// **Hors ligne, et c'est voulu.** Le jalon 5 prouve que l'alignement est
/// possible, pas qu'il tient en temps reel : l'analyse voit toute la prise
/// d'un coup, sans trame perdue. Le flux sans trou du temps reel est le
/// probleme de S1, au jalon suivant.
///
/// Les deux detecteurs sont ceux de l'application, regles pareil : un
/// aligneur prouve sur d'autres oreilles ne prouverait rien.
class PerformanceFeatures {
  const PerformanceFeatures._();

  /// En dessous de cette energie, on n'entend rien -- meme seuil que
  /// `PcmTake`, mesure sur le S22.
  static const double silenceRms = 0.012;

  /// En dessous, YIN a repondu mais il devine.
  static const double minConfidence = 0.7;

  /// Tout d'un coup : c'est [FeatureExtractor] nourri de la prise entiere,
  /// pour que l'analyse hors ligne et le direct ne puissent pas diverger.
  static List<FeatureFrame> extract(
    Float32List samples, {
    int sampleRate = 44100,
    int frameSize = 2048,
    int hopSize = 1024,
    double a4 = PitchUtils.defaultA4,
  }) =>
      FeatureExtractor(
        sampleRate: sampleRate,
        frameSize: frameSize,
        hopSize: hopSize,
        a4: a4,
      ).addSamples(samples);
}
