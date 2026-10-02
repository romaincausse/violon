import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/online_follower.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';

void main() {
  // Deux mesures : re mi | fa# sol.
  final Passage passage = Passage(
    title: 't',
    ticksPerBeat: 480,
    notes: const <ScoreNote>[
      ScoreNote(
          id: 'n1', midi: 62, onsetTicks: 0, durationTicks: 960, measure: 1),
      ScoreNote(
          id: 'n2', midi: 64, onsetTicks: 960, durationTicks: 960, measure: 1),
      ScoreNote(
          id: 'n3', midi: 66, onsetTicks: 1920, durationTicks: 960, measure: 2),
      ScoreNote(
          id: 'n4', midi: 67, onsetTicks: 2880, durationTicks: 960, measure: 2),
    ],
  );

  int t = 0;
  List<FeatureFrame> note(double? midi, int trames, {bool attaque = true}) {
    final List<FeatureFrame> f = <FeatureFrame>[
      for (int i = 0; i < trames; i++)
        FeatureFrame(
          timeMs: (t += 23) - 23,
          midi: midi,
          rms: midi == null ? 0.001 : 0.1,
          onset: attaque && i == 0 && midi != null,
        ),
    ];
    return f;
  }

  List<FollowPosition> suivre(OnlineFollower s, List<FeatureFrame> trames) =>
      <FollowPosition>[
        for (final FeatureFrame f in trames)
          if (s.add(f) case final FollowPosition p) p,
      ];

  /// Le chemin suivi, sans les repetitions : `n2` joue la note 2, `r2`
  /// s'est arrete apres elle.
  List<String> chemin(List<FollowPosition> p) {
    final List<String> c = <String>[];
    for (final FollowPosition x in p) {
      if (!x.started) {
        continue;
      }
      final String e = '${x.resting ? 'r' : 'n'}${x.noteIndex}';
      if (c.isEmpty || c.last != e) {
        c.add(e);
      }
    }
    return c;
  }

  setUp(() => t = 0);

  test('avant la premiere note, il attend', () {
    final OnlineFollower s = OnlineFollower(passage);
    final List<FollowPosition> p = suivre(s, note(null, 10));
    expect(p.last.started, isFalse);
    expect(p.last.resting, isTrue);
  });

  test('il suit la melodie, note apres note', () {
    final OnlineFollower s = OnlineFollower(passage);
    final List<FollowPosition> p = suivre(s, <FeatureFrame>[
      ...note(null, 5),
      ...note(62, 12),
      ...note(64, 12),
      ...note(66, 12),
      ...note(67, 12),
      ...note(null, 30),
    ]);
    expect(chemin(p), <String>['n0', 'n1', 'n2', 'n3', 'r3']);
  });

  test('la position rendue retarde de lagFrames trames', () {
    final OnlineFollower s = OnlineFollower(passage, lagFrames: 2);
    final List<FeatureFrame> f = note(62, 6);
    expect(s.add(f[0]), isNull);
    expect(s.add(f[1]), isNull);
    expect(s.add(f[2])!.timeMs, f[0].timeMs);
    expect(s.add(f[3])!.timeMs, f[1].timeMs);
  });

  test('une reprise de la mesure est suivie', () {
    final OnlineFollower s = OnlineFollower(passage);
    final List<FollowPosition> p = suivre(s, <FeatureFrame>[
      ...note(62, 10),
      ...note(64, 10),
      ...note(66, 10),
      ...note(null, 30),
      // Il reprend la mesure 2 du debut.
      ...note(66, 10),
      ...note(67, 10),
    ]);
    expect(chemin(p), <String>['n0', 'n1', 'n2', 'r2', 'n2', 'n3']);
  });

  test('la confiance est haute quand une seule place explique le son', () {
    final OnlineFollower s = OnlineFollower(passage);
    final List<FollowPosition> p = suivre(s, <FeatureFrame>[
      ...note(62, 10),
      ...note(64, 20),
    ]);
    expect(p.last.noteIndex, 1);
    expect(p.last.confidence, greaterThan(0.8));
  });

  test('une longue seance ne fait pas deriver les scores', () {
    final OnlineFollower s = OnlineFollower(passage);
    FollowPosition? dernier;
    for (int k = 0; k < 2000; k++) {
      for (final FeatureFrame f in <FeatureFrame>[
        ...note(66, 3),
        ...note(67, 3),
        ...note(null, 3),
      ]) {
        dernier = s.add(f) ?? dernier;
      }
    }
    expect(dernier!.confidence.isFinite, isTrue);
    expect(dernier.noteIndex, isNotNull);
  });

  test('reset fait tout oublier', () {
    final OnlineFollower s = OnlineFollower(passage);
    suivre(s, note(62, 10));
    s.reset();
    expect(s.framesSeen, 0);
    final List<FollowPosition> p = suivre(s, note(null, 5));
    expect(p.last.started, isFalse);
  });
}
