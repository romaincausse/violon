@Tags(<String>['lent'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/score_note.dart';

/// Le piege de Firework, en petit (ADR-019) : des mesures qui reviennent a
/// l'identique, et une note ajoutee par habitude.
///
///   m1 la la la si   m2 sol sol sol sol   m3 la la la si
///   m4 sol sol sol sol   m5 la la la la   m6 re re
///
/// L'enfant joue d'un trait, sans s'arreter, mais glisse un si au milieu de
/// la mesure 5, comme a la fin des mesures 1 et 3. L'aligneur pouvait
/// "expliquer" ce si en reculant de deux mesures en plein jeu, puis en
/// sautant en avant a la fin. Un enfant ne recule pas sans s'arreter.
void main() {
  final Passage piece = () {
    final PassageBuilder b = PassageBuilder();
    for (final List<int> m in <List<int>>[
      <int>[69, 69, 69, 71],
      <int>[67, 67, 67, 67],
      <int>[69, 69, 69, 71],
      <int>[67, 67, 67, 67],
      <int>[69, 69, 69, 69],
    ]) {
      for (final int midi in m) {
        b.add(midi, NoteValue.quarter);
      }
    }
    b
      ..add(74, NoteValue.half)
      ..add(74, NoteValue.half);
    return Passage(
      title: 'repetee',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 100,
    );
  }();

  test('une note ajoutee ne fait pas reculer en plein jeu',
      skip: 'Lot P5 (ADR-019) : une note ajoutee coute a l aligneur autant '
          'de trames qu elle dure, un saut un prix fixe ; sur des notes '
          'longues, reculer d une mesure revient moins cher.', () {
    // Ce qui est joue : les mesures 1 a 4, puis la la si la la, puis re re.
    final List<int> joue = <int>[
      69, 69, 69, 71, 67, 67, 67, 67, //
      69, 69, 69, 71, 67, 67, 67, 67,
      69, 69, 71, 69, 69, 74, 74,
    ];
    const int pas = 600;
    final Float32List son = ViolinSynth(a4: 440).render(
      <BowedNote>[
        for (int k = 0; k < joue.length; k++)
          BowedNote(
            start: Duration(milliseconds: 300 + pas * k),
            duration: const Duration(milliseconds: pas),
            midi: joue[k].toDouble(),
          ),
      ],
      length: Duration(milliseconds: 300 + pas * joue.length + 800),
    );
    final Alignment a =
        OfflineAligner(piece).align(PerformanceFeatures.extract(son));
    final Map<String, int> mesure = <String, int>{
      for (final ScoreNote n in piece.notes) n.id: n.measure,
    };
    // Note jouee k, a mi-duree : dans quelle mesure l'aligneur la met-il ?
    int mesureA(int k) {
      final int t = 300 + pas * k + pas ~/ 2;
      String? id;
      for (int f = 0; f < a.frameTimesMs.length; f++) {
        if (a.frameTimesMs[f] <= t) {
          id = a.frameNotes[f] ?? id;
        }
      }
      return mesure[id] ?? -1;
    }

    // Les mesures 3 et 4 restent les mesures 3 et 4 : pas de recul vers 1
    // et 2 pour preparer le si de la mesure 5.
    for (int k = 8; k < 16; k++) {
      expect(mesureA(k), 3 + (k - 8) ~/ 4, reason: 'note jouee $k');
    }
    // La fin est la mesure 5 puis la mesure 6.
    expect(mesureA(17), 5);
    expect(mesureA(21), 6);
  });
}
