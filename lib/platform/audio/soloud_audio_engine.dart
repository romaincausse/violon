import 'package:flutter_soloud/flutter_soloud.dart';

import '../../core/play/audio_engine.dart';
import '../../core/play/click_sound.dart';
import '../../core/play/metronome_clock.dart';

/// Le moteur de son, branche sur SoLoud (ADR-012).
///
/// **La seule classe du projet qui connait `flutter_soloud`**, comme
/// `RecordAudioCapture` est la seule a connaitre `record`. Tout ce qui est
/// au-dessus parle a [AudioEngine], et se teste avec `FakeAudioEngine`.
///
/// Deux appels justifient a eux seuls la dependance :
///  - `setDelaySamples` pose un clic **a l'echantillon pres**, donc sans
///    derive, quoi que fasse l'interface pendant ce temps ;
///  - `setWaveformFreq` fixe une frequence exacte, donc le bourdon sonne au
///    diapason mesure et non a 440 par defaut.
class SoloudAudioEngine implements AudioEngine {
  SoloudAudioEngine({SoLoud? soloud}) : _injecte = soloud;

  final SoLoud? _injecte;

  /// **Resolu tardivement, et c'est indispensable.** Construire `SoLoud`
  /// charge la bibliotheque native : le faire dans le constructeur ferait
  /// echouer tout test de widget qui monte l'application, faute de `.so` dans
  /// la machine virtuelle de test. Et cote produit, cela reviendrait a
  /// reveiller le materiel audio au lancement d'une application qu'on ouvre
  /// pour travailler en silence.
  SoLoud get _soloud => _injecte ?? SoLoud.instance;

  /// Les clics deja synthetises, par accent.
  ///
  /// Un clic se fabrique une fois pour toute la seance : le refaire a chaque
  /// pulsation ferait travailler le processeur quatre fois par temps pour un
  /// resultat identique au precedent.
  final Map<PulseAccent, AudioSource> _clics = <PulseAccent, AudioSource>{};

  /// Ce qui a ete lance et qu'il faudra pouvoir couper, clics planifies
  /// compris. Un clic deja pose mais pas encore sonne doit pouvoir etre annule
  /// quand on arrete le metronome, sinon il sonne dans le silence.
  final List<SoundHandle> _enCours = <SoundHandle>[];

  final List<AudioSource> _sources = <AudioSource>[];

  /// Vrai des qu'on a demande du son au moins une fois.
  ///
  /// **Tant que c'est faux, cette classe ne touche pas a la bibliotheque
  /// native** -- pas meme pour demander si elle est initialisee. C'est ce qui
  /// permet de construire le moteur au lancement, de le traverser jusqu'aux
  /// ecrans, et de le liberer a la fermeture, sans jamais reveiller le
  /// materiel audio d'une seance entierement silencieuse.
  bool _reveille = false;

  @override
  bool get isRunning => _reveille && _soloud.isInitialized;

  @override
  Future<void> start() async {
    _reveille = true;
    if (_soloud.isInitialized) {
      return;
    }
    // `lowLatency` reduit la taille du tampon : un clic planifie dans 20 ms
    // doit pouvoir etre pose dans 20 ms.
    await _soloud.init(sampleRate: sampleRate, lowLatency: true);
  }

  /// Frequence d'echantillonnage demandee au moteur.
  ///
  /// Fixee ici plutot que relue apres coup : SoLoud garde la sienne privee, et
  /// un clic planifie a partir d'une frequence supposee tomberait a cote. On
  /// impose donc la valeur qu'on utilisera pour convertir les delais en
  /// echantillons, et les deux ne peuvent plus diverger.
  static const int sampleRate = 44100;

