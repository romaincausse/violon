import 'dart:async';
import 'dart:typed_data';

import 'package:violon/core/audio/audio_capture.dart';

/// Micro scripte. Permet de tester toute la chaine -- octets, trames, YIN --
/// sans appareil, ce qui est justement la raison d'etre de [AudioCapture].
class FakeCapture implements AudioCapture {
  FakeCapture({
    this.permission = true,
    this.refuse = const <MicSource>{},
  });

  final bool permission;

  /// Sources que cet appareil refuse. Un telephone qui ne sait pas faire
  /// d'`UNPROCESSED` leve, il ne rend pas un flux vide.
  final Set<MicSource> refuse;

  final List<MicSource> demandes = <MicSource>[];
  int arrets = 0;
  int liberations = 0;
  late StreamController<Uint8List> controleur;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start({
    required int sampleRate,
    required MicSource source,
  }) async {
    demandes.add(source);
    if (refuse.contains(source)) {
      throw StateError('source $source indisponible');
    }
    controleur = StreamController<Uint8List>();
    return controleur.stream;
  }

  @override
  Future<void> stop() async => arrets++;

  @override
  Future<void> dispose() async => liberations++;
}
