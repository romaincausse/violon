import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fft.dart';

/// Transformee de Fourier discrete, ecrite directement d'apres sa definition.
///
/// Lente et evidemment correcte : c'est l'etalon contre lequel la FFT est
/// verifiee. Une FFT qui se contenterait de "donner un pic au bon endroit"
/// pourrait avoir des phases fausses sans qu'on le voie.
(Float64List, Float64List) dftNaive(Float64List real, Float64List imag) {
  final int n = real.length;
  final Float64List re = Float64List(n);
  final Float64List im = Float64List(n);
  for (int k = 0; k < n; k++) {
    for (int t = 0; t < n; t++) {
      final double angle = -2 * math.pi * k * t / n;
      re[k] += real[t] * math.cos(angle) - imag[t] * math.sin(angle);
      im[k] += real[t] * math.sin(angle) + imag[t] * math.cos(angle);
    }
  }
  return (re, im);
}

void main() {
  group('Fft', () {
    test('refuse une taille qui n est pas une puissance de deux', () {
      expect(() => Fft(100), throwsArgumentError);
      expect(() => Fft(0), throwsA(isA<AssertionError>()));
      expect(Fft(64).size, 64);
    });

    test('donne le meme resultat que la definition mathematique', () {
      // Un signal quelconque mais reproductible : une graine fixe, parce que
      // le determinisme est une regle du projet.
      const int n = 64;
      final math.Random hasard = math.Random(1789);
      final Float64List re = Float64List(n);
      final Float64List im = Float64List(n);
      for (int i = 0; i < n; i++) {
        re[i] = hasard.nextDouble() * 2 - 1;
        im[i] = hasard.nextDouble() * 2 - 1;
      }
      final (Float64List attenduRe, Float64List attenduIm) =
          dftNaive(Float64List.fromList(re), Float64List.fromList(im));

      Fft(n).transform(re, im);

      for (int k = 0; k < n; k++) {
        expect(re[k], closeTo(attenduRe[k], 1e-9), reason: 'reel[$k]');
        expect(im[k], closeTo(attenduIm[k], 1e-9), reason: 'imag[$k]');
      }
    });

    test('une constante ne contient que du continu', () {
      const int n = 32;
      final Float64List re = Float64List(n)..fillRange(0, n, 1);
      final Float64List im = Float64List(n);
      Fft(n).transform(re, im);

      expect(re[0], closeTo(n.toDouble(), 1e-9));
      for (int k = 1; k < n; k++) {
        expect(re[k], closeTo(0, 1e-9), reason: 'case $k');
        expect(im[k], closeTo(0, 1e-9), reason: 'case $k');
      }
    });

    test('une sinusoide tombe dans sa propre case', () {
      const int n = 64;
      const int caseAttendue = 5;
      final Float64List re = Float64List(n);
      final Float64List im = Float64List(n);
      for (int i = 0; i < n; i++) {
        re[i] = math.cos(2 * math.pi * caseAttendue * i / n);
      }
      Fft(n).transform(re, im);

      final List<double> amplitudes = <double>[
        for (int k = 0; k <= n ~/ 2; k++)
          math.sqrt(re[k] * re[k] + im[k] * im[k]),
      ];
      int plusForte = 0;
      for (int k = 1; k < amplitudes.length; k++) {
        if (amplitudes[k] > amplitudes[plusForte]) {
          plusForte = k;
        }
      }
      expect(plusForte, caseAttendue);
    });

    group('spectre d amplitude', () {
      const int taille = 1024;
      const int sampleRate = 44100;
      final Fft fft = Fft(taille);

      Float32List sinus(double frequenceHz) {
        final Float32List s = Float32List(taille);
        for (int i = 0; i < taille; i++) {
          s[i] = math.sin(2 * math.pi * frequenceHz * i / sampleRate);
        }
        return s;
      }

      test('rend la moitie du spectre, plus le continu', () {
        expect(fft.magnitudes(Float32List(taille)), hasLength(taille ~/ 2 + 1));
      });

      test('refuse un signal de la mauvaise longueur', () {
        expect(() => fft.magnitudes(Float32List(512)), throwsArgumentError);
      });

      test('le pic tombe a la bonne frequence', () {
        // La4 a 440 Hz. Une case vaut 43 Hz a cette resolution, donc le pic
        // doit tomber a moins d'une case de la verite.
        final Float64List spectre = fft.magnitudes(sinus(440));
        int pic = 1;
        for (int k = 2; k < spectre.length; k++) {
          if (spectre[k] > spectre[pic]) {
            pic = k;
          }
        }
        expect(
          fft.frequencyOfBin(pic, sampleRate),
          closeTo(440, fft.frequencyOfBin(1, sampleRate)),
        );
      });

      test('le silence ne contient rien', () {
        final Float64List spectre = fft.magnitudes(Float32List(taille));
        for (final double v in spectre) {
          expect(v, closeTo(0, 1e-9));
        }
      });

      test('la fenetre de Hann etale bien moins qu une coupe nette', () {
        // Sans fenetre, les bords de la trame font une discontinuite qui
        // repand de l'energie sur tout le spectre. Un detecteur d'attaques
        // prendrait cet etalement pour une attaque a chaque trame.
        //
        // On mesure l'energie **hors** du voisinage du pic : la fenetre doit
        // la reduire de plusieurs ordres de grandeur.
        final Float32List signal = sinus(1000);
        final Float64List avecFenetre = fft.magnitudes(signal);

        final Float64List re = Float64List(taille);
        final Float64List im = Float64List(taille);
        for (int i = 0; i < taille; i++) {
          re[i] = signal[i];
        }
        fft.transform(re, im);

        int picDe(Float64List spectre) {
          int pic = 1;
          for (int k = 2; k < spectre.length; k++) {
            if (spectre[k] > spectre[pic]) {
              pic = k;
            }
          }
          return pic;
        }

        final int pic = picDe(avecFenetre);
        double fuite(double Function(int) amplitude) {
          double somme = 0;
          for (int k = 0; k <= taille ~/ 2; k++) {
            if ((k - pic).abs() > 3) {
              somme += amplitude(k);
            }
          }
          return somme;
        }

        final double sans = fuite(
          (int k) => math.sqrt(re[k] * re[k] + im[k] * im[k]),
        );
        final double avec = fuite((int k) => avecFenetre[k]);
        expect(avec, lessThan(sans / 10));
      });
    });
  });
}
