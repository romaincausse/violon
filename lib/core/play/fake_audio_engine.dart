import 'audio_engine.dart';
import 'metronome_clock.dart';

/// Un clic planifie, tel que le moteur factice l'a recu.
class FakeClick {
  const FakeClick({required this.delay, required this.accent});

  final Duration delay;
  final PulseAccent accent;

  @override
  String toString() => 'FakeClick(${delay.inMilliseconds} ms, ${accent.name})';
}

/// Moteur de son factice, qui note ce qu'on lui demande au lieu de le jouer.
///
/// Meme role que `FakePitchSource` en entree : developper et tester tout ce qui
/// est au-dessus du moteur **sans appareil et sans haut-parleur**. Un test qui
/// verifie qu'un clic tombe au bon instant n'a pas besoin de l'entendre ; il a
/// besoin de savoir a quel instant il a ete pose.
class FakeAudioEngine implements AudioEngine {
  final List<FakeClick> clicks = <FakeClick>[];
  final List<FakeDroneVoice> drones = <FakeDroneVoice>[];

  int starts = 0;
  int stopAlls = 0;
  bool disposed = false;
  bool _running = false;

  /// Les bourdons encore en train de sonner.
  Iterable<FakeDroneVoice> get sounding =>
      drones.where((FakeDroneVoice d) => !d.stopped);

  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async {
    starts++;
    _running = true;
  }

  @override
  Future<DroneVoice> startDrone({
    required double frequencyHz,
    double volume = 0.3,
    DroneTimbre timbre = DroneTimbre.dentDeScie,
  }) async {
    final FakeDroneVoice voix = FakeDroneVoice(
      frequencyHz: frequencyHz,
      volume: volume,
      timbre: timbre,
    );
    drones.add(voix);
    return voix;
  }

  @override
  Future<void> scheduleClick({
    required Duration delay,
    PulseAccent accent = PulseAccent.beat,
  }) async {
    clicks.add(FakeClick(delay: delay, accent: accent));
  }

  @override
  Future<void> stopAll() async {
    stopAlls++;
    for (final FakeDroneVoice voix in drones) {
      voix.stopped = true;
    }
    clicks.clear();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _running = false;
  }
}

class FakeDroneVoice implements DroneVoice {
  FakeDroneVoice({
    required this.frequencyHz,
    required this.volume,
    required this.timbre,
  });

  double frequencyHz;
  double volume;
  final DroneTimbre timbre;
  bool stopped = false;

  @override
  Future<void> setFrequency(double hz) async => frequencyHz = hz;

  @override
  Future<void> setVolume(double v) async => volume = v;

  @override
  Future<void> stop() async => stopped = true;
}
