import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/tuner.dart';
import 'package:violon/core/scoring/tuning_advice.dart';

/// Une hauteur lissee a [cents] de la note [midi].
SmoothedPitch entendu(
  int midi,
  double cents, {
  double confidence = 1,
  double excursionCents = 0,
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
  final Tuner accordeur = Tuner();
  const TuningCoach coach = TuningCoach();

  /// Le conseil donne sur une corde entendue a [cents] de sa hauteur.
  TuningAdvice conseil(int midi, double cents, {double excursionCents = 0}) =>
      coach.advise(
        accordeur.read(
          entendu(midi, cents, excursionCents: excursionCents),
        ),
      );

  group('TuningCoach', () {
    test('sans rien entendre, il ne conseille rien', () {
      expect(coach.advise(null).action, TuningAction.play);
      expect(coach.advise(null).turns, isFalse);
    });

    test('une note qui bouge encore ne se corrige pas', () {
      // Un archet qui demarre fait varier la hauteur de plusieurs dizaines de
      // cents. Conseiller un geste a cet instant, c'est le conseiller au
      // hasard -- et l'enfant tournerait pour rien.
      final TuningAdvice a = conseil(55, -40, excursionCents: 60);
      expect(a.action, TuningAction.hold);
      expect(a.turns, isFalse);
      expect(a.stringMidi, 55);
    });

    test('une corde juste ne se touche plus', () {
      final TuningAdvice a = conseil(69, 1);
      expect(a.action, TuningAction.stop);
      expect(a.turns, isFalse);
    });

    test('trop bas, on tend ; trop haut, on detend', () {
      // La seule convention du lot. Une inversion ici ferait casser une corde
      // a un enfant qui fait confiance a l'ecran.
      expect(conseil(55, -30).turn, TuningTurn.tighten);
      expect(conseil(55, 30).turn, TuningTurn.loosen);
    });

    test('petit ecart : le tendeur ; gros ecart : la cheville', () {
      // Un tendeur arrive en butee passe une vingtaine de cents, et l'enfant
      // force alors sur une vis au lieu de prendre la cheville.
      expect(conseil(62, -10).action, TuningAction.fineTuner);
      expect(conseil(62, -80).action, TuningAction.peg);
    });

    test('le passage au tendeur se fait au seuil annonce', () {
      const TuningCoach serre = TuningCoach(fineTunerRangeCents: 20);
      TuningAdvice a(double cents) =>
          serre.advise(accordeur.read(entendu(76, cents)));
      expect(a(19).action, TuningAction.fineTuner);
      expect(a(21).action, TuningAction.peg);
    });

    test('un violon sans tendeur renvoie toujours a la cheville', () {
      // Certains instruments n'en portent qu'un, sur le mi. Envoyer vers une
      // vis qui n'existe pas serait pire que de ne rien dire.
      const TuningCoach unSeul = TuningCoach(fineTuners: <int>[76]);
      expect(
        unSeul.advise(accordeur.read(entendu(55, -10))).action,
        TuningAction.peg,
      );
      expect(
        unSeul.advise(accordeur.read(entendu(76, -10))).action,
        TuningAction.fineTuner,
      );
    });

    test('le geste se resserre a mesure qu on approche', () {
      // C'est ainsi que se dit le "quand s arreter" : il ne se dit pas, il se
      // voit -- la cheville, puis le tendeur, puis plus rien.
      expect(conseil(55, -120).action, TuningAction.peg);
      expect(conseil(55, -15).action, TuningAction.fineTuner);
      expect(conseil(55, -2).action, TuningAction.stop);
    });
  });
}
