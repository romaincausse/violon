import 'dart:math' as math;
import 'dart:typed_data';

import 'metronome_clock.dart';

/// Un clic de metronome, synthetise plutot qu'enregistre.
///
/// **Pourquoi le fabriquer soi-meme.** Un fichier de clic serait un asset de
/// plus a versionner, a trois exemplaires, avec sa licence -- pour trois
/// impulsions qui tiennent en vingt lignes d'arithmetique. Et les fabriquer
/// permet de les **distinguer a l'oreille sans les distinguer au volume** : le
/// premier temps est plus aigu, pas plus fort. Un accent obtenu en montant le
/// son fatigue ; un accent obtenu en montant la hauteur s'entend aussi bien et
/// se laisse oublier.
///
/// Dart pur : la synthese se teste sans haut-parleur et sans appareil, comme
/// tout ce qui vit dans `lib/core/`.
class ClickSound {
  const ClickSound({
    required this.frequencyHz,
    required this.duration,
    required this.amplitude,
  });

  final double frequencyHz;
  final Duration duration;

  /// Amplitude de crete, de 0 a 1.
  final double amplitude;

  /// Premier temps de la mesure : le plus aigu, celui qu'on repere sans
  /// compter.
  static const ClickSound downbeat = ClickSound(
    frequencyHz: 1600,
    duration: Duration(milliseconds: 35),
    amplitude: 0.8,
  );

  /// Un temps ordinaire.
  static const ClickSound beat = ClickSound(
    frequencyHz: 1000,
    duration: Duration(milliseconds: 30),
    amplitude: 0.7,
  );

  /// Une subdivision : plus grave, plus breve, plus discrete. Elle remplit,
  /// elle ne scande pas -- si elle sonnait comme un temps, on perdrait le
  /// metre en gagnant la precision.
  static const ClickSound subdivision = ClickSound(
    frequencyHz: 800,
    duration: Duration(milliseconds: 18),
    amplitude: 0.35,
  );

  static ClickSound forAccent(PulseAccent accent) => switch (accent) {
        PulseAccent.downbeat => downbeat,
        PulseAccent.beat => beat,
        PulseAccent.subdivision => subdivision,
      };

  /// Duree de la montee, en secondes.
  ///
  /// **Une milliseconde, et pas zero.** Une sinusoide qui demarre a pleine
  /// amplitude produit une discontinuite, qui s'entend comme un craquement en
  /// plus du clic. La descente est exponentielle pour la meme raison, a l'autre
  /// bout.
  static const double _attackSeconds = 0.001;

  /// Les echantillons, entre -1 et 1.
  List<double> samples({int sampleRate = 44100}) {
    final int total = duration.inMicroseconds * sampleRate ~/ 1000000;
    final double attaque = _attackSeconds * sampleRate;
    return <double>[
      for (int i = 0; i < total; i++)
        () {
          final double t = i / sampleRate;
          final double montee = i < attaque ? i / attaque : 1;
          // Descente exponentielle : le clic doit avoir disparu a la fin de sa
          // duree, sinon la coupure nette s'entend.
          final double descente = math.exp(-5 * i / total);
          return amplitude *
              montee *
              descente *
              math.sin(2 * math.pi * frequencyHz * t);
        }(),
    ];
  }

  /// Le clic au format WAV, 16 bits, mono.
  ///
  /// Le moteur audio charge des octets ; lui donner un WAV plutot qu'un format
  /// maison evite d'avoir a le convaincre de quoi que ce soit.
  Uint8List wav({int sampleRate = 44100}) {
    final List<double> valeurs = samples(sampleRate: sampleRate);
    const int bitsParEchantillon = 16;
    const int canaux = 1;
    const int octetsParEchantillon = bitsParEchantillon ~/ 8;
    final int tailleDonnees = valeurs.length * octetsParEchantillon;

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

    for (final double valeur in valeurs) {
      // Borne avant conversion : 32768 deborderait un entier signe 16 bits et
      // repasserait au negatif, ce qui s'entendrait comme un craquement.
      final int entier = (valeur * 32767).round().clamp(-32768, 32767);
      data.setInt16(pos, entier, Endian.little);
      pos += 2;
    }

    return data.buffer.asUint8List();
  }
}
