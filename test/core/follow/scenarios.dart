import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/alignment_report.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/online_follower.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/follow/synthetic_take.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';

/// Cinq mesures de 4/4 en sol majeur, avec ce qui piege un suiveur : des
/// notes repetees a la meme hauteur (mesure 2), des durees melangees, un
/// retour sur des notes deja entendues.
///
///   m1  sol la si do            (noires)
///   m2  re re re re  mi re      (4 croches, 2 noires)
///   m3  do si la  sol           (noire, 2 croches, blanche)
///   m4  la si  do re mi fa#     (2 noires, 4 croches)
///   m5  sol re                  (blanches)
Passage melodie() {
  final PassageBuilder b = PassageBuilder();
  void n(int midi, NoteValue v) => b.add(midi, v);
  for (final int m in <int>[67, 69, 71, 72]) {
    n(m, NoteValue.quarter);
  }
  for (int i = 0; i < 4; i++) {
    n(74, NoteValue.eighth);
  }
  n(76, NoteValue.quarter);
  n(74, NoteValue.quarter);
  n(72, NoteValue.quarter);
  n(71, NoteValue.eighth);
  n(69, NoteValue.eighth);
  n(67, NoteValue.half);
  n(69, NoteValue.quarter);
  n(71, NoteValue.quarter);
  for (final int m in <int>[72, 74, 76, 78]) {
    n(m, NoteValue.eighth);
  }
  n(79, NoteValue.half);
  n(74, NoteValue.half);
  return Passage(
    title: 'melodie',
    notes: b.notes,
    ticksPerBeat: b.ticksPerBeat,
    writtenTempoBpm: 92,
  );
}

/// Le piege d'*Into the Stars*, en petit : la mesure 3 reprend la mesure 1
/// note pour note, et les phrases ne se separent qu'a la deuxieme note de la
/// mesure suivante.
///
///   m1  re mi fa# sol    m2  la sol fa# mi
///   m3  re mi fa# sol    m4  la si do# re
Passage phraseRepetee() {
  final PassageBuilder b = PassageBuilder();
  for (final int m in <int>[
    62, 64, 66, 67, 69, 67, 66, 64, //
    62, 64, 66, 67, 69, 71, 73, 74,
  ]) {
    b.add(m, NoteValue.quarter);
  }
  return Passage(
    title: 'phrase repetee',
    notes: b.notes,
    ticksPerBeat: b.ticksPerBeat,
    writtenTempoBpm: 92,
  );
}

/// Les positions d'une prise, au fil de l'eau, telles que le suiveur en
/// direct les a rendues.
Alignment enDirect(
  List<FeatureFrame> trames,
  Passage passage, {
  Set<String> slurredInto = const <String>{},
}) {
  final OnlineFollower suiveur =
      OnlineFollower(passage, slurredInto: slurredInto);
  final List<String?> notes = List<String?>.filled(trames.length, null);
  int i = 0;
  for (final FeatureFrame t in trames) {
    final FollowPosition? pos = suiveur.add(t);
    if (pos != null) {
      notes[i++] = pos.playing ? passage.notes[pos.noteIndex!].id : null;
    }
  }
  return Alignment(
    frameTimesMs: <int>[for (final FeatureFrame t in trames) t.timeMs],
    frameNotes: notes,
  );
}

/// Toute la chaine, du scenario au verdict.
AlignmentReport aligner(
  SyntheticTake prise,
  Passage passage, {
  Set<String> slurredInto = const <String>{},
  ViolinSynth? synth,
}) {
  final List<FeatureFrame> trames =
      PerformanceFeatures.extract(prise.render(synth ?? ViolinSynth()));
  final Alignment a =
      OfflineAligner(passage, slurredInto: slurredInto).align(trames);
  return AlignmentReport.evaluate(
    a,
    GroundTruth.parseAudacity(prise.audacityLabels()),
    passage,
  );
}

/// La meme chaine, avec le suiveur en direct a la place de l'aligneur : la
/// position qu'il a rendue pour chaque trame, au fil de l'eau.
AlignmentReport suivre(
  SyntheticTake prise,
  Passage passage, {
  Set<String> slurredInto = const <String>{},
  ViolinSynth? synth,
}) {
  final List<FeatureFrame> trames =
      PerformanceFeatures.extract(prise.render(synth ?? ViolinSynth()));
  return AlignmentReport.evaluate(
    enDirect(trames, passage, slurredInto: slurredInto),
    GroundTruth.parseAudacity(prise.audacityLabels()),
    passage,
  );
}
