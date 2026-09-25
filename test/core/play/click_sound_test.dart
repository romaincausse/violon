import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/click_sound.dart';
import 'package:violon/core/play/metronome_clock.dart';

String _ascii(Uint8List octets, int debut) =>
    String.fromCharCodes(octets.sublist(debut, debut + 4));

int _uint32(Uint8List octets, int debut) =>
    ByteData.sublistView(octets).getUint32(debut, Endian.little);

int _uint16(Uint8List octets, int debut) =>
    ByteData.sublistView(octets).getUint16(debut, Endian.little);

void main() {
  group('ClickSound, la synthese', () {
    test('la duree demandee est la duree produite', () {
      final List<double> s = ClickSound.beat.samples(sampleRate: 48000);
      expect(s, hasLength(30 * 48));
    });

    test('le clic commence a zero et finit eteint', () {
      // Une sinusoide qui demarre a pleine amplitude craque, et une qui
      // s'arrete net craque a l'autre bout.
      final List<double> s = ClickSound.beat.samples();
      expect(s.first.abs(), lessThan(0.01));
      expect(s.last.abs(), lessThan(0.05));
    });

    test('rien ne depasse l amplitude demandee', () {
      for (final ClickSound clic in <ClickSound>[
        ClickSound.downbeat,
        ClickSound.beat,
        ClickSound.subdivision,
      ]) {
        for (final double v in clic.samples()) {
          expect(v.abs(), lessThanOrEqualTo(clic.amplitude + 1e-9));
        }
      }
    });

    test('le premier temps est plus aigu, pas plus fort', () {
      // Un accent obtenu en montant le son fatigue ; un accent obtenu en
      // montant la hauteur s'entend aussi bien et se laisse oublier.
      expect(
        ClickSound.downbeat.frequencyHz,
        greaterThan(ClickSound.beat.frequencyHz),
      );
      expect(
        ClickSound.downbeat.amplitude - ClickSound.beat.amplitude,
        lessThan(0.2),
      );
    });

    test('la subdivision reste en retrait', () {
      expect(
        ClickSound.subdivision.amplitude,
        lessThan(ClickSound.beat.amplitude),
      );
      expect(
        ClickSound.subdivision.duration,
        lessThan(ClickSound.beat.duration),
      );
    });

    test('chaque accent a son clic', () {
      expect(ClickSound.forAccent(PulseAccent.downbeat), ClickSound.downbeat);
      expect(ClickSound.forAccent(PulseAccent.beat), ClickSound.beat);
      expect(
        ClickSound.forAccent(PulseAccent.subdivision),
        ClickSound.subdivision,
      );
    });
  });

  group('ClickSound, le WAV', () {
    test('l en-tete est celui d un WAV PCM 16 bits mono', () {
      final Uint8List wav = ClickSound.beat.wav(sampleRate: 44100);
      expect(_ascii(wav, 0), 'RIFF');
      expect(_ascii(wav, 8), 'WAVE');
      expect(_ascii(wav, 12), 'fmt ');
      expect(_uint32(wav, 16), 16, reason: 'taille du bloc fmt');
      expect(_uint16(wav, 20), 1, reason: 'PCM entier');
      expect(_uint16(wav, 22), 1, reason: 'mono');
      expect(_uint32(wav, 24), 44100);
      expect(_uint32(wav, 28), 44100 * 2, reason: 'octets par seconde');
      expect(_uint16(wav, 32), 2, reason: 'octets par trame');
      expect(_uint16(wav, 34), 16, reason: 'bits par echantillon');
      expect(_ascii(wav, 36), 'data');
    });

    test('les tailles annoncees sont les tailles reelles', () {
      final Uint8List wav = ClickSound.beat.wav(sampleRate: 44100);
      final int donnees = _uint32(wav, 40);
      expect(wav.length, 44 + donnees);
      expect(_uint32(wav, 4), 36 + donnees);
      expect(donnees, ClickSound.beat.samples().length * 2);
    });

    test('la frequence d echantillonnage change la taille, pas le son', () {
      final Uint8List a44 = ClickSound.beat.wav(sampleRate: 44100);
      final Uint8List a48 = ClickSound.beat.wav(sampleRate: 48000);
      expect(a48.length, greaterThan(a44.length));
      expect(_uint32(a48, 24), 48000);
    });
  });
}
