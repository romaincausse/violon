import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/audio/yin_isolate_analyzer.dart';
import 'record_audio_capture.dart';

/// Assemble la chaine audio reelle : micro, trames, YIN dans son isolate.
///
/// Vit dans `lib/platform/` parce que c'est ici, et seulement ici, qu'on
/// nomme l'implementation concrete de la capture. L'interface, elle, ne
/// connait qu'une fabrique.
Future<PitchSource> defaultPitchSource() async => MicrophonePitchSource(
      RecordAudioCapture(),
      analyzer: await YinIsolateAnalyzer.spawn(),
    );