  @override
  Future<DroneVoice> startDrone({
    required double frequencyHz,
    double volume = 0.3,
    DroneTimbre timbre = DroneTimbre.dentDeScie,
  }) async {
    await start();
    final AudioSource source = await _soloud.loadWaveform(
      _ondePour(timbre),
      false,
      1,
      0,
    );
    _sources.add(source);
    _soloud.setWaveformFreq(source, frequencyHz);
    final SoundHandle handle = _soloud.play(source, volume: volume);
    _enCours.add(handle);
    return _SoloudDrone(
      soloud: _soloud,
      source: source,
      handle: handle,
      onStopped: () {
        _enCours.remove(handle);
        _sources.remove(source);
      },
    );
  }

  @override
  Future<void> scheduleClick({
    required Duration delay,
    PulseAccent accent = PulseAccent.beat,
  }) async {
    await start();
    final AudioSource source = await _sourceDeClic(accent);
    // Pose en pause, retarde, puis relache : c'est la sequence que SoLoud
    // demande, et l'instant est alors fige dans le moteur.
    final SoundHandle handle = _soloud.play(source, paused: true);
    final int echantillons = delay.inMicroseconds * sampleRate ~/ 1000000;
    if (echantillons > 0) {
      _soloud.setDelaySamples(handle, echantillons);
    }
    _soloud.setPause(handle, false);
    _enCours.add(handle);
    // La liste ne doit pas grandir indefiniment sur une seance longue : les
    // clics deja sonnes n'ont plus de voix a arreter.
    _enCours.removeWhere(
      (SoundHandle h) => h != handle && !_soloud.getIsValidVoiceHandle(h),
    );
  }

  Future<AudioSource> _sourceDeClic(PulseAccent accent) async {
    final AudioSource? deja = _clics[accent];
    if (deja != null) {
      return deja;
    }
    final AudioSource source = await _soloud.loadMem(
      'clic-${accent.name}.wav',
      ClickSound.forAccent(accent).wav(sampleRate: sampleRate),
    );
    _clics[accent] = source;
    _sources.add(source);
    return source;
  }

  static WaveForm _ondePour(DroneTimbre timbre) => switch (timbre) {
        DroneTimbre.sinus => WaveForm.sin,
        DroneTimbre.dentDeScie => WaveForm.saw,
        DroneTimbre.triangle => WaveForm.triangle,
      };

  @override
  Future<void> stopAll() async {
    if (!_reveille || !_soloud.isInitialized) {
      return;
    }
    // On arrete ce qu'on a lance, pas tout ce qui sonne dans le moteur : c'est
    // la meme chose aujourd'hui, et ce le restera meme si un jour deux choses
    // sonnent en meme temps.
    final List<SoundHandle> aArreter = List<SoundHandle>.of(_enCours);
    _enCours.clear();
    for (final SoundHandle handle in aArreter) {
      await _soloud.stop(handle);
    }
  }

  @override
  Future<void> dispose() async {
    if (!_reveille || !_soloud.isInitialized) {
      return;
    }
    await stopAll();
    for (final AudioSource source in _sources) {
      await _soloud.disposeSource(source);
    }
    _sources.clear();
    _clics.clear();
    _soloud.deinit();
  }
}

class _SoloudDrone implements DroneVoice {
  _SoloudDrone({
    required SoLoud soloud,
    required this.source,
    required this.handle,
    required this.onStopped,
  }) : _soloud = soloud;

  final SoLoud _soloud;
  final AudioSource source;
  final SoundHandle handle;
  final void Function() onStopped;
  bool _arrete = false;

  @override
  Future<void> setFrequency(double frequencyHz) async {
    if (_arrete) {
      return;
    }
    _soloud.setWaveformFreq(source, frequencyHz);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_arrete) {
      return;
    }
    _soloud.setVolume(handle, volume);
  }

  @override
  Future<void> stop() async {
    if (_arrete) {
      return;
    }
    _arrete = true;
    await _soloud.stop(handle);
    await _soloud.disposeSource(source);
    onStopped();
  }
}

/// Fabrique par defaut, injectee jusqu'aux ecrans qui emettent.
AudioEngine defaultAudioEngine() => SoloudAudioEngine();
