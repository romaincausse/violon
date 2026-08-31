import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/yin_isolate_analyzer.dart';

Float32List sinus(double frequenceHz, int n, {int sampleRate = 44100}) {
  final Float32List buffer = Float32List(n);
  for (int i = 0; i < n; i++) {
    buffer[i] = math.sin(2 * math.pi * frequenceHz * i / sampleRate);
  }
  return buffer;
}

void main() {
  group('YinIsolateAnalyzer', () {
    late YinIsolateAnalyzer analyseur;

    setUp(() async {
      analyseur = await YinIsolateAnalyzer.spawn();
    });

    tearDown(() async {
      await analyseur.dispose();
    });

    test('detecte une hauteur de l autre cote de l isolate', () async {
      final PitchEstimate? e = await analyseur.analyze(
        sinus(440, 2048),
        timestampMs: 123,
      );
      expect(e, isNotNull);
      expect(e!.frequencyHz, closeTo(440, 1));
      expect(e.nearestMidi, 69); // la4
    });

    test('l horodatage traverse l isolate intact', () async {
      final PitchEstimate? e = await analyseur.analyze(
        sinus(440, 2048),
        timestampMs: 4321,
      );
      expect(e!.timestampMs, 4321);
    });

    test('le silence revient a vide, pas en exception', () async {
      expect(
        await analyseur.analyze(Float32List(2048), timestampMs: 0),
        isNull,
      );
    });

    test('plusieurs analyses en vol reviennent chacune a son appelant',
        () async {
      // Chaque demande porte un numero : sans lui, deux analyses lancees
      // ensemble pourraient se repondre l'une a la place de l'autre.
      final List<PitchEstimate?> resultats = await Future.wait(
        <Future<PitchEstimate?>>[
          analyseur.analyze(sinus(220, 2048), timestampMs: 0),
          analyseur.analyze(sinus(440, 2048), timestampMs: 1),
          analyseur.analyze(sinus(880, 2048), timestampMs: 2),
        ],
      );
      expect(resultats[0]!.nearestMidi, 57); // la3
      expect(resultats[1]!.nearestMidi, 69); // la4
      expect(resultats[2]!.nearestMidi, 81); // la5
      expect(
          resultats.map((PitchEstimate? e) => e!.timestampMs), <int>[0, 1, 2]);
    });

    test('l isolate rend le meme resultat que l analyse sur place', () async {
      // Le deplacement dans un isolate ne doit rien changer au signal : le
      // buffer est transfere, pas recopie ni reinterprete.
      final Float32List signal = sinus(392, 2048); // sol4
      final PitchEstimate? via = await analyseur.analyze(
        Float32List.fromList(signal),
        timestampMs: 0,
      );
      final PitchEstimate? direct = await YinIsolateAnalyzer.spawn().then(
        (YinIsolateAnalyzer a) async {
          final PitchEstimate? r = await a.analyze(signal, timestampMs: 0);
          await a.dispose();
          return r;
        },
      );
      expect(via!.frequencyHz, direct!.frequencyHz);
    });

    test('une analyse en vol au moment de la liberation ne reste pas suspendue',
        () async {
      final YinIsolateAnalyzer jetable = await YinIsolateAnalyzer.spawn();
      final Future<PitchEstimate?> enVol = jetable.analyze(
        sinus(440, 2048),
        timestampMs: 0,
      );
      await jetable.dispose();
      // Sans denouement, ce `await` ne reviendrait jamais et le test
      // expirerait au bout de trente secondes.
      expect(await enVol, isNull);
    });

    test('analyser apres liberation est une erreur, pas un silence', () async {
      final YinIsolateAnalyzer jetable = await YinIsolateAnalyzer.spawn();
      await jetable.dispose();
      expect(
        () => jetable.analyze(sinus(440, 2048), timestampMs: 0),
        throwsStateError,
      );
    });
  });
}
