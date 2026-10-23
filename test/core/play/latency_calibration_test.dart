import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/latency_calibration.dart';

void main() {
  final List<int> clics = <int>[
    for (final int d in LatencyCalibration.offsetsMs) 10000 + d,
  ];
  // Le micro a ouvert quand le moteur marquait 9200 : un son du moteur a
  // 10000 + d arrive au micro a 800 + d + latence.
  List<int> entendusA(int latence, {List<int>? seulement}) => <int>[
        for (int k = 0; k < clics.length; k++)
          if (seulement == null || seulement.contains(k))
            800 + LatencyCalibration.offsetsMs[k] + latence,
      ];

  test('la latence est l ecart median entre clic joue et clic entendu', () {
    final List<int> entendus = <int>[
      for (int k = 0; k < clics.length; k++)
        800 + LatencyCalibration.offsetsMs[k] + 85 + (k.isEven ? 3 : -2),
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
      onsetsMicMs: entendusA(90, seulement: <int>[0, 1, 3, 5]),
      micToEngineMs: 9200,
    );
    expect(l!.latencyMs, 90);
    expect(l.matched, 4);
  });

  test('une latence plus longue que l ecart entre deux clics', () {
    // Le S22 : plus de 600 ms. Des clics reguliers toutes les 500 ms
    // auraient ete apparies a l'echo du precedent.
    final LatencyEstimate? l = LatencyCalibration.estimate(
      clicksEngineMs: clics,
      onsetsMicMs: entendusA(843),
      micToEngineMs: 9200,
    );
    expect(l!.latencyMs, 843);
    expect(l.matched, 6);
  });

  test('une voix dans la piece ne fausse pas la mesure', () {
    final LatencyEstimate? l = LatencyCalibration.estimate(
      clicksEngineMs: clics,
      // Les six clics, et des attaques de voix partout autour.
      onsetsMicMs: <int>[
        ...entendusA(620),
        850,
        1100,
        1490,
        2230,
        2950,
        3410,
        4100,
        4430,
      ],
      micToEngineMs: 9200,
    );
    expect(l!.latencyMs, 620);
    expect(l.matched, 6);
  });

  test('un bruit de la piece n est pas un clic : la mesure est refusee', () {
    expect(
      LatencyCalibration.estimate(
        clicksEngineMs: clics,
        // Des attaques sans rapport avec le motif des clics.
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
