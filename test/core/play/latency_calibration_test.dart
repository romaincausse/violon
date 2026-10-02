import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/latency_calibration.dart';

void main() {
  final List<int> clics = <int>[
    for (int k = 0; k < LatencyCalibration.clicks; k++) 10000 + k * 500,
  ];

  test('la latence est l ecart median entre clic joue et clic entendu', () {
    // Le micro a ouvert quand le moteur marquait 9200 : un son du moteur a
    // 10000 arrive au micro a 800 + latence.
    final List<int> entendus = <int>[
      for (int k = 0; k < clics.length; k++)
        800 + k * 500 + 85 + (k.isEven ? 3 : -2),
    ];
    final LatencyEstimate? l = LatencyCalibration.estimate(
      clicksEngineMs: clics,
      onsetsMicMs: entendus,
      micToEngineMs: 9200,
    );
    expect(l, isNotNull);
    expect(l!.latencyMs, inInclusiveRange(83, 88));
    expect(l.matched, 6);
  });

  test('deux clics rates n empechent pas la mesure', () {
    final LatencyEstimate? l = LatencyCalibration.estimate(
      clicksEngineMs: clics,
      onsetsMicMs: <int>[890, 1390, 2390, 3390],
      micToEngineMs: 9200,
    );
    expect(l!.latencyMs, 90);
    expect(l.matched, 4);
  });

  test('un bruit de la piece n est pas un clic : la mesure est refusee', () {
    expect(
      LatencyCalibration.estimate(
        clicksEngineMs: clics,
        onsetsMicMs: <int>[890, 1500, 2100, 3390, 3700],
        micToEngineMs: 9200,
      ),
      isNull,
    );
    expect(
      LatencyCalibration.estimate(
        clicksEngineMs: clics,
        onsetsMicMs: const <int>[],
        micToEngineMs: 9200,
      ),
      isNull,
    );
  });
}
