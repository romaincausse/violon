import 'dart:math' as math;
import 'dart:typed_data';

/// Transformee de Fourier rapide, radix-2, en place.
///
/// Ecrite a la main pour tenir la regle d'architecture n1 : `lib/core/` ne
/// depend d'aucun paquet. Une FFT radix-2 tient en cinquante lignes et se
/// verifie contre la definition mathematique -- c'est ce que fait son test.
///
/// **Pourquoi une FFT alors que YIN n'en utilise pas.** YIN travaille sur
/// l'autocorrelation, dans le domaine temporel. Le detecteur d'attaques, lui,
/// compare des spectres successifs : c'est justement ce qui lui permet de voir
/// une note rejouee a la meme hauteur, la ou YIN ne voit aucun changement.
class Fft {
  Fft(this.size)
      : assert(size > 0, 'la taille doit etre > 0'),
        _cos = Float64List(size ~/ 2),
        _sin = Float64List(size ~/ 2),
        _reversed = Uint32List(size) {
    if (size & (size - 1) != 0) {
      throw ArgumentError.value(
          size, 'size', 'doit etre une puissance de deux');
    }
    for (int i = 0; i < size ~/ 2; i++) {
      final double angle = -2 * math.pi * i / size;
      _cos[i] = math.cos(angle);
      _sin[i] = math.sin(angle);
    }
    // Table d'inversion de bits, calculee une fois : c'est la permutation
    // qui permet a l'algorithme de travailler en place.
    final int bits = size.bitLength - 1;
    for (int i = 0; i < size; i++) {
      int j = 0;
      for (int b = 0; b < bits; b++) {
        if (i & (1 << b) != 0) {
          j |= 1 << (bits - 1 - b);
        }
      }
      _reversed[i] = j;
    }
  }

  final int size;
  final Float64List _cos;
  final Float64List _sin;
  final Uint32List _reversed;

  /// Transforme [real] et [imag] en place. Les deux font [size] elements.
  void transform(Float64List real, Float64List imag) {
    if (real.length != size || imag.length != size) {
      throw ArgumentError('les tableaux doivent faire $size elements');
    }
    for (int i = 0; i < size; i++) {
      final int j = _reversed[i];
      if (j > i) {
        double t = real[i];
        real[i] = real[j];
        real[j] = t;
        t = imag[i];
        imag[i] = imag[j];
        imag[j] = t;
      }
    }
    for (int longueur = 2; longueur <= size; longueur <<= 1) {
      final int demi = longueur ~/ 2;
      final int pas = size ~/ longueur;
      for (int debut = 0; debut < size; debut += longueur) {
        for (int i = 0; i < demi; i++) {
          final int k = i * pas;
          final int a = debut + i;
          final int b = a + demi;
          final double reB = real[b] * _cos[k] - imag[b] * _sin[k];
          final double imB = real[b] * _sin[k] + imag[b] * _cos[k];
          real[b] = real[a] - reB;
          imag[b] = imag[a] - imB;
          real[a] += reB;
          imag[a] += imB;
        }
      }
    }
  }

  /// Spectre d'amplitude d'un signal reel, fenetre de Hann appliquee.
  ///
  /// Rend `size / 2 + 1` valeurs : au-dela, le spectre d'un signal reel n'est
  /// que le miroir de la premiere moitie.
  ///
  /// La fenetre de Hann n'est pas une precaution de style. Sans elle, les
  /// discontinuites aux bords de la trame etalent de l'energie sur tout le
  /// spectre, et un detecteur d'attaques prendrait cet etalement pour une
  /// attaque a chaque trame.
  Float64List magnitudes(Float32List samples) {
    if (samples.length != size) {
      throw ArgumentError('le signal doit faire $size echantillons');
    }
    final Float64List real = Float64List(size);
    final Float64List imag = Float64List(size);
    for (int i = 0; i < size; i++) {
      real[i] = samples[i] * _hann(i);
    }
    transform(real, imag);

    final Float64List sortie = Float64List(size ~/ 2 + 1);
    for (int i = 0; i < sortie.length; i++) {
      sortie[i] = math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }
    return sortie;
  }

  double _hann(int i) => 0.5 * (1 - math.cos(2 * math.pi * i / (size - 1)));

  /// Frequence, en Hz, du centre d'une case du spectre.
  double frequencyOfBin(int bin, int sampleRate) => bin * sampleRate / size;
}
