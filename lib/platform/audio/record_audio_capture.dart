import 'dart:typed_data';

import 'package:record/record.dart';

import '../../core/audio/audio_capture.dart';

/// [AudioCapture] appuyee sur le paquet `record`.
///
/// **Le seul fichier du projet qui connaisse ce paquet.** Il vit hors de
/// `lib/core/` parce qu'il ne se teste pas sans appareil : tout ce qui se
/// teste -- decoupage des trames, repli de source, detection -- est au-dessus,
/// en Dart pur.
///
/// Changer de paquet de capture, ou porter sur iOS, se limite a ecrire une
/// autre classe a cet endroit.
class RecordAudioCapture implements AudioCapture {
  RecordAudioCapture({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start({
    required int sampleRate,
    required MicSource source,
  }) {
    return _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // Les trois traitements que le projet combat, coupes explicitement.
        // La source choisie ci-dessous les desactive deja en principe, mais
        // rien n'oblige un constructeur a la respecter.
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(audioSource: _androidSource(source)),
      ),
    );
  }

  static AndroidAudioSource _androidSource(MicSource source) =>
      switch (source) {
        MicSource.unprocessed => AndroidAudioSource.unprocessed,
        MicSource.voiceRecognition => AndroidAudioSource.voiceRecognition,
      };

  @override
  Future<void> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
