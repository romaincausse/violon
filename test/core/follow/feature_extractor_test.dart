import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/feature_extractor.dart';
import 'package:violon/core/follow/performance_features.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  // Trois re repetes puis un mi : des attaques que YIN ne voit pas, et un
  // changement de hauteur qu'il voit.
  final Float32List signal = ViolinSynth(a4: 440).render(
    <BowedNote>[
      BowedNote(start: ms(300), duration: ms(280), midi: 62),
      BowedNote(start: ms(600), duration: ms(280), midi: 62),
      BowedNote(start: ms(900), duration: ms(280), midi: 62),
      BowedNote(start: ms(1200), duration: ms(500), midi: 64),
    ],
    length: ms(2000),
  );

  String decrire(FeatureFrame f) => '${f.timeMs} ${f.midi?.toStringAsFixed(4)} '
      '${f.rms.toStringAsFixed(6)} ${f.onset} ${f.analysed}';

  List<FeatureFrame> parPaquets(List<int> tailles) {
    final FeatureExtractor e = FeatureExtractor();
    final List<FeatureFrame> sortie = <FeatureFrame>[];
    int i = 0;
    int k = 0;
    while (i < signal.length) {
      final int n = math.min(tailles[k++ % tailles.length], signal.length - i);
      sortie.addAll(e.addSamples(Float32List.sublistView(signal, i, i + n)));
      i += n;
    }
    return sortie;
  }

  test('le decoupage du flux ne change aucune trame', () {
    // C'est la garantie de S1 : le suiveur en direct voit exactement ce que
    // l'aligneur a vu sur le banc.
    final List<String> dUnCoup =
        PerformanceFeatures.extract(signal).map(decrire).toList();
    for (final List<int> tailles in <List<int>>[
      <int>[2048],
      <int>[441],
      <int>[1, 7, 1764, 4096, 333],
      <int>[44100],
    ]) {
      expect(
        parPaquets(tailles).map(decrire).toList(),
        dUnCoup,
        reason: 'paquets de $tailles',
      );
    }
    expect(dUnCoup.where((String s) => s.contains(' true true')).length,
        greaterThanOrEqualTo(4),
        reason: 'les quatre attaques sont vues');
  });

  test('une trame sautee garde sa place, son energie et son attaque', () {
    final FeatureExtractor e = FeatureExtractor();
    final List<FeatureFrame> pleines = PerformanceFeatures.extract(signal);
    final List<FeatureFrame> sautees =
        e.addSamples(signal, analysePitch: false);
    expect(sautees.length, pleines.length);
    for (int i = 0; i < pleines.length; i++) {
      expect(sautees[i].timeMs, pleines[i].timeMs);
      expect(sautees[i].onset, pleines[i].onset);
      expect(sautees[i].rms, pleines[i].rms);
      expect(sautees[i].midi, isNull);
      expect(sautees[i].analysed, isFalse);
    }
  });

  test('reset fait repartir le temps de zero', () {
    final FeatureExtractor e = FeatureExtractor();
    e.addSamples(signal);
    e.reset();
    final List<FeatureFrame> f = e.addSamples(signal);
    expect(f.first.timeMs, 0);
    expect(f.map(decrire).toList(),
        PerformanceFeatures.extract(signal).map(decrire).toList());
  });

  test('retuned rapporte la hauteur a l accord reel', () {
    final FeatureFrame f = FeatureFrame(
      timeMs: 0,
      midi: 69 + 12 * math.log(443 / 440) / math.ln2,
      rms: 0.1,
      onset: false,
    );
    // Un la a 443 Hz mesure contre 440 vaut 69,12 ; contre 443, c'est un la.
    expect(f.retuned(fromA4: 440, toA4: 443).midi, closeTo(69, 0.001));
    const FeatureFrame muet =
        FeatureFrame(timeMs: 0, midi: null, rms: 0, onset: false);
    expect(muet.retuned(fromA4: 440, toA4: 443).midi, isNull);
  });
}
