import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/even_bow.dart';
import 'package:violon/core/follow/performance_features.dart';

/// Un archet de [ms] millisecondes, une trame toutes les 23 ms, dont le
/// niveau en decibels suit [niveau] (de 0 a 1 le long de l'archet).
List<FeatureFrame> archet(
  int de,
  int ms,
  double Function(double x) niveau, {
  bool attaque = true,
}) =>
    <FeatureFrame>[
      for (int t = de; t < de + ms; t += 23)
        FeatureFrame(
          timeMs: t,
          midi: 69,
          rms: math.pow(10, niveau((t - de) / ms) / 20).toDouble(),
          onset: attaque && t == de,
        ),
    ];

List<FeatureFrame> silence(int de, int ms) => <FeatureFrame>[
      for (int t = de; t < de + ms; t += 23)
        FeatureFrame(timeMs: t, midi: null, rms: 0.001, onset: false),
    ];

void main() {
  test('un archet egal, a un decibel pres, est egal et fait le record', () {
    final EvenBow e = EvenBow();
    final math.Random r = math.Random(4);
    for (final FeatureFrame f in <FeatureFrame>[
      ...archet(0, 4000, (_) => -25 + r.nextDouble() * 2 - 1),
      ...silence(4000, 300),
    ]) {
      e.hear(f);
    }
    final BowStroke b = e.last!;
    expect(b.verdict, BowVerdict.even);
    expect(b.spreadDb, lessThan(2));
    expect(e.bestMs, closeTo(4000, 50));
  });

  test('le son qui s eteint se dit, et ne fait pas de record', () {
    final EvenBow e = EvenBow(bestMs: 1200);
    for (final FeatureFrame f in <FeatureFrame>[
      ...archet(0, 3000, (double x) => -20 - 12 * x),
      ...silence(3000, 300),
    ]) {
      e.hear(f);
    }
    expect(e.last!.verdict, BowVerdict.fades);
    expect(e.last!.trendDb, lessThan(-6));
    expect(e.bestMs, 1200, reason: 'le record reste');
  });

  test('le son qui grossit, et celui qui gonfle au milieu', () {
    final EvenBow e = EvenBow();
    for (final FeatureFrame f in archet(0, 3000, (double x) => -32 + 12 * x)) {
      e.hear(f);
    }
    e.rest();
    expect(e.last!.verdict, BowVerdict.swells);
    for (final FeatureFrame f
        in archet(5000, 3000, (double x) => -30 + 12 * math.sin(math.pi * x))) {
      e.hear(f);
    }
    e.rest();
    expect(e.last!.verdict, BowVerdict.uneven);
  });

  test('un changement d archet coupe en deux archets, l attaque du debut non',
      () {
    final EvenBow e = EvenBow();
    final List<BowStroke> vus = <BowStroke>[];
    for (final FeatureFrame f in <FeatureFrame>[
      // L'attaque du flux spectral tombe deux trames apres le debut du son.
      ...archet(0, 46, (_) => -25, attaque: false),
      const FeatureFrame(timeMs: 46, midi: 69, rms: 0.056, onset: true),
      ...archet(69, 2000, (_) => -25, attaque: false),
      ...archet(2069, 2500, (_) => -24),
      ...silence(4569, 200),
    ]) {
      final BowStroke? avant = e.last;
      e.hear(f);
      if (e.last != null && !identical(e.last, avant)) {
        vus.add(e.last!);
      }
    }
    expect(vus.map((BowStroke b) => b.startMs), <int>[0, 2069]);
    expect(vus.every((BowStroke b) => b.verdict == BowVerdict.even), isTrue);
    expect(e.bestMs, closeTo(2500, 50));
  });

  test('un archet trop court ne se juge pas', () {
    final EvenBow e = EvenBow();
    for (final FeatureFrame f in archet(0, 800, (double x) => -20 - 10 * x)) {
      e.hear(f);
    }
    expect(e.currentMs, greaterThan(700));
    e.rest();
    expect(e.last, isNull);
    expect(e.currentMs, 0);
  });
}
