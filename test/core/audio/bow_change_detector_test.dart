import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/bow_change_detector.dart';
import 'package:violon/core/audio/onset_detector.dart';
import 'package:violon/core/audio/violin_synth.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  /// Quatre re detaches, colles l'un a l'autre : seuls les changements
  /// d'archet les separent -- le cas que le flux spectral ratait (ADR-019).
  final Float32List quatreRe = ViolinSynth(a4: 440).render(
    <BowedNote>[
      for (int k = 0; k < 4; k++)
        BowedNote(start: ms(300 + 300 * k), duration: ms(300), midi: 62),
    ],
    length: ms(1800),
  );

  List<Onset> detecter(Float32List signal, {List<int>? paquets}) {
    final BowChangeDetector d = BowChangeDetector();
    final List<Onset> sortie = <Onset>[];
    if (paquets == null) {
      sortie.addAll(d.addSamples(signal));
    } else {
      int i = 0;
      int k = 0;
      while (i < signal.length) {
        final int n =
            math.min(paquets[k++ % paquets.length], signal.length - i);
        sortie.addAll(d.addSamples(Float32List.sublistView(signal, i, i + n)));
        i += n;
      }
    }
    return sortie;
  }

  group('BowChangeDetector', () {
    test('chaque changement d archet sur la meme hauteur est vu', () {
      final List<int> t =
          detecter(quatreRe).map((Onset o) => o.timestampMs).toList();
      // Trois changements entre quatre notes, a quarante millisecondes pres.
      for (final int attendu in <int>[600, 900, 1200]) {
        expect(
          t.any((int x) => (x - attendu).abs() <= 40),
          isTrue,
          reason: 'changement attendu vers $attendu ms, vus : $t',
        );
      }
    });

    test('une note tenue avec vibrato n en a aucun', () {
      final Float32List tenue = ViolinSynth(a4: 440).render(
        <BowedNote>[
          BowedNote(
            start: ms(300),
            duration: ms(1500),
            midi: 69,
            vibratoCents: 40,
          ),
        ],
        length: ms(2200),
      );
      final List<Onset> o = detecter(tenue)
          .where((Onset x) => x.timestampMs > 450 && x.timestampMs < 1700)
          .toList();
      expect(o, isEmpty);
    });

    test('une fin de note dans le silence n est pas un changement d archet',
        () {
      final Float32List seule = ViolinSynth(a4: 440).render(
        <BowedNote>[BowedNote(start: ms(200), duration: ms(500), midi: 64)],
        length: ms(1500),
      );
      final List<Onset> o =
          detecter(seule).where((Onset x) => x.timestampMs > 500).toList();
      expect(o, isEmpty);
    });

    test('le decoupage du flux ne change rien', () {
      final List<int> dUnCoup =
          detecter(quatreRe).map((Onset o) => o.timestampMs).toList();
      for (final List<int> p in <List<int>>[
        <int>[1],
        <int>[441],
        <int>[7, 1764, 333],
      ]) {
        expect(
          detecter(quatreRe, paquets: p).map((Onset o) => o.timestampMs),
          dUnCoup,
          reason: 'paquets de $p',
        );
      }
    });

    test('il dit jusqu ou il a tranche, et tout l est a la fin', () {
      final BowChangeDetector d = BowChangeDetector();
      expect(d.decidedUntilMs, -1);
      d.addSamples(quatreRe);
      final int tranche = d.decidedUntilMs;
      // Il lui manque la remontee d'energie : une quarantaine de
      // millisecondes et une fenetre.
      expect(tranche, lessThan(1800));
      expect(tranche, greaterThan(1700));
      d.finish();
      expect(d.decidedUntilMs, greaterThan(1 << 30));
      d.reset();
      expect(d.decidedUntilMs, -1);
    });
  });
}
