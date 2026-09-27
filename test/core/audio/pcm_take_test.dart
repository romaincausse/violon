import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pcm_take.dart';

/// [secondes] de silence, en PCM 16 bits mono.
Uint8List silence(double secondes, {int sampleRate = 8000}) =>
    Uint8List((secondes * sampleRate).round() * 2);

/// [secondes] de sinus a pleine echelle.
Uint8List son(double secondes,
    {int sampleRate = 8000, double amplitude = 0.5}) {
  final int n = (secondes * sampleRate).round();
  final Int16List e = Int16List(n);
  for (int i = 0; i < n; i++) {
    e[i] = (math.sin(2 * math.pi * 440 * i / sampleRate) * 32000 * amplitude)
        .round();
  }
  return Uint8List.view(e.buffer);
}

/// Lit l'en-tete d'un WAV : (frequence, nombre d'echantillons).
(int, int) enTete(Uint8List wav) {
  final ByteData d = ByteData.sublistView(wav);
  return (d.getUint32(24, Endian.little), d.getUint32(40, Endian.little) ~/ 2);
}

void main() {
  group('PcmTake', () {
    test('une prise vide n a rien a reecouter', () {
      final PcmTake prise = PcmTake(sampleRate: 8000);
      expect(prise.isEmpty, isTrue);
      expect(prise.wav(), isNull);
    });

    test('du silence seul ne produit rien', () {
      // Mieux vaut dire qu'il n'y a rien que jouer vingt secondes de rien.
      final PcmTake prise = PcmTake(sampleRate: 8000)..add(silence(3));
      expect(prise.isEmpty, isFalse);
      expect(prise.wav(), isNull);
    });

    test('elle rend un WAV lisible', () {
      final PcmTake prise = PcmTake(sampleRate: 8000)..add(son(1));
      final Uint8List? wav = prise.wav();
      expect(wav, isNotNull);
      expect(String.fromCharCodes(wav!.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final (int frequence, int echantillons) = enTete(wav);
      expect(frequence, 8000);
      expect(echantillons * 2 + 44, wav.length);
    });

    test('le silence du debut et de la fin est coupe', () {
      // L'enfant appuie apres avoir joue : la fenetre commence par ce qu'il
      // faisait avant, et finit par le temps qu'il a mis a poser l'archet.
      final PcmTake prise = PcmTake(sampleRate: 8000, keepMs: 0)
        ..add(silence(2))
        ..add(son(1))
        ..add(silence(2));
      final (int _, int echantillons) = enTete(prise.wav()!);
      expect(echantillons, lessThan(8000 * 2));
      expect(echantillons, greaterThan(8000 ~/ 2));
    });

    test('un peu de silence est garde de chaque cote', () {
      // Couper au ras de la premiere attaque mange le debut du coup d'archet
      // et fait commencer la relecture par un clic.
      final PcmTake serre = PcmTake(sampleRate: 8000, keepMs: 0)
        ..add(silence(1))
        ..add(son(1))
        ..add(silence(1));
      final PcmTake large = PcmTake(sampleRate: 8000, keepMs: 250)
        ..add(silence(1))
        ..add(son(1))
        ..add(silence(1));
      expect(enTete(large.wav()!).$2, greaterThan(enTete(serre.wav()!).$2));
    });

    test('la fenetre glisse et borne la memoire', () {
      // Vingt secondes en 16 bits mono font moins de deux megaoctets ;
      // au-dela on garderait surtout du silence.
      final PcmTake prise = PcmTake(sampleRate: 8000, maxSeconds: 2);
      for (int i = 0; i < 10; i++) {
        prise.add(son(1));
      }
      expect(prise.duration.inSeconds, lessThanOrEqualTo(3));
      expect(prise.duration.inSeconds, greaterThanOrEqualTo(2));
    });

    test('elle sait tout de suite si elle a entendu quelque chose', () {
      // Le bouton s'allume ou s'eteint a chaque image : rebalayer deux
      // megaoctets pour savoir s'il doit etre gris couterait le silence tres
      // cher.
      final PcmTake prise = PcmTake(sampleRate: 8000);
      expect(prise.hasSound, isFalse);
      prise.add(silence(1));
      expect(prise.hasSound, isFalse);
      prise.add(son(1));
      expect(prise.hasSound, isTrue);
    });

    test('ce qui sort de la fenetre cesse de compter', () {
      // Une note jouee il y a une minute n'est plus "ce qu'on vient de
      // jouer" : le bouton doit s'eteindre avec elle.
      final PcmTake prise = PcmTake(sampleRate: 8000, maxSeconds: 2)
        ..add(son(1));
      expect(prise.hasSound, isTrue);
      for (int i = 0; i < 5; i++) {
        prise.add(silence(1));
      }
      expect(prise.hasSound, isFalse);
    });

    test('elle se vide quand on le lui demande', () {
      final PcmTake prise = PcmTake(sampleRate: 8000)..add(son(1));
      prise.reset();
      expect(prise.isEmpty, isTrue);
      expect(prise.hasSound, isFalse);
      expect(prise.wav(), isNull);
    });

    test('un son tres faible compte pour du silence', () {
      // Le bruit d'une dalle posee sur un pupitre ne doit pas se faire passer
      // pour une note.
      final PcmTake prise = PcmTake(sampleRate: 8000)
        ..add(son(2, amplitude: 0.001));
      expect(prise.wav(), isNull);
    });
  });
}
