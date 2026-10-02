import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/microphone_pitch_source.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/feature_analyzer.dart';
import 'package:violon/core/follow/performance_features.dart';

import '../audio/fake_capture.dart';

Duration ms(int v) => Duration(milliseconds: v);

/// Analyseur de trames dont le test decide quand il repond : la seule facon
/// de mettre le suiveur sous pression sans dependre de la vitesse reelle.
class TrameurPilote implements FeatureAnalyzer {
  final InlineFeatureAnalyzer _vrai = InlineFeatureAnalyzer();
  final List<Completer<void>> _attente = <Completer<void>>[];
  final List<bool> hauteursDemandees = <bool>[];
  int recus = 0;

  @override
  Future<List<FeatureFrame>> add(
    Float32List samples, {
    bool analysePitch = true,
  }) async {
    recus++;
    hauteursDemandees.add(analysePitch);
    final Completer<void> c = Completer<void>();
    _attente.add(c);
    await c.future;
    return _vrai.add(samples, analysePitch: analysePitch);
  }

  Future<void> liberer() async {
    while (_attente.isNotEmpty) {
      _attente.removeAt(0).complete();
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> reset() => _vrai.reset();

  @override
  Future<void> dispose() async {}
}

Uint8List enOctets(Float32List s) {
  final Uint8List b = Uint8List(s.length * 2);
  final ByteData v = ByteData.view(b.buffer);
  for (int i = 0; i < s.length; i++) {
    v.setInt16(2 * i, (s[i].clamp(-1, 1) * 32767).round(), Endian.little);
  }
  return b;
}

Float32List deOctets(Uint8List b) {
  final ByteData v = ByteData.view(b.buffer);
  return Float32List.fromList(<double>[
    for (int i = 0; i < b.length ~/ 2; i++)
      v.getInt16(2 * i, Endian.little) / 32768,
  ]);
}

void main() {
  final Float32List signal = ViolinSynth().render(
    <BowedNote>[
      BowedNote(start: ms(200), duration: ms(250), midi: 62),
      BowedNote(start: ms(500), duration: ms(250), midi: 62),
      BowedNote(start: ms(800), duration: ms(400), midi: 64),
    ],
    length: ms(1500),
  );
  // Ce que le micro livre, apres quantification sur 16 bits.
  final Uint8List octets = enOctets(signal);
  final List<FeatureFrame> attendues =
      PerformanceFeatures.extract(deOctets(octets));

  String decrire(FeatureFrame f) =>
      '${f.timeMs} ${f.midi?.toStringAsFixed(3)} ${f.onset} ${f.analysed}';

  Future<void> envoyer(FakeCapture micro) async {
    // Des paquets de taille irreguliere, comme ceux d'Android.
    int i = 0;
    int k = 0;
    const List<int> tailles = <int>[3528, 1764, 4097, 900];
    while (i < octets.length) {
      final int n = math.min(tailles[k++ % 4], octets.length - i);
      micro.controleur.add(Uint8List.sublistView(octets, i, i + n));
      i += n;
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('le micro rend les trames du banc, sans en perdre une', () async {
    final FakeCapture micro = FakeCapture();
    final MicrophonePitchSource source = MicrophonePitchSource(micro);
    final List<FeatureFrame> recues = <FeatureFrame>[];
    final StreamSubscription<FeatureFrame> a =
        source.features.listen(recues.add);
    await source.start();
    await envoyer(micro);
    await Future<void>.delayed(Duration.zero);

    // Le framer garde la derniere trame incomplete : tout ce qui est rendu
    // doit etre exactement le debut de l'analyse hors ligne.
    expect(recues, isNotEmpty);
    expect(
      recues.map(decrire).toList(),
      attendues.take(recues.length).map(decrire).toList(),
    );
    expect(recues.length, greaterThanOrEqualTo(attendues.length - 2));
    await a.cancel();
    await source.dispose();
  });

  test('sous pression, les hauteurs sautent mais aucune trame ne manque',
      () async {
    final FakeCapture micro = FakeCapture();
    final TrameurPilote trameur = TrameurPilote();
    final MicrophonePitchSource source =
        MicrophonePitchSource(micro, featureAnalyzer: trameur);
    final List<FeatureFrame> recues = <FeatureFrame>[];
    final StreamSubscription<FeatureFrame> a =
        source.features.listen(recues.add);
    await source.start();
    // Rien ne repond pendant tout l'envoi : la file s'allonge.
    await envoyer(micro);
    await trameur.liberer();
    await Future<void>.delayed(Duration.zero);

    expect(trameur.hauteursDemandees, contains(false));
    expect(source.pitchSkippedFeatureChunks, greaterThan(0));
    // Le temps avance d'un pas regulier : pas un trou.
    for (int i = 1; i < recues.length; i++) {
      expect(recues[i].timeMs - recues[i - 1].timeMs, inInclusiveRange(23, 24));
    }
    expect(recues.length, greaterThanOrEqualTo(attendues.length - 2));
    // Les attaques sont toutes la, hauteurs ou pas.
    expect(
      recues.where((FeatureFrame f) => f.onset).length,
      attendues.where((FeatureFrame f) => f.onset).length,
    );
    await a.cancel();
    await source.dispose();
  });

  test('personne a l ecoute, rien n est calcule', () async {
    final FakeCapture micro = FakeCapture();
    final TrameurPilote trameur = TrameurPilote();
    final MicrophonePitchSource source =
        MicrophonePitchSource(micro, featureAnalyzer: trameur);
    await source.start();
    await envoyer(micro);
    expect(trameur.recus, 0);
    await source.dispose();
  });

  test('l isolate rend les memes trames que l analyse sur place', () async {
    final IsolateFeatureAnalyzer isolate = await IsolateFeatureAnalyzer.spawn();
    final List<FeatureFrame> recues = <FeatureFrame>[
      ...await isolate.add(Float32List.sublistView(signal, 0, 20000)),
      ...await isolate.add(Float32List.sublistView(signal, 20000)),
    ];
    expect(recues.map(decrire).toList(),
        PerformanceFeatures.extract(signal).map(decrire).toList());
    await isolate.reset();
    final List<FeatureFrame> apres = await isolate.add(signal);
    expect(apres.first.timeMs, 0);
    await isolate.dispose();
  });
}
