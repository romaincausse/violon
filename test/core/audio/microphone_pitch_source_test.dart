import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/audio_capture.dart';
import 'package:violon/core/audio/microphone_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';

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

/// Genere une sinusoide en PCM 16 bits petit-boutiste, comme le micro.
Uint8List sinus(double frequenceHz, int echantillons,
    {int sampleRate = 44100}) {
  final Uint8List bytes = Uint8List(echantillons * 2);
  final ByteData vue = ByteData.view(bytes.buffer);
  for (int i = 0; i < echantillons; i++) {
    final double v = math.sin(2 * math.pi * frequenceHz * i / sampleRate);
    vue.setInt16(i * 2, (v * 30000).round(), Endian.little);
  }
  return bytes;
}

void main() {
  group('MicrophonePitchSource', () {
    test('demande UNPROCESSED en premier', () async {
      final FakeCapture micro = FakeCapture();
      await MicrophonePitchSource(micro).start();
      expect(micro.demandes, <MicSource>[MicSource.unprocessed]);
    });

    test('retombe sur VOICE_RECOGNITION si UNPROCESSED est refusee', () async {
      // Le cas reel : `UNPROCESSED` existe depuis Android 7 mais reste
      // facultative pour les constructeurs. Sans repli, l'application ne
      // demarrerait pas du tout sur ces appareils.
      final FakeCapture micro = FakeCapture(
        refuse: <MicSource>{MicSource.unprocessed},
      );
      final MicrophonePitchSource source = MicrophonePitchSource(micro);
      await source.start();

      expect(micro.demandes, <MicSource>[
        MicSource.unprocessed,
        MicSource.voiceRecognition,
      ]);
      expect(source.activeSource, MicSource.voiceRecognition);
    });

    test('signale la source retenue, pour pouvoir l afficher', () async {
      final MicrophonePitchSource source = MicrophonePitchSource(FakeCapture());
      expect(source.activeSource, isNull);
      await source.start();
      expect(source.activeSource, MicSource.unprocessed);
    });

    test('echoue clairement si aucune source ne repond', () async {
      final MicrophonePitchSource source = MicrophonePitchSource(
        FakeCapture(refuse: MicSource.values.toSet()),
      );
      await expectLater(source.start(), throwsStateError);
      expect(source.activeSource, isNull);
    });

    test('un refus de permission a son propre type', () async {
      // L'interface doit pouvoir distinguer "il a dit non", ou l'on propose
      // d'ouvrir les reglages, de "le micro est casse".
      final MicrophonePitchSource source = MicrophonePitchSource(
        FakeCapture(permission: false),
      );
      await expectLater(
        source.start(),
        throwsA(isA<MicPermissionDenied>()),
      );
    });

    test('la permission est demandee avant d ouvrir le micro', () async {
      final FakeCapture micro = FakeCapture(permission: false);
      await expectLater(
        MicrophonePitchSource(micro).start(),
        throwsA(isA<MicPermissionDenied>()),
      );
      expect(micro.demandes, isEmpty);
    });

    test('un la3 joue au micro ressort en la3 detecte', () async {
      // Le test de bout en bout : octets PCM du micro, decoupage en trames,
      // YIN, hauteur. Aucun appareil, et pourtant toute la chaine est
      // parcourue.
      final FakeCapture micro = FakeCapture();
      final MicrophonePitchSource source = MicrophonePitchSource(micro);
      final Future<PitchEstimate> premiere = source.pitches.first;
      await source.start();

      micro.controleur.add(sinus(220, 4096)); // la3
      final PitchEstimate estimate = await premiere;

      expect(estimate.frequencyHz, closeTo(220, 1));
      expect(estimate.nearestMidi, 57); // la3
      expect(estimate.timestampMs, 0, reason: 'premiere trame de la prise');
    });

    test('les trames suivantes sont horodatees a leur place', () async {
      final FakeCapture micro = FakeCapture();
      final MicrophonePitchSource source = MicrophonePitchSource(micro);
      final Future<List<PitchEstimate>> deux = source.pitches.take(2).toList();
      await source.start();

      micro.controleur.add(sinus(440, 2048 * 2));
      final List<PitchEstimate> estimates = await deux;

      expect(estimates[0].timestampMs, 0);
      expect(estimates[1].timestampMs, 2048 * 1000 ~/ 44100);
    });

    test('le silence ne produit aucune hauteur', () async {
      final FakeCapture micro = FakeCapture();
      final MicrophonePitchSource source = MicrophonePitchSource(micro);
      final List<PitchEstimate> recues = <PitchEstimate>[];
      source.pitches.listen(recues.add);
      await source.start();

      micro.controleur.add(Uint8List(2048 * 2 * 3));
      await Future<void>.delayed(Duration.zero);

      expect(recues, isEmpty);
    });

    test('arreter ferme le micro, liberer ferme tout', () async {
      final FakeCapture micro = FakeCapture();
      final MicrophonePitchSource source = MicrophonePitchSource(micro);
      await source.start();
      await source.stop();
      expect(micro.arrets, 1);

      // Un second arret ne redemande rien : le micro est deja ferme.
      await source.stop();
      expect(micro.arrets, 1);

      await source.dispose();
      expect(micro.liberations, 1);
    });

    test('redemarrer remet l horloge des trames a zero', () async {
      final FakeCapture micro = FakeCapture();
      final MicrophonePitchSource source = MicrophonePitchSource(micro);

      await source.start();
      micro.controleur.add(sinus(440, 2048 * 2));
      await Future<void>.delayed(Duration.zero);

      final Future<PitchEstimate> apres = source.pitches.first;
      await source.start();
      micro.controleur.add(sinus(440, 2048));

      expect((await apres).timestampMs, 0);
    });
  });
}
