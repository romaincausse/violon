import 'dart:async';

import 'pitch_estimate.dart';
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

  final StreamController<PitchEstimate> _controller =
      StreamController<PitchEstimate>.broadcast();
  Timer? _timer;
  int _index = 0;

  @override
  Stream<PitchEstimate> get pitches => _controller.stream;

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
      _controller.add(script[_index]);
      _index++;
    });
  }

  /// Emet tout le script immediatement : pratique pour les tests unitaires.
  void emitAll() {
    for (final PitchEstimate estimate in script) {
      _controller.add(estimate);
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
  }
}
