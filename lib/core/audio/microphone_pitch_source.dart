import 'dart:async';
import 'dart:typed_data';

import 'audio_capture.dart';
import 'pcm_framer.dart';
import 'pitch_estimate.dart';
import 'pitch_source.dart';
import 'yin_detector.dart';

/// Levee quand l'utilisateur refuse l'acces au micro.
///
/// Un type a part plutot qu'un message : l'interface doit pouvoir distinguer
/// "il a dit non" -- ou l'on propose d'ouvrir les reglages -- de "le micro est
/// casse", ou l'on ne peut rien faire.
class MicPermissionDenied implements Exception {
  const MicPermissionDenied();

  @override
  String toString() => 'Acces au micro refuse';
}

/// La chaine complete : octets du micro, trames, YIN, hauteurs.
///
/// Du Dart pur : elle ne connait pas le paquet de capture, seulement
/// [AudioCapture]. C'est ce qui permet de la tester en entier, de la source
/// physique jusqu'a la note detectee, sans micro et sans widget.
class MicrophonePitchSource implements PitchSource {
  MicrophonePitchSource(
    this.capture, {
    this.sampleRate = 44100,
    int frameSize = 2048,
    YinDetector? detector,
  })  : _framer = PcmFramer(frameSize: frameSize, sampleRate: sampleRate),
        _detector = detector ?? YinDetector(sampleRate: sampleRate);

  /// Ordre d'essai des sources. La premiere qui demarre gagne.
  static const List<MicSource> sourcePreference = <MicSource>[
    MicSource.unprocessed,
    MicSource.voiceRecognition,
  ];

  final AudioCapture capture;
  final int sampleRate;

  final PcmFramer _framer;
  final YinDetector _detector;
  final StreamController<PitchEstimate> _controller =
      StreamController<PitchEstimate>.broadcast();

  StreamSubscription<Uint8List>? _subscription;
  MicSource? _activeSource;

  /// Source retenue par le dernier [start], ou `null` a l'arret.
  ///
  /// Vaut la peine d'etre exposee : si l'appareil est retombe sur le repli,
  /// la detection sera moins stable, et on veut pouvoir le dire plutot que de
  /// laisser croire a un probleme de jeu.
  MicSource? get activeSource => _activeSource;

  @override
  Stream<PitchEstimate> get pitches => _controller.stream;

  /// Zero tant que la calibration n'a pas eu lieu (lot A4). Tant qu'elle vaut
  /// zero, la notation du rythme n'a pas de sens : celle de la justesse, si.
  @override
  int get latencyMs => 0;

  @override
  Future<void> start() async {
    if (!await capture.hasPermission()) {
      throw const MicPermissionDenied();
    }
    await stop();
    _framer.reset();

    final Stream<Uint8List> octets = await _ouvrir();
    _subscription = octets.listen(_onBytes);
  }

  /// Essaie les sources dans l'ordre, et rend le flux de la premiere qui
  /// accepte.
  ///
  /// `UNPROCESSED` n'existe qu'a partir d'Android 7 et reste **facultative**
  /// pour les constructeurs : un appareil recent peut parfaitement la
  /// refuser. Sans repli, l'application ne demarrerait pas du tout sur ces
  /// appareils.
  Future<Stream<Uint8List>> _ouvrir() async {
    Object? derniereErreur;
    for (final MicSource source in sourcePreference) {
      try {
        final Stream<Uint8List> flux = await capture.start(
          sampleRate: sampleRate,
          source: source,
        );
        _activeSource = source;
        return flux;
      } catch (e) {
        derniereErreur = e;
      }
    }
    _activeSource = null;
    throw StateError('Aucune source micro utilisable : $derniereErreur');
  }

  void _onBytes(Uint8List bytes) {
    for (final PcmFrame frame in _framer.addBytes(bytes)) {
      // YIN tourne ici, sur l'isolate principal. Le lot A2 le deplacera :
      // 2048 echantillons coutent quelques millisecondes, ce qui se voit sur
      // l'animation du curseur.
      final PitchEstimate? estimate = _detector.detect(
        frame.samples,
        timestampMs: frame.timestampMs,
      );
      if (estimate != null && !_controller.isClosed) {
        _controller.add(estimate);
      }
    }
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_activeSource != null) {
      await capture.stop();
      _activeSource = null;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await capture.dispose();
    await _controller.close();
  }
}
