import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pcm_framer.dart';

void main() {
  /// Ecrit [values] en PCM 16 bits signes, petit-boutiste, comme le fait le
  /// micro Android.
  Uint8List pcm(List<int> values) {
    final Uint8List bytes = Uint8List(values.length * 2);
    final ByteData vue = ByteData.view(bytes.buffer);
    for (int i = 0; i < values.length; i++) {
      vue.setInt16(i * 2, values[i], Endian.little);
    }
    return bytes;
  }

  group('PcmFramer', () {
    test('un paquet trop court ne produit rien', () {
      final PcmFramer f = PcmFramer(frameSize: 4);
      expect(f.addBytes(pcm(<int>[1, 2, 3])), isEmpty);
      expect(f.pendingSamples, 3);
    });

    test('un paquet complet produit une trame de la bonne taille', () {
      final PcmFramer f = PcmFramer(frameSize: 4);
      final List<PcmFrame> trames = f.addBytes(pcm(<int>[1, 2, 3, 4]));
      expect(trames, hasLength(1));
      expect(trames.single.samples, hasLength(4));
      expect(f.pendingSamples, 0);
    });

    test('un gros paquet produit plusieurs trames d un coup', () {
      final PcmFramer f = PcmFramer(frameSize: 4);
      final List<PcmFrame> trames = f.addBytes(
        pcm(List<int>.generate(10, (int i) => i)),
      );
      expect(trames, hasLength(2));
      expect(f.pendingSamples, 2, reason: 'le reste attend la suite');
    });

    test('les echantillons sont ramenes entre -1 et 1', () {
      final PcmFramer f = PcmFramer(frameSize: 4);
      final PcmFrame t =
          f.addBytes(pcm(<int>[0, 16384, -16384, -32768])).single;
      expect(t.samples[0], 0);
      expect(t.samples[1], closeTo(0.5, 1e-6));
      expect(t.samples[2], closeTo(-0.5, 1e-6));
      // Le minimum d'un entier 16 bits vaut exactement -1 : c'est pour lui
      // qu'on divise par 32768 et non par 32767.
      expect(t.samples[3], -1.0);
    });

    test('un echantillon coupe en deux paquets est reconstitue', () {
      // Le cas qui arrive vraiment : le systeme livre un nombre impair
      // d'octets. Jeter l'octet orphelin decalerait tout le flux d'un octet
      // et le signal deviendrait du bruit.
      final PcmFramer complet = PcmFramer(frameSize: 4);
      final Float32List attendu =
          complet.addBytes(pcm(<int>[1000, -2000, 3000, -4000])).single.samples;

      final PcmFramer coupe = PcmFramer(frameSize: 4);
      final Uint8List octets = pcm(<int>[1000, -2000, 3000, -4000]);
      expect(coupe.addBytes(Uint8List.sublistView(octets, 0, 3)), isEmpty);
      final Float32List obtenu =
          coupe.addBytes(Uint8List.sublistView(octets, 3)).single.samples;

      expect(obtenu, attendu);
    });

    test('un paquet vide ne perd pas l octet orphelin', () {
      final PcmFramer f = PcmFramer(frameSize: 2);
      final Uint8List octets = pcm(<int>[1234, 5678]);
      f.addBytes(Uint8List.sublistView(octets, 0, 1));
      expect(f.addBytes(Uint8List(0)), isEmpty);
      final Float32List s =
          f.addBytes(Uint8List.sublistView(octets, 1)).single.samples;
      expect(s[0], closeTo(1234 / 32768, 1e-6));
      expect(s[1], closeTo(5678 / 32768, 1e-6));
    });

    test('l horodatage se calcule, il ne s accumule pas', () {
      // A 44,1 kHz, une trame de 2048 dure 46,44 ms. Additionner 46 ms a
      // chaque trame prendrait une seconde de retard en une minute et demie.
      final PcmFramer f = PcmFramer(frameSize: 2048, sampleRate: 44100);
      final List<PcmFrame> trames = f.addBytes(
        Uint8List(2048 * 2 * 100), // cent trames de silence
      );
      expect(trames, hasLength(100));
      expect(trames.first.timestampMs, 0);
      expect(trames[1].timestampMs, 46);
      // Cent trames font 204800 echantillons, soit 4643 ms exactement.
      expect(trames.last.timestampMs, 99 * 2048 * 1000 ~/ 44100);
      expect(trames.last.timestampMs, 4597);
    });

    test('remettre a zero oublie le reste et l horloge', () {
      final PcmFramer f = PcmFramer(frameSize: 4);
      f.addBytes(pcm(<int>[1, 2, 3, 4, 5]));
      expect(f.emittedSamples, 4);
      f.reset();
      expect(f.pendingSamples, 0);
      expect(f.emittedSamples, 0);
      expect(f.addBytes(pcm(<int>[9, 9, 9, 9])).single.timestampMs, 0);
    });
  });
}
