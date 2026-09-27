import 'dart:typed_data';

/// Encodage WAV PCM 16 bits mono.
///
/// Deux usages l'ont justifie en commun : le clic du metronome, que le moteur
/// audio charge comme un fichier, et les prises de synthese du banc d'essai,
/// qu'on ecoute dans Audacity a cote des vraies. **Le meme format que les
/// vraies prises** (voir `docs/banc-d-essai.md`) : 16 bits, mono, sans
/// compression.
class Wav {
  const Wav._();

  /// Les [samples], entre -1 et 1, au format WAV.
  static Uint8List encode(List<double> samples, {int sampleRate = 44100}) {
    const int bitsParEchantillon = 16;
    const int canaux = 1;
    const int octetsParEchantillon = bitsParEchantillon ~/ 8;
    final int tailleDonnees = samples.length * octetsParEchantillon;

    final ByteData data = ByteData(44 + tailleDonnees);
    int pos = 0;
    void ecrireAscii(String s) {
      for (final int c in s.codeUnits) {
        data.setUint8(pos++, c);
      }
    }

    void ecrireUint32(int v) {
      data.setUint32(pos, v, Endian.little);
      pos += 4;
    }

    void ecrireUint16(int v) {
      data.setUint16(pos, v, Endian.little);
      pos += 2;
    }

    ecrireAscii('RIFF');
    ecrireUint32(36 + tailleDonnees);
    ecrireAscii('WAVE');
    ecrireAscii('fmt ');
    ecrireUint32(16); // taille du bloc fmt
    ecrireUint16(1); // PCM entier
    ecrireUint16(canaux);
    ecrireUint32(sampleRate);
    ecrireUint32(sampleRate * canaux * octetsParEchantillon);
    ecrireUint16(canaux * octetsParEchantillon);
    ecrireUint16(bitsParEchantillon);
    ecrireAscii('data');
    ecrireUint32(tailleDonnees);

    for (final double valeur in samples) {
      // Borne avant conversion : 32768 deborderait un entier signe 16 bits et
      // repasserait au negatif, ce qui s'entendrait comme un craquement.
      final int entier = (valeur * 32767).round().clamp(-32768, 32767);
      data.setInt16(pos, entier, Endian.little);
      pos += 2;
    }

    return data.buffer.asUint8List();
  }
}
