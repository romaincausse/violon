import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/store/take_history.dart';
import 'package:violon/core/store/week_report.dart';

void main() {
  final DateTime maintenant = DateTime(2026, 10, 9, 19);

  TakeRecord prise(
    int joursAvant, {
    String key = 'piece:stars:8-12',
    String titre = 'Into the Stars',
    int? tempo = 70,
    List<MeasureTrace> mesures = const <MeasureTrace>[],
    List<NoteTrace> notes = const <NoteTrace>[],
  }) =>
      TakeRecord(
        atMs: maintenant
            .subtract(Duration(days: joursAvant))
            .millisecondsSinceEpoch,
        key: key,
        title: titre,
        fromMeasure: 8,
        toMeasure: 12,
        writtenPulseBpm: 94,
        durationMs: 120000,
        heldPulseBpm: tempo,
        tuningScore: 80,
        rhythmScore: 85,
        reachedEnd: true,
        measures: mesures,
        notes: notes,
      );

  test('les jours joues, ce qui a monte, sans jamais les jours manques', () {
    final TakeHistory h = TakeHistory.vide
        .withTake(prise(12, tempo: 60))
        .withTake(prise(5, tempo: 64))
        .withTake(prise(2, tempo: 70))
        .withTake(prise(2, key: 'exo:gamme', titre: 'Gamme de re', tempo: 72));
    final WeekReport r = WeekReport.of(h, maintenant);
    expect(r.days, hasLength(2));
    expect(r.playing, const Duration(minutes: 6));
    expect(r.works.first.title, 'Into the Stars');
    expect(r.works.first.rose, isTrue);
    expect(r.works.first.previousBestPulseBpm, 60);
    expect(r.works.first.bestPulseBpm, 70);
    final String texte = r.toText();
    expect(texte, contains('2 jours de travail, 6 min d archet, 3 prises'));
    expect(texte, contains('Into the Stars : 2 prises, tempo 60 -> 70'));
    // Le rapport ne parle jamais de ce qui n'a pas ete fait.
    expect(texte, isNot(contains('manque')));
    expect(texte, isNot(contains('0 min')));
  });

  test('les mesures qui resistent, et combien de fois il y est revenu', () {
    TakeHistory h = TakeHistory.vide;
    for (int i = 0; i < 4; i++) {
      h = h.withTake(prise(i, mesures: const <MeasureTrace>[
        MeasureTrace(measure: 10, difficulty: 50, restarts: 4, stops: 1),
        MeasureTrace(measure: 9, difficulty: 5),
      ]));
    }
    final WeekReport r = WeekReport.of(h, maintenant);
    expect(r.resisting.single.measure, 10);
    expect(r.resisting.single.restarts, 16);
    expect(r.toText(), contains('mesure 10 : reprise 16 fois, 4 arrets'));
  });

  test('une note jouee basse avec constance est un fait, chiffre', () {
    TakeHistory h = TakeHistory.vide;
    for (int i = 0; i < 5; i++) {
      h = h.withTake(prise(i, notes: <NoteTrace>[
        // do#5, bas dans quatre prises sur cinq.
        NoteTrace(midi: 73, measure: 10, cents: i == 0 ? -5 : -22),
        const NoteTrace(midi: 74, measure: 10, cents: 3),
      ]));
    }
    final WeekReport r = WeekReport.of(h, maintenant);
    expect(r.noteFact!.midi, 73);
    expect(r.noteFact!.off, 4);
    expect(r.noteFact!.total, 5);
    expect(r.toText(), contains('Do#5 : bas de 22 cents, 4 prises sur 5'));
  });

  test('une semaine sans prise dit qu il n y a rien, sans reproche', () {
    final WeekReport r = WeekReport.of(TakeHistory.vide, maintenant);
    expect(r.days, isEmpty);
    expect(r.works, isEmpty);
    expect(r.toText(), isNot(contains('resiste')));
  });
}
