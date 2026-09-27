import 'dart:typed_data';

/// Un signal decode d'un fichier WAV.
class WavData {
  const WavData({required this.samples, required this.sampleRate});

  /// Entre -1 et 1, mono.
  final Float32List samples;
  final int sampleRate;
}

/// Encodage et decodage WAV PCM 16 bits.
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

  /// Decode un WAV PCM 16 bits, mono ou stereo.
  ///
  /// Les blocs inconnus sont sautes plutot que refuses : un enregistreur
  /// ajoute souvent ses metadonnees (`LIST`, `bext`) entre `fmt ` et `data`.
  /// La stereo est ramenee au mono par moyenne -- le violon est au milieu.
  /// Tout autre format est refuse : le protocole du banc exige du PCM 16 bits,
  /// et convertir en silence masquerait une prise mal faite.
  static WavData decode(Uint8List bytes) {
    final ByteData data = ByteData.sublistView(bytes);
    String ascii(int pos) => String.fromCharCodes(bytes.sublist(pos, pos + 4));

    if (bytes.length < 12 || ascii(0) != 'RIFF' || ascii(8) != 'WAVE') {
      throw const FormatException('pas un fichier WAV');
    }
    int? canaux;
    int? frequence;
    int pos = 12;
    while (pos + 8 <= bytes.length) {
      final String bloc = ascii(pos);
      final int taille = data.getUint32(pos + 4, Endian.little);
      final int contenu = pos + 8;
      if (bloc == 'fmt ') {
        final int format = data.getUint16(contenu, Endian.little);
        canaux = data.getUint16(contenu + 2, Endian.little);
        frequence = data.getUint32(contenu + 4, Endian.little);
        final int bits = data.getUint16(contenu + 14, Endian.little);
        if (format != 1 || bits != 16 || canaux < 1 || canaux > 2) {
          throw FormatException(
            'WAV non gere : format $format, $bits bits, $canaux canaux '
            '(attendu : PCM 16 bits, mono ou stereo)',
          );
        }
      } else if (bloc == 'data') {
        if (canaux == null || frequence == null) {
          throw const FormatException('bloc data avant le bloc fmt');
        }
        final int fin = (contenu + taille).clamp(contenu, bytes.length);
        final int trames = (fin - contenu) ~/ (2 * canaux);
        final Float32List samples = Float32List(trames);
        for (int i = 0; i < trames; i++) {
          double somme = 0;
          for (int c = 0; c < canaux; c++) {
            somme += data.getInt16(
              contenu + 2 * (i * canaux + c),
              Endian.little,
            );
          }
          samples[i] = somme / canaux / 32768;
        }
        return WavData(samples: samples, sampleRate: frequence);
      }
      // Les blocs sont alignes sur deux octets.
      pos = contenu + taille + (taille.isOdd ? 1 : 0);
    }
    throw const FormatException('aucun bloc data');
  }
}
