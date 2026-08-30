import 'passage.dart';
import 'score_note.dart';

/// Passage de demonstration, utilise par l'ecran de demo et les tests.
///
/// Huit croches conjointes en sol majeur, premiere position : le genre de
/// mesure qu'on fait repeter dix fois.
Passage buildDemoPassage() {
  const int ticksPerBeat = 480;
  const int eighth = ticksPerBeat ~/ 2;
  const List<int> midis = <int>[67, 69, 71, 72, 74, 72, 71, 69];

  final List<ScoreNote> notes = <ScoreNote>[];
  for (int i = 0; i < midis.length; i++) {
    notes.add(
      ScoreNote(
        id: 'n${i + 1}',
        midi: midis[i],
        onsetTicks: i * eighth,
        durationTicks: eighth,
        measure: 12 + (i ~/ 4),
      ),
    );
  }

  return Passage(
    title: 'Demo - mesures 12 a 13',
    notes: notes,
    ticksPerBeat: ticksPerBeat,
    writtenTempoBpm: 92,
  );
}
