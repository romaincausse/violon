import 'dart:async';
import 'dart:typed_data';

import 'pitch_estimate.dart';
import 'pitch_smoother.dart';
import 'pitch_source.dart';

/// Source de hauteurs scriptee.
///
/// Deux usages :
///  - developper l'interface (partition, curseur, scoring) sous Flutter Web
///    avec le hot reload, sans avoir a jouer du violon a chaque iteration ;
///  - ecrire des tests deterministes du moteur de notation.
class FakePitchSource implements PitchSource {
  FakePitchSource(this.script,
      {this.interval = const Duration(milliseconds: 50)});

  /// Genere un jeu parfaitement juste et en place a partir de frequences.
  factory FakePitchSource.fromFrequencies(
    List<double> frequencies, {
    Duration interval = const Duration(milliseconds: 50),
  }) {
    int t = 0;
    final List<PitchEstimate> script = <PitchEstimate>[];
    for (final double frequency in frequencies) {
      script.add(
        PitchEstimate(frequencyHz: frequency, confidence: 1, timestampMs: t),
      );
      t += interval.inMilliseconds;
    }
    return FakePitchSource(script, interval: interval);
  }

  final List<PitchEstimate> script;
  final Duration interval;

  final StreamController<SmoothedPitch> _controller =
      StreamController<SmoothedPitch>.broadcast();

  final StreamController<Uint8List> _octets =
      StreamController<Uint8List>.broadcast();

  Timer? _timer;
  int _index = 0;

  @override
  Stream<PitchEstimate> get pitches =>
      _controller.stream.map((SmoothedPitch p) => p.estimate);

  @override
  Stream<SmoothedPitch> get smoothedPitches => _controller.stream;

  @override
  Stream<Uint8List> get audio => _octets.stream;

  /// Envoie des octets comme le ferait le micro.
  ///
  /// Le script d'une source factice porte des hauteurs, pas du signal : ce
  /// qu'on veut rejouer n'a aucun rapport avec ce qu'on veut analyser. Les
  /// deux flux se pilotent donc separement.
  void emitAudio(Uint8List octets) => _octets.add(octets);

  /// **Aucun lissage ici, et c'est delibere.**
  ///
  /// J'avais d'abord fait passer le script par un vrai [PitchSmoother], pour
  /// que la source factice ressemble a la chaine reelle. Un test l'a refuse :
  /// un script `la4, si4, do5` ressortait `la4, la#4, do5`, parce que la
  /// mediane glissante attend deux ecarts de suite avant d'admettre un
  /// changement de note.
  ///
  /// Le lisseur avait raison, c'est l'idee qui etait mauvaise : **une source
  /// scriptee dont le script ne ressort pas tel quel n'est plus un outil de
  /// test.** Le lissage se teste dans `pitch_smoother_test.dart`, sur du
  /// signal fait pour ca.
  ///
  /// Consequence a connaitre : ici `excursionCents` vaut zero et `vibrato`
  /// est faux. Tout ce qui juge une oscillation doit donc etre teste sur des
  /// [SmoothedPitch] construits a la main, pas sur cette source.
  void _emettre(PitchEstimate estimate) => _controller.add(
        SmoothedPitch(estimate: estimate, excursionCents: 0, vibrato: false),
      );

  @override
  String get sourceLabel => 'source factice';

  /// Une source scriptee ne jette rien : tout ce qui est ecrit est livre.
  @override
  int get droppedFrames => 0;

  @override
  int get latencyMs => 0;

  @override
  Future<void> start() async {
    _index = 0;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (Timer timer) {
      if (_index >= script.length) {
        timer.cancel();
        return;
      }
      _emettre(script[_index]);
      _index++;
    });
  }

  /// Emet une hauteur, maintenant, hors script.
  ///
  /// Le pendant de [emitAudio] pour les hauteurs. Un script decrit une prise
  /// du debut a la fin ; certains tests ont besoin de conduire l'ecran note
  /// par note, en regardant ce qu'il fait entre deux.
  void emit(PitchEstimate estimate) => _emettre(estimate);

  /// Emet tout le script immediatement : pratique pour les tests unitaires.
  void emitAll() {
    for (final PitchEstimate estimate in script) {
      _emettre(estimate);
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
    await _octets.close();
  }
}
