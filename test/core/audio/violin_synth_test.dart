import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/onset_detector.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/audio/yin_detector.dart';
import 'package:violon/core/music/pitch_utils.dart';

const int sampleRate = 44100;

Duration ms(int v) => Duration(milliseconds: v);

int echantillon(int millisecondes) => millisecondes * sampleRate ~/ 1000;

/// Hauteur estimee par YIN sur la trame qui commence a [debutMs].
PitchEstimate? yinA(Float32List signal, int debutMs) {
  final int debut = echantillon(debutMs);
  return YinDetector().detect(
    Float32List.sublistView(signal, debut, debut + 2048),
  );
}

double rmsEntre(Float32List signal, int debutMs, int finMs) {
  double somme = 0;
  final int debut = echantillon(debutMs);
  final int fin = echantillon(finMs);
  for (int i = debut; i < fin; i++) {
    somme += signal[i] * signal[i];
  }
  return math.sqrt(somme / (fin - debut));
}

void main() {
  group('ViolinSynth', () {
    test('la meme graine rend le meme signal, une autre graine un autre', () {
      const List<BowedNote> notes = <BowedNote>[
        BowedNote(
            start: Duration(milliseconds: 100),
            duration: Duration(milliseconds: 400),
            midi: 69),
      ];
      final Float32List a = ViolinSynth(seed: 7).render(notes, length: ms(600));
      final Float32List b = ViolinSynth(seed: 7).render(notes, length: ms(600));
      final Float32List c = ViolinSynth(seed: 8).render(notes, length: ms(600));
      expect(a, b);
      expect(a, isNot(c));
    });

    test('sans note, il reste le bruit de fond d une piece calme', () {
      final Float32List silence = ViolinSynth(noiseRms: 0.005)
          .render(const <BowedNote>[], length: ms(1000));
      expect(silence, hasLength(sampleRate));
      expect(rmsEntre(silence, 0, 1000), closeTo(0.005, 0.0005));
    });

    test('YIN retrouve la hauteur, fausse note comprise', () {
      // 67,3 : un sol trop haut de trente cents. C'est ainsi que le scenario
      // fabrique une note fausse, il faut donc qu'elle s'entende.
      final Float32List signal = ViolinSynth().render(
        const <BowedNote>[
          BowedNote(
              start: Duration.zero,
              duration: Duration(milliseconds: 500),
              midi: 67.3),
        ],
        length: ms(500),
      );
      final PitchEstimate? e = yinA(signal, 200);
      expect(e, isNotNull);
      expect(
        PitchUtils.centsBetween(
          e!.frequencyHz,
          PitchUtils.midiToFrequency(67),
        ),
        closeTo(30, 3),
      );
    });

    test('une note aigue ne replie aucun harmonique dans le grave', () {
      // Mi6, en quatrieme position sur la corde de mi : seize harmoniques
      // depasseraient Nyquist. Un repliement fabriquerait une hauteur fantome.
      final Float32List signal = ViolinSynth().render(
        const <BowedNote>[
          BowedNote(
              start: Duration.zero,
              duration: Duration(milliseconds: 500),
              midi: 88),
        ],
        length: ms(500),
      );
      expect(yinA(signal, 200)!.nearestMidi, 88);
    });

    test('deux notes detachees a la meme hauteur donnent deux attaques', () {
      // Le cas ou YIN est aveugle : seule l'attaque d'archet distingue les
      // deux notes. Si le synthetiseur ne la produisait pas, il ne servirait
      // a rien sur ce piege.
      final Float32List signal = ViolinSynth().render(
        const <BowedNote>[
          BowedNote(
              start: Duration(milliseconds: 200),
              duration: Duration(milliseconds: 500),
              midi: 74),
          BowedNote(
              start: Duration(milliseconds: 700),
              duration: Duration(milliseconds: 500),
              midi: 74),
        ],
        length: ms(1500),
      );
      final List<Onset> attaques = OnsetDetector().addSamples(signal);
      expect(attaques, hasLength(2));
      expect(attaques[0].timestampMs, closeTo(200, 40));
      expect(attaques[1].timestampMs, closeTo(700, 40));
    });

    test('une liaison ne creuse pas le son, un detache si', () {
      List<BowedNote> deux({required bool lie}) => <BowedNote>[
            const BowedNote(
                start: Duration(milliseconds: 100),
                duration: Duration(milliseconds: 400),
                midi: 67),
            BowedNote(
              start: ms(500),
              duration: ms(400),
              midi: 69,
              attack: !lie,
            ),
          ];

      final ViolinSynth synth = ViolinSynth(noiseRms: 0);
      final Float32List lie = synth.render(deux(lie: true), length: ms(1000));
      final Float32List detache =
          synth.render(deux(lie: false), length: ms(1000));

      final double tenu = rmsEntre(lie, 300, 400);
      expect(rmsEntre(lie, 490, 510), greaterThan(0.8 * tenu));
      expect(rmsEntre(detache, 490, 510), lessThan(0.5 * tenu));
    });

    test('le vibrato fait osciller la hauteur de part et d autre', () {
      final Float32List signal = ViolinSynth().render(
        const <BowedNote>[
          BowedNote(
            start: Duration.zero,
            duration: Duration(milliseconds: 1500),
            midi: 69,
            vibratoCents: 35,
          ),
        ],
        length: ms(1500),
      );
      final double la = PitchUtils.midiToFrequency(69);
      final List<double> ecarts = <double>[
        for (int t = 400; t < 1300; t += 10)
          PitchUtils.centsBetween(yinA(signal, t)!.frequencyHz, la),
      ];
      // Une trame de 46 ms lisse un peu la crete d'un vibrato a 5,5 Hz : on
      // demande une excursion nette, pas exactement trente-cinq cents.
      expect(ecarts.reduce(math.max), inInclusiveRange(20, 40));
      expect(ecarts.reduce(math.min), inInclusiveRange(-40, -20));
    });

    test('le signal reste dans [-1, 1]', () {
      final Float32List signal = ViolinSynth(noiseRms: 0.05).render(
        const <BowedNote>[
          BowedNote(
              start: Duration.zero,
              duration: Duration(milliseconds: 300),
              midi: 55,
              amplitude: 1),
        ],
        length: ms(300),
      );
      expect(signal.every((double v) => v >= -1 && v <= 1), isTrue);
    });
  });
}
