import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/play/accompaniment.dart';
import 'package:violon/core/play/accompaniment_plan.dart';
import 'package:violon/core/play/following_accompanist.dart';

void main() {
  // Huit noires a 60 : une seconde par noire, 480 ticks.
  final Passage p = () {
    final PassageBuilder b = PassageBuilder();
    for (int i = 0; i < 8; i++) {
      b.add(60 + i, NoteValue.quarter);
    }
    return Passage(
      title: 't',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 60,
    );
  }();
  // Une basse par croche.
  final List<AccompanimentNote> basse = <AccompanimentNote>[
    for (int t = 0; t < 8 * 480; t += 240)
      AccompanimentNote(midi: 48, onsetTicks: t, durationTicks: 240),
  ];

  FollowingAccompanist accompagnateur() => FollowingAccompanist(
        passage: p,
        notes: basse,
        latencyMs: 100,
      );

  List<int> instants(List<TimedNote> n) =>
      <int>[for (final TimedNote x in n) x.at.inMilliseconds];

  test('un temps d avance, cale sur l attaque, latence retranchee', () {
    final FollowingAccompanist a = accompagnateur();
    // Il attaque la note 0 au temps 1000 du micro ; micro + 5000 = moteur.
    final List<TimedNote> n = a.noteStarted(
      noteIndex: 0,
      attackMicMs: 1000,
      micToEngineMs: 5000,
      nowEngineMs: 5800,
    );
    // L'attaque vaut 6000 cote moteur, moins 100 de latence : 5900. La
    // croche du temps (5900) est posee ; la suivante a 6400 ; et celle du
    // temps suivant (6900), a un temps de distance.
    expect(instants(n), <int>[5900, 6400, 6900]);
  });

  test('il suit le tempo que l eleve tient', () {
    final FollowingAccompanist a = accompagnateur();
    a.noteStarted(
        noteIndex: 0, attackMicMs: 0, micToEngineMs: 0, nowEngineMs: -500);
    // La note 1 arrive 500 ms plus tard : il joue a 120.
    final List<TimedNote> n = a.noteStarted(
      noteIndex: 1,
      attackMicMs: 500,
      micToEngineMs: 0,
      nowEngineMs: 300,
      quarterBpm: 120,
    );
    // Rien n'est pose deux fois ; la suite, a 250 ms la croche.
    expect(instants(n), <int>[650, 900]);
    expect(n.first.duration, const Duration(milliseconds: 250));
  });

  test('une reprise recale l accompagnement sur la note reprise', () {
    final FollowingAccompanist a = accompagnateur();
    a.noteStarted(
        noteIndex: 4, attackMicMs: 0, micToEngineMs: 0, nowEngineMs: -500);
    // Il revient a la note 2.
    final List<TimedNote> n = a.noteStarted(
      noteIndex: 2,
      attackMicMs: 3000,
      micToEngineMs: 0,
      nowEngineMs: 2800,
    );
    expect(n.first.at.inMilliseconds, 2900);
  });

  test('ce qui serait en retard se tait', () {
    final FollowingAccompanist a = accompagnateur();
    final List<TimedNote> n = a.noteStarted(
      noteIndex: 0,
      attackMicMs: 1000,
      micToEngineMs: 0,
      // Le moteur est deja passe : seule la croche suivante peut sonner.
      nowEngineMs: 1300,
    );
    expect(instants(n), <int>[1400, 1900]);
  });
}
