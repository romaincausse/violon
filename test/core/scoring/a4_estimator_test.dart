import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/a4_estimator.dart';

SmoothedPitch entendu(
  int midi,
  double cents, {
  double excursionCents = 0,
  double confidence = 1,
}) {
  return SmoothedPitch(
    estimate: PitchEstimate(
      frequencyHz: PitchUtils.midiToFrequency(midi) *
          math.pow(2, cents / 1200).toDouble(),
      confidence: confidence,
      timestampMs: 0,
    ),
    excursionCents: excursionCents,
    vibrato: false,
  );
}

void main() {
  group('A4Estimator', () {
    test('une seule mesure ne confirme rien', () {
      // Le bug trouve sur l'appareil : le bruit d'une piece produit des
      // mesures que YIN juge fiables et que le lisseur juge stables.
      // L'accordeur proposait d'adopter un diapason alors que personne ne
      // jouait.
      final A4Estimator e = A4Estimator();
      expect(e.add(entendu(69, 20)), isNull);
      expect(e.confirmed, isNull);
    });

    test('une corde tenue finit par confirmer', () {
      final A4Estimator e = A4Estimator(confirmations: 6);
      double? confirme;
      for (int i = 0; i < 6; i++) {
        confirme = e.add(entendu(69, 8));
      }
      expect(confirme, isNotNull);
      expect(PitchUtils.centsBetween(confirme!, 440), closeTo(8, 0.5));
    });

    test('une serie interrompue recommence a zero', () {
      // Cinq mesures sur le la, puis une sur le re : rien n'est confirme.
      final A4Estimator e = A4Estimator(confirmations: 6);
      for (int i = 0; i < 5; i++) {
        e.add(entendu(69, 5));
      }
      expect(e.add(entendu(62, 0)), isNull);
      for (int i = 0; i < 5; i++) {
        expect(e.add(entendu(69, 5)), isNull);
      }
      expect(e.add(entendu(69, 5)), isNotNull);
    });

    test('une mesure instable interrompt la serie', () {
      final A4Estimator e = A4Estimator(confirmations: 3);
      e.add(entendu(69, 5));
      e.add(entendu(69, 5));
      expect(e.add(entendu(69, 5, excursionCents: 90)), isNull);
      expect(e.confirmed, isNull);
    });

    test('une serie qui se disperse ne confirme pas', () {
      // Une derive lente finirait par confirmer n'importe quoi si chaque
      // mesure n'etait comparee qu'a la precedente.
      final A4Estimator e = A4Estimator(confirmations: 4, spreadCents: 10);
      expect(e.add(entendu(69, 0)), isNull);
      expect(e.add(entendu(69, 4)), isNull);
      expect(e.add(entendu(69, 8)), isNull);
      expect(e.add(entendu(69, 25)), isNull, reason: 'trop loin du depart');
      expect(e.confirmed, isNull);
    });

    test('le diapason confirme est la mediane de la serie', () {
      final A4Estimator e = A4Estimator(confirmations: 5, spreadCents: 20);
      for (final double cents in <double>[6, 10, 8, 9, 7]) {
        e.add(entendu(69, cents));
      }
      expect(PitchUtils.centsBetween(e.confirmed!, 440), closeTo(8, 0.5));
    });

    test('remettre a zero oublie le diapason confirme', () {
      final A4Estimator e = A4Estimator(confirmations: 2);
      e.add(entendu(69, 5));
      e.add(entendu(69, 5));
      expect(e.confirmed, isNotNull);
      e.reset();
      expect(e.confirmed, isNull);
    });
  });
}
