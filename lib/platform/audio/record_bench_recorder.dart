import 'dart:async';
import 'dart:io';

import 'package:record/record.dart';

import '../../core/audio/bench_recorder.dart';

/// [BenchRecorder] sur le paquet `record`, avec les reglages exacts de
/// `RecordAudioCapture` : meme source, memes traitements coupes.
///
/// **Les prises vont dans le dossier prive de l'application**, pas dans la
/// galerie ni les telechargements : aucune autre application ne les voit, et
/// seul `adb run-as` -- qui ne marche que sur une version de debug -- sait les
/// lire. Desinstaller l'application les efface.
class RecordBenchRecorder implements BenchRecorder {
  RecordBenchRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// `/data/user/0/<paquet>/banc` : sur Android, le dossier temporaire de
  /// Dart est le cache de l'application, que le systeme peut vider. Son
  /// parent ne l'est jamais.
  Directory get _dossier =>
      Directory('${Directory.systemTemp.parent.path}/banc');

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String name) async {
    final Directory dossier = await _dossier.create(recursive: true);
    final List<BenchTake> deja = await takes();
    final String nom = nomLibre(name, deja.map((BenchTake t) => t.name));
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.unprocessed,
        ),
      ),
      path: '${dossier.path}/$nom.wav',
    );
  }

  @override
  Stream<double> level() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((Amplitude a) => a.current);

  @override
  Future<BenchTake?> stop() async {
    final String? chemin = await _recorder.stop();
    if (chemin == null) {
      return null;
    }
    final File f = File(chemin);
    return BenchTake(
      name: f.uri.pathSegments.last.replaceAll('.wav', ''),
      bytes: await f.length(),
    );
  }

  @override
  Future<List<BenchTake>> takes() async {
    if (!await _dossier.exists()) {
      return const <BenchTake>[];
    }
    final List<File> fichiers = <File>[
      await for (final FileSystemEntity e in _dossier.list())
        if (e is File && e.path.endsWith('.wav')) e,
    ]..sort((File a, File b) =>
        a.statSync().modified.compareTo(b.statSync().modified));
    return <BenchTake>[
      for (final File f in fichiers)
        BenchTake(
          name: f.uri.pathSegments.last.replaceAll('.wav', ''),
          bytes: f.lengthSync(),
        ),
    ];
  }

  @override
  Future<void> delete(String name) async {
    final File f = File('${_dossier.path}/$name.wav');
    if (await f.exists()) {
      await f.delete();
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

BenchRecorder defaultBenchRecorder() => RecordBenchRecorder();
