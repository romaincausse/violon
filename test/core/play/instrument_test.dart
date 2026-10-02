import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/instrument.dart';

Instrument flute() => Instrument(
      id: 'flute',
      name: 'Flute',
      sustains: true,
      samples: const <InstrumentSample>[
        InstrumentSample(midi: 72, hz: 523.0, file: 'flute_72.ogg'),
        InstrumentSample(midi: 60, hz: 261.2, file: 'flute_60.ogg'),
        InstrumentSample(midi: 64, hz: 330.0, file: 'flute_64.ogg'),
      ],
    );

void main() {
  group('Instrument', () {
    test('prend l echantillon le plus proche, a sa hauteur mesuree', () {
      final SamplePlayback p = flute().playbackFor(277.18); // do#4
      expect(p.sample.midi, 60);
      // La vitesse part de la hauteur mesuree (261,2), pas du do theorique.
      expect(p.speed, closeTo(277.18 / 261.2, 1e-9));
      expect(flute().playbackFor(500).sample.midi, 72);
    });

    test('ramene une note hors tessiture par octaves', () {
      final Instrument f = flute();
      expect(f.lowestMidi, 57);
      expect(f.highestMidi, 75);
      expect(f.fold(40), 64, reason: 'une basse de piano monte');
      expect(f.fold(62), 62);
      expect(f.fold(88), 64);
    });

    test('se lit depuis le JSON, un echantillon abime est ignore', () {
      final Instrument? i = Instrument.fromJson(<String, Object?>{
        'id': 'violon',
        'name': 'Violon',
        'sustains': true,
        'samples': <Object?>[
          <String, Object?>{
            'midi': 69,
            'hz': 440.8,
            'file': 'violon_69.ogg',
            'loopStart': 0.9,
          },
          <String, Object?>{'midi': 'la'},
        ],
      });
      expect(i!.samples.single.loopStart, const Duration(milliseconds: 900));
      expect(Instrument.fromJson(<String, Object?>{'id': 'x'}), isNull);
    });

    test('les echantillons embarques sont complets et accordes', () {
      final InstrumentLibrary lib = InstrumentLibrary.fromJson(
        jsonDecode(File('assets/sons/instruments.json').readAsStringSync()),
      );
      expect(
        lib.instruments.map((Instrument i) => i.id),
        containsAll(<String>['piano', 'violon', 'violoncelle', 'flute']),
      );
      expect(lib.byId('piano')!.sustains, isFalse);
      expect(
          lib.sustaining.map((Instrument i) => i.id), isNot(contains('piano')));
      for (final Instrument i in lib.instruments) {
        // Une note livree tous les deux demi-tons au plus : le moteur ne
        // transpose plus que d'un demi-ton, et le piano pas du tout
        // (ADR-017).
        for (int k = 1; k < i.samples.length; k++) {
          expect(
            i.samples[k].midi - i.samples[k - 1].midi,
            lessThanOrEqualTo(i.id == 'piano' ? 1 : 2),
            reason:
                '${i.id} : ${i.samples[k - 1].midi} -> ${i.samples[k].midi}',
          );
        }
        for (final InstrumentSample s in i.samples) {
          expect(File('assets/sons/${s.file}').existsSync(), isTrue,
              reason: s.file);
          final double cents = 1200 *
              math.log(s.hz / (440 * math.pow(2, (s.midi - 69) / 12))) /
              math.ln2;
          expect(cents.abs(), lessThan(50), reason: '${s.file} : $cents');
          expect(s.loopStart != null, i.sustains, reason: s.file);
        }
      }
    });

    test('la licence accompagne les echantillons', () {
      final String licence = File('assets/sons/LICENCE.txt').readAsStringSync();
      expect(licence, contains('CC0'));
      expect(licence, contains('Versilian Studios'));
      expect(licence, contains('Simon Dalzell'));
      // Le piano vient d'ailleurs, et sa licence demande le nom de l'auteur.
      expect(licence, contains('CC BY 3.0'));
      expect(licence, contains('Alexander Holm'));
    });
  });
}
