import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/slur_judge.dart';

/// Les liaisons respectees (K8).
void main() {
  // Re4 mi4 fa#4 sol4 sur la corde de re, liees par deux ; puis la4, corde de
  // la, lie au sol : un changement de corde sous la liaison.
  final Passage p = Passage(
    title: 'x',
    ticksPerBeat: 480,
    notes: <ScoreNote>[
      for (final (int i, int m) in <(int, int)>[
        (0, 64),
        (1, 66),
        (2, 67),
        (3, 69),
        (4, 71),
      ])
        ScoreNote(
          id: 'n$i',
          midi: m,
          onsetTicks: 480 * i,
          durationTicks: 480,
          measure: 1,
          slurred: i.isOdd,
        ),
    ],
  );
  final Set<String> liees = <String>{'n1', 'n3'};

  /// Une note toutes les 500 ms, une trame toutes les 25 ms ; [creux] met un
  /// creux de cette profondeur au debut de la note dite.
  (Alignment, List<FeatureFrame>) jouer(Map<String, double> creux) {
    final List<int> temps = <int>[];
    final List<String?> notes = <String?>[];
    final List<FeatureFrame> trames = <FeatureFrame>[];
    for (int i = 0; i < p.notes.length; i++) {
      for (int t = 0; t < 500; t += 25) {
        final int ms = 500 * i + t;
        temps.add(ms);
        notes.add(p.notes[i].id);
        trames.add(FeatureFrame(
          timeMs: ms,
          midi: p.notes[i].midi.toDouble(),
          rms: 0.05,
          onset: t == 0,
          bowDipDb: t == 25 ? creux[p.notes[i].id] : null,
        ));
      }
    }
    return (Alignment(frameTimesMs: temps, frameNotes: notes), trames);
  }

  List<String> juger(Map<String, double> creux) {
    final (Alignment a, List<FeatureFrame> t) = jouer(creux);
    return <String>[
      for (final ScoreNote n in SlurJudge.broken(
        passage: p,
        slurredInto: liees,
        alignment: a,
        frames: t,
      ))
        n.id,
    ];
  }

  test('un creux profond sous une liaison la casse, un creux leger non', () {
    expect(juger(<String, double>{'n1': 8.5}), <String>['n1']);
    expect(juger(<String, double>{'n1': 4.4}), isEmpty,
        reason: 'le changement de note sous la liaison, pas l archet');
    expect(juger(<String, double>{'n2': 9}), isEmpty,
        reason: 'n2 n est pas liee : on attend un changement d archet');
  });

  test('un changement de corde sous la liaison ne se juge pas', () {
    // La4 est la corde de la a vide, apres le sol de la corde de re.
    expect(juger(<String, double>{'n3': 9}), isEmpty);
  });

  test('sans liaison, rien a juger', () {
    final (Alignment a, List<FeatureFrame> t) =
        jouer(<String, double>{'n1': 9});
    expect(
      SlurJudge.broken(
        passage: p,
        slurredInto: const <String>{},
        alignment: a,
        frames: t,
      ),
      isEmpty,
    );
  });
}
