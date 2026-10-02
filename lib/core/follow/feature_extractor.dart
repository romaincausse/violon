import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/onset_detector.dart';
import '../audio/pitch_estimate.dart';
import '../audio/yin_detector.dart';
import '../music/pitch_utils.dart';
import 'performance_features.dart';

/// Ce que [PerformanceFeatures] calcule sur une prise entiere, calcule au fil
/// de l'eau (lot S1).
///
/// **Les memes trames, a l'identique, quel que soit le decoupage du flux.**
/// L'aligneur a ete regle sur l'analyse hors ligne ; un suiveur en direct
/// nourri d'autres trames serait un autre suiveur, qu'aucun banc n'aurait
/// mesure. Un test le verifie : une prise donnee d'un coup ou par paquets de
/// taille quelconque rend la meme liste.
///
/// **Sans trou.** Chaque echantillon est vu par le detecteur d'attaques, qui
/// en a besoin pour comparer un spectre au precedent. Sous pression, seule
/// l'analyse de hauteur peut etre sautee ([addSamples] avec
/// `analysePitch: false`) : la trame est rendue quand meme, a sa place, avec
/// son energie et son attaque, et marquee comme non analysee. Le suiveur sait
/// alors qu'il ne sait pas, ce qui n'est pas la meme chose qu'un silence.
///
/// **Une trame attend que son attaque soit tranchee.** Le detecteur ne
/// declare une attaque qu'une fenetre apres l'avoir vue. Une trame n'est donc
/// rendue que quand toutes les attaques qui la precedent sont connues -- ce
/// qui arrive avant qu'elle soit complete, sa fenetre etant plus longue que
/// ce retard. Aucune latence ajoutee.
class FeatureExtractor {
  FeatureExtractor({
    this.sampleRate = 44100,
    this.frameSize = 2048,
    this.hopSize = 1024,
    this.a4 = PitchUtils.defaultA4,
  })  : _yin = YinDetector(sampleRate: sampleRate),
        _attaques = OnsetDetector(sampleRate: sampleRate);

  final int sampleRate;
  final int frameSize;
  final int hopSize;

  /// Le la de reference des hauteurs rendues. Le direct le laisse a 440 et
  /// rapporte ensuite a l'accord mesure ([FeatureFrame.retuned]) : l'analyse
  /// tourne dans un isolate qui ignore le diapason.
  final double a4;

  final YinDetector _yin;
  final OnsetDetector _attaques;

  /// Echantillons pas encore sortis d'une fenetre : de [_debutTampon] a la
  /// fin de ce qui a ete recu.
  final List<double> _tampon = <double>[];
  int _debutTampon = 0;

  /// Debut, en echantillons, de la prochaine trame a rendre.
  int _prochaine = 0;

  /// Attaques connues et pas encore rattachees a une trame.
  final List<Onset> _attaquesEnAttente = <Onset>[];

  /// Ajoute un paquet d'echantillons qui suit exactement le precedent, et
  /// rend les trames qu'il complete.
  ///
  /// [analysePitch] faux saute YIN sur ces trames-la : c'est le seul
  /// allegement permis quand l'analyse prend du retard.
  List<FeatureFrame> addSamples(
    Float32List samples, {
    bool analysePitch = true,
  }) {
    _attaquesEnAttente.addAll(_attaques.addSamples(samples));
    _tampon.addAll(samples);

    final List<FeatureFrame> trames = <FeatureFrame>[];
    final Float32List fenetre = Float32List(frameSize);
    while (_prochaine + frameSize <= _debutTampon + _tampon.length) {
      final int debut = _prochaine;
      final int timeMs = debut * 1000 ~/ sampleRate;

      // Une attaque marque la premiere trame qui commence apres elle, et une
      // seule : l'aligneur avancerait deux fois sinon.
      bool onset = false;
      while (_attaquesEnAttente.isNotEmpty &&
          _attaquesEnAttente.first.timestampMs <= timeMs) {
        onset = true;
        _attaquesEnAttente.removeAt(0);
      }

      final int decalage = debut - _debutTampon;
      for (int i = 0; i < frameSize; i++) {
        fenetre[i] = _tampon[decalage + i];
      }
      final double rms = _efficace(fenetre);
      double? midi;
      if (analysePitch && rms >= PerformanceFeatures.silenceRms) {
        final PitchEstimate? e = _yin.detect(fenetre, timestampMs: timeMs);
        if (e != null && e.confidence >= PerformanceFeatures.minConfidence) {
          midi = PitchUtils.frequencyToMidi(e.frequencyHz, a4: a4);
        }
      }
      trames.add(
        FeatureFrame(
          timeMs: timeMs,
          midi: midi,
          rms: rms,
          onset: onset,
          analysed: analysePitch,
        ),
      );
      _prochaine += hopSize;
    }

    // Ce qui precede la prochaine trame ne servira plus.
    final int inutile = _prochaine - _debutTampon;
    if (inutile > 0) {
      _tampon.removeRange(0, math.min(inutile, _tampon.length));
      _debutTampon += inutile;
    }
    return trames;
  }

  /// Oublie tout : a appeler entre deux prises. Le temps repart de zero.
  void reset() {
    _attaques.reset();
    _tampon.clear();
    _debutTampon = 0;
    _prochaine = 0;
    _attaquesEnAttente.clear();
  }

  static double _efficace(Float32List fenetre) {
    double somme = 0;
    for (final double v in fenetre) {
      somme += v * v;
    }
    return math.sqrt(somme / fenetre.length);
  }
}
