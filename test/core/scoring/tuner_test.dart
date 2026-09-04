import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/tuner.dart';

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
  group('Tuner', () {
    final Tuner accordeur = Tuner();

    test('reconnait les quatre cordes a vide', () {
      for (final (int midi, String nom) in <(int, String)>[
        (55, 'Sol3'),
        (62, 'Re4'),
        (69, 'La4'),
        (76, 'Mi5'),
      ]) {
        final TunerReading r = accordeur.read(entendu(midi, 0))!;
        expect(r.stringMidi, midi);
        expect(r.stringName, nom);
        expect(r.inTune, isTrue, reason: nom);
      }
    });

    test('dit de combien la corde est basse ou haute', () {
      expect(accordeur.read(entendu(69, -12))!.centsOffset, closeTo(-12, 0.1));
      expect(accordeur.read(entendu(69, 20))!.centsOffset, closeTo(20, 0.1));
    });

    test('une corde a dix cents n est pas juste', () {
      // L'oreille percoit environ cinq cents de battement entre deux cordes
      // voisines : une corde "juste a dix cents pres" ferait sonner faux tout
      // le reste.
      expect(accordeur.read(entendu(69, 10))!.inTune, isFalse);
      expect(accordeur.read(entendu(69, 3))!.inTune, isTrue);
    });

    test('une hauteur qui bouge ne donne pas de verdict', () {
      // Un archet qui demarre fait varier la hauteur de plusieurs dizaines de
      // cents. L'aiguille danserait sans rien dire d'utile.
      final TunerReading r =
          accordeur.read(entendu(69, 0, excursionCents: 60))!;
      expect(r.steady, isFalse);
      expect(r.inTune, isFalse, reason: 'pas de vert en traversant la cible');
    });

    test('une mesure peu sure est ignoree', () {
      expect(accordeur.read(entendu(69, 0, confidence: 0.2)), isNull);
    });

    test('une note qui n est aucune corde a vide est ignoree', () {
      // Do5 est a trois demi-tons du la4 : l'enfant joue autre chose.
      expect(accordeur.read(entendu(72, 0)), isNull);
    });

    test('entre deux cordes, la plus proche gagne', () {
      // Un peu au-dessus du re4 : c'est bien du re qu'il s'agit.
      expect(accordeur.read(entendu(62, 80))!.stringMidi, 62);
      // Un peu en dessous du la4.
      expect(accordeur.read(entendu(69, -80))!.stringMidi, 69);
    });

    group('diapason', () {
      test('un accordeur a 442 juge par rapport a 442', () {
        // Un enfant accorde a 442 joue son la a 442 Hz. Juge contre 440, il
        // serait haut de 8 cents alors qu'il est parfaitement juste.
        const SmoothedPitch la442 = SmoothedPitch(
          estimate: PitchEstimate(
            frequencyHz: 442,
            confidence: 1,
            timestampMs: 0,
          ),
          excursionCents: 0,
          vibrato: false,
        );
        expect(Tuner().read(la442)!.inTune, isFalse);
        expect(Tuner(a4: 442).read(la442)!.inTune, isTrue);
      });

      test('le la stable donne le diapason reel de l instrument', () {
        // C'est ce que demande la regle de justesse relative : juger les
        // doigts par rapport a l'instrument tel qu'il est accorde.
        final double? mesure = accordeur.measuredA4From(entendu(69, 8));
        expect(mesure, isNotNull);
        expect(
          PitchUtils.centsBetween(mesure!, 440),
          closeTo(8, 0.5),
        );
      });

      test('une autre corde ne donne pas le diapason', () {
        expect(accordeur.measuredA4From(entendu(62, 0)), isNull);
      });

      test('un la qui bouge ne donne pas le diapason', () {
        expect(
          accordeur.measuredA4From(entendu(69, 0, excursionCents: 60)),
          isNull,
        );
      });

      test('un la franchement faux est une corde a accorder, pas un diapason',
          () {
        // Cinquante cents separent deja 427 Hz de 440 : aucun orchestre ne
        // descend aussi bas. Au-dela, c'est la corde qui est fausse.
        expect(accordeur.measuredA4From(entendu(69, 80)), isNull);
      });
    });
  });
}
