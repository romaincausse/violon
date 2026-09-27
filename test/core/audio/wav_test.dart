import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/wav.dart';

void main() {
  group('Wav', () {
    test('un signal encode puis decode revient au quantum pres', () {
      final List<double> signal = <double>[0, 0.5, -0.5, 0.999, -1];
      final WavData lu = Wav.decode(Wav.encode(signal, sampleRate: 22050));
      expect(lu.sampleRate, 22050);
      expect(lu.samples, hasLength(signal.length));
      for (int i = 0; i < signal.length; i++) {
        expect(lu.samples[i], closeTo(signal[i], 1 / 16384));
      }
    });

    test('une valeur hors de [-1, 1] est bornee, pas repliee', () {
      final WavData lu = Wav.decode(Wav.encode(<double>[1.5, -1.5]));
      expect(lu.samples[0], greaterThan(0.99));
      expect(lu.samples[1], lessThan(-0.99));
    });

    test('un bloc inconnu entre fmt et data est saute', () {
      final Uint8List mono = Wav.encode(<double>[0.25, -0.25]);
      // On glisse un bloc LIST de 6 octets apres le bloc fmt (qui finit a 36).
      final Uint8List avecListe = Uint8List.fromList(<int>[
        ...mono.sublist(0, 36),
        ...'LIST'.codeUnits,
        6,
        0,
        0,
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        ...mono.sublist(36),
      ]);
      expect(Wav.decode(avecListe).samples[0], closeTo(0.25, 1e-4));
    });

    test('la stereo est ramenee au mono par moyenne', () {
      final Uint8List mono = Wav.encode(<double>[0, 0]);
      final ByteData d = ByteData.sublistView(mono);
      // On reecrit l en-tete en stereo : les deux echantillons deviennent une
      // trame gauche / droite.
      d.setUint16(22, 2, Endian.little);
      d.setInt16(44, 16384, Endian.little);
      d.setInt16(46, 0, Endian.little);
      final WavData lu = Wav.decode(mono);
      expect(lu.samples, hasLength(1));
      expect(lu.samples[0], closeTo(0.25, 1e-4));
    });

    test('un format autre que PCM 16 bits est refuse', () {
      final Uint8List wav = Wav.encode(<double>[0]);
      ByteData.sublistView(wav).setUint16(34, 24, Endian.little);
      expect(() => Wav.decode(wav), throwsFormatException);
      expect(
        () => Wav.decode(Uint8List.fromList('pas un wav du tout'.codeUnits)),
        throwsFormatException,
      );
    });
  });
}
