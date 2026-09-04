import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/music/pitch_utils.dart';

/// Une mesure a [cents] de la note temperee [midi].
PitchEstimate mesure(int midi, double cents, {int timestampMs = 0}) {
  return PitchEstimate(
    frequencyHz:
        PitchUtils.midiToFrequency(midi) * math.pow(2, cents / 1200).toDouble(),
    confidence: 1,
    timestampMs: timestampMs,
  );
}

/// Ecart en cents entre une hauteur lissee et une note temperee.
double centsDe(SmoothedPitch p, int midi) =>
    PitchUtils.centsBetween(p.frequencyHz, PitchUtils.midiToFrequency(midi));

void main() {
  group('PitchSmoother', () {
    test('la premiere mesure ressort telle quelle', () {
      final SmoothedPitch p = PitchSmoother().add(mesure(69, 12));
      expect(centsDe(p, 69), closeTo(12, 0.01));
      expect(p.excursionCents, 0);
      expect(p.vibrato, isFalse);
    });

    test('une erreur d octave isolee est ignoree', () {
      // YIN se trompe parfois d'octave sur une trame. Une moyenne deplacerait
      // la hauteur de plusieurs centaines de cents ; la mediane l'ignore.
      final PitchSmoother s = PitchSmoother();
      s.add(mesure(69, 0));
      s.add(mesure(81, 0)); // une octave trop haut
      final SmoothedPitch p = s.add(mesure(69, 0));
      expect(centsDe(p, 69), closeTo(0, 1));
    });

    test('le bruit de mesure est resserre', () {
      final PitchSmoother s = PitchSmoother();
      s.add(mesure(69, -8));
      s.add(mesure(69, 11));
      final SmoothedPitch p = s.add(mesure(69, 2));
      // La mediane de -8, 11 et 2 vaut 2, pas la moyenne 1,67.
      expect(centsDe(p, 69), closeTo(2, 0.5));
    });

    test('l horodatage et la confiance suivent la derniere mesure', () {
      final PitchSmoother s = PitchSmoother();
      s.add(mesure(69, 0));
      final SmoothedPitch p = s.add(mesure(69, 5, timestampMs: 460));
      expect(p.timestampMs, 460);
      expect(p.estimate.confidence, 1);
    });

    group('la mediane ne franchit pas les notes', () {
      test('deux mesures suffisent a basculer sur la note suivante', () {
        // Sans remise a zero, la mediane rendrait une hauteur qui n'a jamais
        // ete jouee, pile entre les deux notes.
        final PitchSmoother s = PitchSmoother();
        s.add(mesure(69, 0));
        s.add(mesure(69, 0));
        s.add(mesure(71, 0)); // un ton plus haut
        final SmoothedPitch p = s.add(mesure(71, 0));
        expect(centsDe(p, 71), closeTo(0, 1));
      });

      test('un demi-ton compte comme une note nouvelle', () {
        // Le plus petit intervalle melodique doit suffire : sinon chaque
        // do -> do# trainerait la note precedente derriere lui.
        final PitchSmoother s = PitchSmoother();
        s.add(mesure(69, 0));
        s.add(mesure(69, 0));
        s.add(mesure(70, 0));
        final SmoothedPitch p = s.add(mesure(70, 0));
        expect(centsDe(p, 70), closeTo(0, 1));
      });

      test('la premiere trame de la note nouvelle n est pas perdue', () {
        // Elle sert de point de depart au nouvel historique : la jeter
        // rognerait le debut de chaque note.
        final PitchSmoother s = PitchSmoother();
        s.add(mesure(69, 0));
        s.add(mesure(69, 0));
        s.add(mesure(71, 30)); // premiere trame de la note, un peu haute
        final SmoothedPitch p = s.add(mesure(71, 10));
        // La mediane de 30 et 10 vaut 20 : les deux trames ont compte.
        expect(centsDe(p, 71), closeTo(20, 2));
      });

      test('une trame de retard, et c est assume', () {
        // Le prix a payer pour ne pas confondre un vibrato large avec un
        // changement de note. A 46 ms la trame, la couleur d'une note arrive
        // 46 ms tard : invisible a l'oeil, et sans effet sur la justesse,
        // qui se juge sur la duree de la note.
        final PitchSmoother s = PitchSmoother();
        s.add(mesure(69, 0));
        s.add(mesure(69, 0));
        final SmoothedPitch premiere = s.add(mesure(71, 0));
        expect(centsDe(premiere, 69), closeTo(0, 1),
            reason: 'la premiere trame rend encore la note precedente');
      });

      test('un vibrato large ne passe pas pour un changement de note', () {
        // Plus ou moins cinquante cents saute de cent cents d'une trame a
        // l'autre, soit exactement l'ecart d'un demi-ton. Ce qui les separe,
        // c'est qu'un vibrato repart aussitot dans l'autre sens.
        final PitchSmoother s = PitchSmoother();
        SmoothedPitch? dernier;
        for (int i = 0; i < 12; i++) {
          dernier = s.add(mesure(69, i.isEven ? -50 : 50, timestampMs: i * 46));
        }
        expect(dernier!.excursionCents, closeTo(100, 2));
        // La note reste le la4 : aucune bascule vers une note voisine.
        expect(centsDe(dernier, 69).abs(), lessThanOrEqualTo(50 + 1));
      });
    });

    group('reconnaissance du vibrato', () {
      /// Nourrit le lisseur d'une oscillation de [amplitudeCents] autour de
      /// la note [midi], sur [combien] trames.
      PitchSmoother oscillation(
        int midi,
        double amplitudeCents, {
        int combien = 20,
        int periodeEnTrames = 4,
      }) {
        final PitchSmoother s = PitchSmoother();
        for (int i = 0; i < combien; i++) {
          final double phase = 2 * math.pi * i / periodeEnTrames;
          s.add(mesure(midi, amplitudeCents * math.sin(phase),
              timestampMs: i * 46));
        }
        return s;
      }

      test('une note tenue bien droite n est pas un vibrato', () {
        final PitchSmoother s = PitchSmoother();
        SmoothedPitch? dernier;
        for (int i = 0; i < 20; i++) {
          dernier = s.add(mesure(69, 2, timestampMs: i * 46));
        }
        expect(dernier!.vibrato, isFalse);
      });

      test('une oscillation reguliere et ample est un vibrato', () {
        final PitchSmoother s = oscillation(69, 40);
        final SmoothedPitch p = s.add(mesure(69, 0, timestampMs: 999));
        expect(p.vibrato, isTrue);
      });

      test('une oscillation minuscule reste du bruit de mesure', () {
        final PitchSmoother s = oscillation(69, 3);
        final SmoothedPitch p = s.add(mesure(69, 0, timestampMs: 999));
        expect(p.vibrato, isFalse);
      });

      test('une derive lente n est pas un vibrato', () {
        // Un enfant qui glisse doucement vers la note traverse une seule fois
        // sa hauteur centrale ; un vibrato la traverse a chaque demi-periode.
        final PitchSmoother s = PitchSmoother();
        SmoothedPitch? dernier;
        for (int i = 0; i < 20; i++) {
          dernier = s.add(mesure(69, -40 + i * 4, timestampMs: i * 46));
        }
        expect(dernier!.vibrato, isFalse);
      });

      test('il faut assez de recul pour se prononcer', () {
        // Sur trois trames, une oscillation et un simple bruit se
        // ressemblent : on ne dit rien plutot que de se tromper.
        final PitchSmoother s = oscillation(69, 40, combien: 3);
        final SmoothedPitch p = s.add(mesure(69, 0));
        expect(p.vibrato, isFalse);
      });

      test('l excursion est mesuree en cents, crete a crete', () {
        final PitchSmoother s = oscillation(69, 30);
        final SmoothedPitch p = s.add(mesure(69, 30, timestampMs: 999));
        expect(p.excursionCents, closeTo(60, 5));
      });
    });

    test('remettre a zero oublie la prise precedente', () {
      final PitchSmoother s = PitchSmoother();
      s.add(mesure(81, 0));
      s.add(mesure(81, 0));
      s.reset();
      final SmoothedPitch p = s.add(mesure(69, 0));
      expect(centsDe(p, 69), closeTo(0, 1));
      expect(p.excursionCents, 0);
    });
  });
}
