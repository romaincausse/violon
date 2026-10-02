import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/scoring/rhythm_judge.dart';

void main() {
  // Huit noires, ecrites a 92.
  final Passage noires = () {
    final PassageBuilder b = PassageBuilder();
    for (int i = 0; i < 8; i++) {
      b.add(62 + i, NoteValue.quarter);
    }
    return Passage(
      title: 't',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 92,
    );
  }();

  /// Une note par duree en millisecondes, jouees legato.
  List<PlayedEvent> jouer(List<int> durees, {int depart = 0, int de = 0}) {
    final List<PlayedEvent> e = <PlayedEvent>[];
    int t = depart;
    for (int i = 0; i < durees.length; i++) {
      e.add(PlayedEvent(noteIndex: de + i, startMs: t, endMs: t + durees[i]));
      t += durees[i];
    }
    return e;
  }

  test('tout a 74 au lieu de 92, rythme impeccable : pas une faute', () {
    // 74 a la noire : 811 ms.
    final RhythmJudge j =
        RhythmJudge.fromEvents(noires, jouer(List<int>.filled(8, 811)));
    expect(j.quarterBpm, closeTo(74, 0.1));
    expect(j.pulseBpm, 74);
    expect(j.overallScore, 100);
    expect(j.tempoRatio, closeTo(74 / 92, 0.01));
    expect(j.hesitations, isEmpty);
  });

  test('une noire jouee comme une croche est une faute, sur cette note', () {
    final List<int> d = List<int>.filled(8, 650);
    d[3] = 325;
    final RhythmJudge j = RhythmJudge.fromEvents(noires, jouer(d));
    // Une seule note fausse ne deplace pas le tempo tenu.
    expect(j.quarterBpm, closeTo(60000 / 650, 0.5));
    expect(j.scoreFor(3), 0);
    expect(j.scoreFor(2), 100);
    expect(j.overallScore, lessThan(100));
  });

  test('deux secondes d arret avant une note : une hesitation, a part', () {
    final List<int> d = List<int>.filled(8, 650);
    d[4] = 650 + 2000;
    final RhythmJudge j = RhythmJudge.fromEvents(noires, jouer(d));
    expect(j.hesitations.map((n) => n.id), <String>[noires.notes[5].id]);
    // Ni le tempo ni le rythme n'en souffrent.
    expect(j.quarterBpm, closeTo(60000 / 650, 0.5));
    expect(j.scoreFor(4), isNull);
    expect(j.overallScore, 100);
  });

  test('un petit rubato reste en place', () {
    final List<int> d = <int>[650, 700, 610, 660, 640, 690, 620, 650];
    expect(RhythmJudge.fromEvents(noires, jouer(d)).overallScore, 100);
  });

  test('une reprise coupe la prise : on ne juge pas par-dessus', () {
    final List<PlayedEvent> e = <PlayedEvent>[
      ...jouer(<int>[600, 600, 600, 600]),
      // Il reprend au debut, tout de suite, deux fois plus lentement.
      ...jouer(<int>[1200, 1200, 1200, 1200], depart: 2400),
    ];
    final RhythmJudge j = RhythmJudge.fromEvents(noires, e);
    // Six enchainements, aucun a cheval sur la reprise.
    expect(j.verdicts, hasLength(6));
  });

  test('un arret de travail coupe aussi la prise', () {
    final List<PlayedEvent> e = <PlayedEvent>[
      ...jouer(<int>[600, 600, 600]),
      ...jouer(<int>[600, 600, 600], depart: 1800 + 3000, de: 3),
    ];
    final RhythmJudge j = RhythmJudge.fromEvents(noires, e);
    expect(j.verdicts.where((RhythmVerdict v) => v.noteIndex == 2), isEmpty);
  });

  test('trop peu d enchainements, rien n est affirme', () {
    final RhythmJudge j =
        RhythmJudge.fromEvents(noires, jouer(<int>[600, 600, 600]));
    expect(j.quarterBpm, isNull);
    expect(j.overallScore, isNull);
  });

  test('l echelle du score de rythme', () {
    expect(RhythmJudge.scoreForRatio(1), 100);
    expect(RhythmJudge.scoreForRatio(1.15), 100);
    expect(RhythmJudge.scoreForRatio(0.5), 0);
    expect(RhythmJudge.scoreForRatio(2), 0);
    final int milieu = RhythmJudge.scoreForRatio(1.5);
    expect(milieu, inExclusiveRange(0, 100));
    // Symetrique : trop court et trop long d'autant coutent pareil.
    expect(RhythmJudge.scoreForRatio(1 / 1.5), milieu);
  });
}
