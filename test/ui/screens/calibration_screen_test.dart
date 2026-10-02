import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/play/fake_audio_engine.dart';
import 'package:violon/core/play/latency_calibration.dart';
import 'package:violon/ui/screens/calibration_screen.dart';

/// Du PCM 16 bits : du silence, et un clic bref aux instants donnes (ms).
Uint8List signal(int debutMs, int finMs, List<int> clicsMs) {
  final int n = (finMs - debutMs) * 441 ~/ 10;
  final Uint8List b = Uint8List(n * 2);
  final ByteData v = ByteData.view(b.buffer);
  for (int i = 0; i < n; i++) {
    final double t = debutMs + i * 1000 / 44100;
    double x = 0;
    for (final int c in clicsMs) {
      if (t >= c && t < c + 8) {
        x = 0.8 * math.sin(2 * math.pi * 2000 * (t - c) / 1000);
      }
    }
    v.setInt16(2 * i, (x * 32767).round(), Endian.little);
  }
  return b;
}

void main() {
  testWidgets('six clics entendus avec 80 ms de retard : 80 ms', (
    WidgetTester tester,
  ) async {
    final FakeAudioEngine moteur = FakeAudioEngine()
      ..clock = const Duration(seconds: 5);
    late FakePitchSource micro;
    int? mesuree;
    await tester.pumpWidget(
      MaterialApp(
        home: CalibrationScreen(
          engine: moteur,
          pitchSourceFactory: () async =>
              micro = FakePitchSource(const <PitchEstimate>[]),
          onMeasured: (int l) => mesuree = l,
        ),
      ),
    );
    await tester.tap(find.byKey(CalibrationScreen.mesurerKey));
    await tester.pump();
    await tester.pump();
    // Le premier paquet du micro : 100 ms de silence. A sa fin, le moteur
    // marque 5000 ms : un instant du micro vaut donc t + 4900 cote moteur.
    micro.emitAudio(signal(0, 100, const <int>[]));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    expect(moteur.clicksAt, hasLength(LatencyCalibration.clicks));
    final List<int> entendus = <int>[
      for (final FakeClick c in moteur.clicksAt)
        c.delay.inMilliseconds - 4900 + 80,
    ];
    micro.emitAudio(signal(100, entendus.last + 400, entendus));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    // Le detecteur d'attaques date un son au debut de la fenetre ou il le
    // voit : jusqu'a une fenetre (23 ms) trop tot, toujours pareil. La
    // latence mesuree l'inclut, comme les attaques qu'elle servira a caler.
    expect(mesuree, inInclusiveRange(80 - 23, 80));
    expect(find.textContaining('Latence :'), findsOneWidget);
  });
}
