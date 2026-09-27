import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/onset_detector.dart';
import '../audio/pitch_estimate.dart';
import '../audio/yin_detector.dart';
import '../music/pitch_utils.dart';

/// Ce que l'oreille retient d'une trame : une hauteur, une energie, et si une
/// note vient de commencer.
class FeatureFrame {
  const FeatureFrame({
    required this.timeMs,
    required this.midi,
    required this.rms,
    required this.onset,
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

  bool get voiced => midi != null;
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

  static List<FeatureFrame> extract(
    Float32List samples, {
    int sampleRate = 44100,
    int frameSize = 2048,
    int hopSize = 1024,
    double a4 = PitchUtils.defaultA4,
  }) {
    final YinDetector yin = YinDetector(sampleRate: sampleRate);
    final List<Onset> attaques =
        OnsetDetector(sampleRate: sampleRate).addSamples(samples);

    final List<FeatureFrame> trames = <FeatureFrame>[];
    int prochaineAttaque = 0;
    for (int debut = 0; debut + frameSize <= samples.length; debut += hopSize) {
      final int timeMs = debut * 1000 ~/ sampleRate;

      // Une attaque marque la premiere trame qui commence apres elle : c'est
      // la premiere dont la fenetre entend la nouvelle note plutot que la
      // queue de l'ancienne. Chaque attaque marque une seule trame, sinon
      // l'aligneur pourrait avancer deux fois sur deux notes repetees.
      bool onset = false;
      while (prochaineAttaque < attaques.length &&
          attaques[prochaineAttaque].timestampMs <= timeMs) {
        onset = true;
        prochaineAttaque++;
      }

      final Float32List fenetre =
          Float32List.sublistView(samples, debut, debut + frameSize);
      final double rms = _efficace(fenetre);
      double? midi;
      if (rms >= silenceRms) {
        final PitchEstimate? e = yin.detect(fenetre, timestampMs: timeMs);
        if (e != null && e.confidence >= minConfidence) {
          midi = PitchUtils.frequencyToMidi(e.frequencyHz, a4: a4);
        }
      }
      trames.add(
        FeatureFrame(timeMs: timeMs, midi: midi, rms: rms, onset: onset),
      );
    }
    return trames;
  }

  static double _efficace(Float32List fenetre) {
    double somme = 0;
    for (final double v in fenetre) {
      somme += v * v;
    }
    return math.sqrt(somme / fenetre.length);
  }
}
