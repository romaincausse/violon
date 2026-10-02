import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/follow/tempo_tracker.dart';
import 'package:violon/core/music/meter.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';

void main() {
  // Huit noires.
  Passage noires({Meter? meter}) {
    final PassageBuilder b = PassageBuilder();
    for (int i = 0; i < 8; i++) {
      b.add(62 + i, NoteValue.quarter);
    }
    return Passage(
      title: 't',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      meter: meter,
    );
  }

  test('le tempo tenu est celui qu il joue, pas celui du papier', () {
    final TempoTracker t = TempoTracker(noires());
    // Une noire toutes les 750 ms : 80 a la noire.
    for (int i = 0; i < 5; i++) {
      t.noteStarted(i, 1000 + i * 750);
    }
    expect(t.quarterBpm, closeTo(80, 0.01));
    expect(t.pulseBpm, 80);
  });

  test('tant qu il n a pas enchaine trois notes, il ne dit rien', () {
    final TempoTracker t = TempoTracker(noires());
    t.noteStarted(0, 0);
    t.noteStarted(1, 600);
    t.noteStarted(2, 1200);
    expect(t.quarterBpm, isNull);
    t.noteStarted(3, 1800);
    expect(t.quarterBpm, closeTo(100, 0.01));
  });

  test('une hesitation ne fait pas s effondrer le tempo', () {
    final TempoTracker t = TempoTracker(noires());
    for (int i = 0; i < 5; i++) {
      t.noteStarted(i, i * 600);
    }
    // Quatre secondes avant la note suivante.
    t.noteStarted(5, 4 * 600 + 4000);
    t.noteStarted(6, 4 * 600 + 4600);
    expect(t.quarterBpm, closeTo(100, 0.01));
  });

  test('une reprise ou un arret ne comptent pas comme un tempo', () {
    final TempoTracker t = TempoTracker(noires());
    for (int i = 0; i < 4; i++) {
      t.noteStarted(i, i * 500);
    }
    // Il reprend au debut : de la note 3 a la note 0 il n'y a pas de tempo.
    t.noteStarted(0, 1700);
    t.stopped();
    t.noteStarted(1, 9000);
    expect(t.quarterBpm, closeTo(120, 0.01));
  });

  test('en 6/8, le tempo se dit a la noire pointee', () {
    final TempoTracker t = TempoTracker(noires(meter: const Meter(6, 8)));
    // Noire a 141 : noire pointee a 94.
    for (int i = 0; i < 5; i++) {
      t.noteStarted(i, (i * 60000 / 141).round());
    }
    expect(t.pulseBpm, 94);
  });

  test('la pulsation repart de sa derniere attaque sur un temps', () {
    final TempoTracker t = TempoTracker(noires());
    for (int i = 0; i < 4; i++) {
      t.noteStarted(i, i * 500);
    }
    expect(t.beatPhase(1500), closeTo(0, 1e-9));
    expect(t.beatPhase(1750), closeTo(0.5, 1e-9));
    // Il pose la note suivante un peu tard : la pulsation se recale sur lui.
    t.noteStarted(4, 2100);
    expect(t.beatPhase(2100), closeTo(0, 1e-9));
  });
}
