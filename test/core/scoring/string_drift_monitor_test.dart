import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_smoother.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/scoring/string_drift_monitor.dart';
import 'package:violon/core/scoring/tuner.dart';

const int sol3 = 55;
const int re4 = 62;
const int la4 = 69;
const int mi5 = 76;

/// Une hauteur lissee a [cents] de la note [midi].
SmoothedPitch entendu(
  int midi,
  double cents, {
  double confidence = 1,
  double excursionCents = 0,
  bool vibrato = false,
}) {
  return SmoothedPitch(
    estimate: PitchEstimate(
      frequencyHz: PitchUtils.midiToFrequency(midi) *
          math.pow(2, cents / 1200).toDouble(),
      confidence: confidence,
      timestampMs: 0,
    ),
    excursionCents: excursionCents,
    vibrato: vibrato,
  );
}

/// Joue [fois] fois la corde [midi] a [cents], et rend la derive signalee.
StringDrift? jouer(
  StringDriftMonitor moniteur,
  int midi,
  double cents, {
  int fois = 6,
}) {
  StringDrift? signalee;
  for (int i = 0; i < fois; i++) {
    signalee ??= moniteur.observe(entendu(midi, cents));
  }
  return signalee;
}

void main() {
  group('StringDriftMonitor', () {
    test('une corde juste ne declenche rien', () {
      final StringDriftMonitor m = StringDriftMonitor();
      expect(jouer(m, la4, 2), isNull);
      expect(m.drifts, isEmpty);
    });

    test('une corde qui a baisse est signalee', () {
      final StringDriftMonitor m = StringDriftMonitor();
      final StringDrift? derive = jouer(m, mi5, -22);

      expect(derive, isNotNull);
      expect(derive!.stringMidi, mi5);
      expect(derive.centsOffset, closeTo(-22, 1));
      expect(derive.flat, isTrue);
      expect(derive.stringName, 'Mi5');
    });

    test('une corde qui a monte est signalee aussi', () {
      final StringDrift? derive = jouer(StringDriftMonitor(), sol3, 20);
      expect(derive, isNotNull);
      expect(derive!.flat, isFalse);
    });

    test('UN DOIGT MAL POSE NE FAIT PAS ACCORDER L INSTRUMENT', () {
      // Le lot tout entier tient a ce test. Un re joue au quatrieme doigt sur
      // la corde de sol tombe exactement sur la frequence du re a vide : rien
      // ne distingue les deux a l'oreille de YIN.
      //
      // Le discriminant est qu'une corde a vide ne PEUT PAS etre jouee faux :
      // sa hauteur est mecaniquement fixe, donc identique a chaque fois. Un
      // doigt se pose un peu differemment a chaque occurrence.
      //
      // Ici l'enfant est bas en moyenne -- bien au-dela du seuil d'alerte --
      // mais il est bas *differemment* a chaque fois. Envoyer accorder un
      // instrument juste serait pire que se taire.
      final StringDriftMonitor m = StringDriftMonitor();
      const List<double> doigtHesitant = <double>[-30, -8, -45, -19, -37, -12];
      for (final double cents in doigtHesitant) {
        expect(m.observe(entendu(re4, cents)), isNull);
      }
      expect(m.drifts, isEmpty);
    });

    test('un vibrato n est jamais une corde a vide', () {
      // On ne fait pas de vibrato sur une corde a vide : la mesure est donc
      // celle d'un doigt, meme si elle tombe sur la bonne frequence.
      final StringDriftMonitor m = StringDriftMonitor();
      for (int i = 0; i < 10; i++) {
        expect(m.observe(entendu(la4, -25, vibrato: true)), isNull);
      }
      expect(m.drifts, isEmpty);
    });

    test('une hauteur instable est ecartee', () {
      // Un archet qui demarre fait glisser la hauteur de plusieurs dizaines
      // de cents. Ce n'est pas une mesure de l'accord.
      final StringDriftMonitor m = StringDriftMonitor();
      for (int i = 0; i < 10; i++) {
        expect(m.observe(entendu(la4, -25, excursionCents: 60)), isNull);
      }
      expect(m.drifts, isEmpty);
    });

    test('le silence et le bruit ne disent rien', () {
      final StringDriftMonitor m = StringDriftMonitor();
      for (int i = 0; i < 10; i++) {
        expect(m.observe(entendu(la4, -25, confidence: 0.2)), isNull);
      }
      expect(m.drifts, isEmpty);
    });

    test('une derive n est signalee qu une fois', () {
      // C'est un evenement, pas un etat : sans ca, l'application enverrait
      // accorder a chaque trame.
      final StringDriftMonitor m = StringDriftMonitor();
      expect(jouer(m, mi5, -25), isNotNull);
      for (int i = 0; i < 10; i++) {
        expect(m.observe(entendu(mi5, -25)), isNull);
      }
      expect(m.driftFor(mi5), isNotNull, reason: "l'etat, lui, demeure");
    });

    test('accorder la corde fait taire l alerte', () {
      final StringDriftMonitor m = StringDriftMonitor();
      expect(jouer(m, mi5, -25), isNotNull);

      // L'enfant accorde. Les mesures recentes redeviennent justes, et les
      // anciennes ne doivent plus peser.
      jouer(m, mi5, 1, fois: 6);
      expect(m.driftFor(mi5), isNull);
      expect(m.drifts, isEmpty);
    });

    test('et une corde qui redescend est re-signalee', () {
      final StringDriftMonitor m = StringDriftMonitor();
      expect(jouer(m, mi5, -25), isNotNull);
      jouer(m, mi5, 1, fois: 6);
      expect(jouer(m, mi5, -25), isNotNull,
          reason: 'une corde neuve redescend plusieurs fois par seance');
    });

    test('un ecart audible mais modere n interrompt pas l enfant', () {
      // L'accordeur exige quatre cents ; prevenir en pleine seance pour huit
      // cents ferait de l'application une gene. Les deux seuils n'ont pas le
      // meme role.
      expect(jouer(StringDriftMonitor(), la4, 8), isNull);
    });

    test('deux cordes peuvent deriver ensemble', () {
      // Un changement de temperature les fait toutes bouger dans le meme sens.
      final StringDriftMonitor m = StringDriftMonitor();
      jouer(m, mi5, -20);
      jouer(m, la4, -25);

      expect(m.drifts, hasLength(2));
      expect(m.drifts.first.stringMidi, la4,
          reason: 'la plus fausse en premier');
    });

    test('chaque corde est jugee separement', () {
      final StringDriftMonitor m = StringDriftMonitor();
      jouer(m, mi5, -25);
      jouer(m, sol3, 0);

      expect(m.driftFor(mi5), isNotNull);
      expect(m.driftFor(sol3), isNull);
    });

    test('remettre a zero oublie la seance precedente', () {
      final StringDriftMonitor m = StringDriftMonitor();
      jouer(m, mi5, -25);
      m.reset();
      expect(m.drifts, isEmpty);
      expect(jouer(m, mi5, -25), isNotNull);
    });

    test('le diapason adopte sert de reference', () {
      // Le meme son, juge contre deux diapasons, ne donne pas le meme verdict.
      // A 442 la corde est basse de vingt cents ; a 440 elle ne l'est que de
      // douze, sous le seuil d'alerte. Surveiller contre 440 alors que
      // l'instrument est accorde a 442 enverrait donc accorder pour rien --
      // ou laisserait passer une vraie derive.
      final SmoothedPitch corde = SmoothedPitch(
        estimate: PitchEstimate(
          frequencyHz: PitchUtils.midiToFrequency(la4, a4: 442) *
              math.pow(2, -20 / 1200).toDouble(),
          confidence: 1,
          timestampMs: 0,
        ),
        excursionCents: 0,
        vibrato: false,
      );

      final StringDriftMonitor a442 = StringDriftMonitor(tuner: Tuner(a4: 442));
      final StringDriftMonitor a440 = StringDriftMonitor();
      for (int i = 0; i < 6; i++) {
        a442.observe(corde);
        a440.observe(corde);
      }

      expect(a442.driftFor(la4)?.centsOffset, closeTo(-20, 1));
      expect(a440.driftFor(la4), isNull,
          reason: 'contre 440 le meme son n atteint pas le seuil');
    });
  });
}
