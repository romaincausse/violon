import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/audio_capture.dart';
import 'package:violon/core/audio/microphone_pitch_source.dart';
import 'package:violon/core/audio/pitch_analyzer.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';

import 'fake_capture.dart';

/// Analyseur dont le test decide quand il repond.
///
/// Sert a mettre la chaine sous pression sans dependre de la vitesse reelle
/// de YIN : c'est le seul moyen de tester ce qui arrive quand l'analyse ne
/// suit plus.
class AnalyseurPilote implements PitchAnalyzer {
  final List<int> recues = <int>[];
  final List<Completer<PitchEstimate?>> _attente =
      <Completer<PitchEstimate?>>[];
  int liberations = 0;

  @override
  Future<PitchEstimate?> analyze(
    Float32List samples, {
    required int timestampMs,
  }) {
    recues.add(timestampMs);
    final Completer<PitchEstimate?> c = Completer<PitchEstimate?>();
    _attente.add(c);
    return c.future;
  }

  /// Repond a la plus ancienne analyse en attente.
  Future<void> repondre({double frequencyHz = 440}) async {
    final Completer<PitchEstimate?> c = _attente.removeAt(0);
    c.complete(
      PitchEstimate(
        frequencyHz: frequencyHz,
        confidence: 1,
        timestampMs: recues[recues.length - _attente.length - 1],
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

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

      // Trois trames de silence, puis une note. Attendre la note prouve que
      // le silence a bien eu le temps d'etre analyse : sans elle, le test
      // passerait aussi longtemps que rien n'a encore ete analyse.
      final Future<PitchEstimate> note = source.pitches.first;
      micro.controleur.add(Uint8List(2048 * 2 * 3));
      micro.controleur.add(sinus(440, 2048));
      await note;

      expect(recues, hasLength(1));
      expect(recues.single.nearestMidi, 69); // la4
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

  group('MicrophonePitchSource sous pression', () {
    /// Envoie [combien] trames de suite, dans un seul paquet.
    Future<void> envoyer(FakeCapture micro, int combien) async {
      micro.controleur.add(sinus(440, 2048 * combien));
      await Future<void>.delayed(Duration.zero);
    }

    test('une seule analyse est en vol a la fois', () async {
      // C'est ce qui garantit l'ordre des hauteurs. Les lancer en parallele
      // irait plus vite et rendrait le resultat inutilisable.
      final FakeCapture micro = FakeCapture();
      final AnalyseurPilote analyseur = AnalyseurPilote();
      final MicrophonePitchSource source =
          MicrophonePitchSource(micro, analyzer: analyseur);
      await source.start();

      await envoyer(micro, 3);
      expect(analyseur.recues, hasLength(1));

      await analyseur.repondre();
      expect(analyseur.recues, hasLength(2));
    });

    test('les hauteurs sortent dans l ordre des trames', () async {
      final FakeCapture micro = FakeCapture();
      final AnalyseurPilote analyseur = AnalyseurPilote();
      final MicrophonePitchSource source =
          MicrophonePitchSource(micro, analyzer: analyseur);
      final List<int> sorties = <int>[];
      source.pitches.listen((PitchEstimate e) => sorties.add(e.timestampMs));
      await source.start();

      await envoyer(micro, 3);
      await analyseur.repondre();
      await analyseur.repondre();
      await analyseur.repondre();

      expect(sorties, <int>[
        0,
        2048 * 1000 ~/ 44100,
        2 * 2048 * 1000 ~/ 44100,
      ]);
    });

    test(
        'quand l analyse ne suit plus, ce sont les vieilles trames qui sautent',
        () async {
      // En temps reel, une hauteur en retard ne sert a rien : mieux vaut un
      // trou dans le retour visuel qu'un retour juste mais decale.
      final FakeCapture micro = FakeCapture();
      final AnalyseurPilote analyseur = AnalyseurPilote();
      final MicrophonePitchSource source =
          MicrophonePitchSource(micro, analyzer: analyseur);
      await source.start();

      await envoyer(micro, 10);

      // Une en vol, quatre en attente, cinq jetees.
      expect(source.droppedFrames, 5);

      // Les quatre gardees sont les plus recentes.
      for (int i = 0; i < 5; i++) {
        await analyseur.repondre();
      }
      // Multiplier puis diviser, jamais l'inverse : arrondir la duree d'une
      // trame puis la multiplier par neuf donnerait 414 ms au lieu de 417.
      int debutDe(int trame) => trame * 2048 * 1000 ~/ 44100;
      expect(analyseur.recues, <int>[
        debutDe(0),
        debutDe(6),
        debutDe(7),
        debutDe(8),
        debutDe(9),
      ]);
    });

    test('rien n est jete quand l analyse suit', () async {
      final FakeCapture micro = FakeCapture();
      final AnalyseurPilote analyseur = AnalyseurPilote();
      final MicrophonePitchSource source =
          MicrophonePitchSource(micro, analyzer: analyseur);
      await source.start();

      await envoyer(micro, 4);
      expect(source.droppedFrames, 0);
    });

    test('redemarrer repart d une file vide et d un compteur a zero', () async {
      final FakeCapture micro = FakeCapture();
      final AnalyseurPilote analyseur = AnalyseurPilote();
      final MicrophonePitchSource source =
          MicrophonePitchSource(micro, analyzer: analyseur);
      await source.start();
      await envoyer(micro, 10);
      expect(source.droppedFrames, greaterThan(0));

      await source.start();
      expect(source.droppedFrames, 0);
    });

    test('liberer la source libere l analyseur', () async {
      final AnalyseurPilote analyseur = AnalyseurPilote();
      await MicrophonePitchSource(FakeCapture(), analyzer: analyseur).dispose();
      expect(analyseur.liberations, 1);
    });
  });

  group('MicrophonePitchSource et le lissage', () {
    test('le meme flux est lu en hauteurs ou en detail', () async {
      // Les deux vues ne dupliquent rien : l'accordeur veut l'excursion et le
      // vibrato, la partition ne veut que la hauteur.
      final FakeCapture micro = FakeCapture();
      final MicrophonePitchSource source = MicrophonePitchSource(micro);
      final Future<PitchEstimate> hauteur = source.pitches.first;
      final Future<SmoothedPitch> detail = source.smoothedPitches.first;
      await source.start();

      micro.controleur.add(sinus(440, 2048));

      expect((await detail).frequencyHz, (await hauteur).frequencyHz);
    });

    test('une erreur d octave isolee n atteint pas la partition', () async {
      // C'est la raison d'etre du lissage a cet endroit : YIN se trompe
      // parfois d'octave sur une trame, et la note passerait au rouge.
      final FakeCapture micro = FakeCapture();
      final MicrophonePitchSource source = MicrophonePitchSource(micro);
      final Future<List<PitchEstimate>> trois = source.pitches.take(3).toList();
      await source.start();

      micro.controleur.add(sinus(440, 2048));
      micro.controleur.add(sinus(880, 2048)); // l'octave parasite
      micro.controleur.add(sinus(440, 2048));

      final List<PitchEstimate> recues = await trois;
      expect(recues.last.nearestMidi, 69, reason: 'la4, pas la5');
    });

    test('redemarrer oublie le lissage de la prise precedente', () async {
      final FakeCapture micro = FakeCapture();
      final MicrophonePitchSource source = MicrophonePitchSource(micro);
      await source.start();
      micro.controleur.add(sinus(880, 2048 * 3));
      await Future<void>.delayed(Duration.zero);

      final Future<PitchEstimate> apres = source.pitches.first;
      await source.start();
      micro.controleur.add(sinus(440, 2048));

      expect((await apres).nearestMidi, 69, reason: 'aucune trace du la5');
    });
  });
}
