import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/dynamics_judge.dart';

/// Les nuances (K9).
void main() {
  /// Huit mesures d'une note chacune ; [marques] pose nuances et soufflets.
  Passage morceau(Map<int, (String?, String?)> marques) => Passage(
        title: 'x',
        ticksPerBeat: 480,
        notes: <ScoreNote>[
          for (int i = 0; i < 8; i++)
            ScoreNote(
              id: 'n$i',
              midi: 69 + (i.isEven ? 0 : 2),
              onsetTicks: 1920 * i,
              durationTicks: 1920,
              measure: i + 1,
              dynamicMark: marques[i]?.$1,
              hairpin: marques[i]?.$2,
            ),
        ],
      );

  /// Chaque note dure une seconde, a l'energie [db] (en dB) qu'on lui donne.
  (Alignment, List<FeatureFrame>) jouer(Passage p, List<double> db) {
    final List<int> temps = <int>[];
    final List<String?> notes = <String?>[];
    final List<FeatureFrame> trames = <FeatureFrame>[];
    for (int i = 0; i < p.notes.length; i++) {
      for (int t = 0; t < 1000; t += 25) {
        temps.add(1000 * i + t);
        notes.add(p.notes[i].id);
        trames.add(FeatureFrame(
          timeMs: 1000 * i + t,
          midi: p.notes[i].midi.toDouble(),
          rms: math.pow(10, db[i] / 20).toDouble(),
          onset: t == 0,
        ));
      }
    }
    return (Alignment(frameTimesMs: temps, frameNotes: notes), trames);
  }

  List<DynamicsFinding> juger(Passage p, List<double> db) {
    final (Alignment a, List<FeatureFrame> t) = jouer(p, db);
    return DynamicsJudge.judge(passage: p, alignment: a, frames: t);
  }

  test('un mp joue plus doux que le mf s entend, un mp au meme niveau non', () {
    final Passage p = morceau(<int, (String?, String?)>{
      0: ('mf', null),
      4: ('mp', null),
    });
    final DynamicsFinding bien =
        juger(p, <double>[-26, -26, -27, -26, -31, -30, -31, -31]).single;
    expect(bien.mark, 'mp');
    expect(bien.louder, isFalse);
    expect(bien.heard, isTrue);
    expect(bien.at.measure, 5);
    final DynamicsFinding plat =
        juger(p, <double>[-26, -26, -27, -26, -26, -27, -26, -26]).single;
    expect(plat.heard, isFalse);
  });

  test('a l envers, ca ne s entend pas non plus', () {
    final Passage p = morceau(<int, (String?, String?)>{
      0: ('p', null),
      4: ('f', null),
    });
    expect(
      juger(p, <double>[-26, -26, -26, -26, -30, -30, -30, -30]).single.heard,
      isFalse,
    );
  });

  test('le crescendo doit monter, du premier tiers au dernier', () {
    final Passage p = morceau(<int, (String?, String?)>{
      1: (null, 'cresc'),
      7: (null, 'fin'),
    });
    final DynamicsFinding monte =
        juger(p, <double>[-30, -32, -30, -29, -27, -26, -24, -23]).single;
    expect(monte.mark, 'cresc');
    expect(monte.heard, isTrue);
    expect(
      juger(p, <double>[-30, -30, -30, -30, -30, -30, -30, -30]).single.heard,
      isFalse,
    );
  });

  test('la meme nuance repetee ne se juge pas, une note non jouee non plus',
      () {
    final Passage p = morceau(<int, (String?, String?)>{
      0: ('mf', null),
      4: ('mf', null),
    });
    expect(juger(p, <double>[-26, -26, -26, -26, -31, -31, -31, -31]), isEmpty);
  });
}
