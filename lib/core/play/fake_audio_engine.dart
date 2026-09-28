import 'audio_engine.dart';
import 'instrument.dart';
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
  FakeAudioEngine({InstrumentLibrary? library})
      : library = library ?? fakeInstruments;

  final List<FakeClick> clicks = <FakeClick>[];
  final List<FakeDroneVoice> drones = <FakeDroneVoice>[];
  final List<FakeNote> notes = <FakeNote>[];
  final List<FakeClick> clicksAt = <FakeClick>[];
  final Set<String> prepared = <String>{};

  /// Ce que le moteur sait jouer.
  final InstrumentLibrary library;

  /// L'horloge du moteur factice : c'est le test qui l'avance.
  Duration clock = Duration.zero;

  @override
  Future<InstrumentLibrary> instruments() async => library;

  @override
  Future<void> prepareInstrument(String instrument) async {
    prepared.add(instrument);
  }

  @override
  Future<Duration> now() async => clock;

  @override
  Future<void> scheduleNote({
    required String instrument,
    required Duration at,
    required double frequencyHz,
    required Duration duration,
    double volume = 0.5,
  }) async {
    notes.add(
      FakeNote(
        instrument: instrument,
        at: at,
        frequencyHz: frequencyHz,
        duration: duration,
        volume: volume,
      ),
    );
  }

  @override
  Future<void> scheduleClickAt({
    required Duration at,
    PulseAccent accent = PulseAccent.beat,
  }) async {
    clicksAt.add(FakeClick(delay: at, accent: accent));
  }

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
    String? instrument,
  }) async {
    final FakeDroneVoice voix = FakeDroneVoice(
      frequencyHz: frequencyHz,
      volume: volume,
      timbre: timbre,
      instrument: instrument,
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
    notes.clear();
    clicksAt.clear();
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
    this.instrument,
  });

  double frequencyHz;
  double volume;
  final DroneTimbre timbre;
  final String? instrument;
  bool stopped = false;

  @override
  Future<void> setFrequency(double hz) async => frequencyHz = hz;

  @override
  Future<void> setVolume(double v) async => volume = v;

  @override
  Future<void> stop() async => stopped = true;
}

/// Une note planifiee dans le moteur factice.
class FakeNote {
  const FakeNote({
    required this.instrument,
    required this.at,
    required this.frequencyHz,
    required this.duration,
    required this.volume,
  });

  final String instrument;
  final Duration at;
  final double frequencyHz;
  final Duration duration;
  final double volume;

  @override
  String toString() => 'FakeNote($instrument ${frequencyHz.toStringAsFixed(1)} '
      '@ ${at.inMilliseconds} ms)';
}

/// Trois instruments de test, sans fichier : un piano qui s'eteint, un violon
/// et un orgue qui tiennent.
final InstrumentLibrary fakeInstruments = InstrumentLibrary(<Instrument>[
  Instrument(
    id: 'piano',
    name: 'Piano',
    sustains: false,
    samples: const <InstrumentSample>[
      InstrumentSample(midi: 36, hz: 65.41, file: 'piano_36.ogg'),
      InstrumentSample(midi: 60, hz: 261.63, file: 'piano_60.ogg'),
      InstrumentSample(midi: 84, hz: 1046.5, file: 'piano_84.ogg'),
    ],
  ),
  Instrument(
    id: 'violon',
    name: 'Violon',
    sustains: true,
    samples: const <InstrumentSample>[
      InstrumentSample(
        midi: 55,
        hz: 196,
        file: 'violon_55.ogg',
        loopStart: Duration(milliseconds: 900),
      ),
      InstrumentSample(
        midi: 81,
        hz: 880,
        file: 'violon_81.ogg',
        loopStart: Duration(milliseconds: 900),
      ),
    ],
  ),
  Instrument(
    id: 'orgue',
    name: 'Orgue',
    sustains: true,
    samples: const <InstrumentSample>[
      InstrumentSample(
        midi: 48,
        hz: 130.8,
        file: 'orgue_48.ogg',
        loopStart: Duration(milliseconds: 900),
      ),
      InstrumentSample(
        midi: 72,
        hz: 523.3,
        file: 'orgue_72.ogg',
        loopStart: Duration(milliseconds: 900),
      ),
    ],
  ),
]);
