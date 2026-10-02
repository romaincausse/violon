import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/scoring/finger_diagnosis.dart';
import 'package:violon/core/store/take_history.dart';

void main() {
  TakeRecord prise(int minute, List<NoteTrace> notes) => TakeRecord(
        atMs: DateTime(2026, 10, 2, 18, minute).millisecondsSinceEpoch,
        key: 'exo:gamme',
        title: 'Gamme',
        fromMeasure: 1,
        toMeasure: 2,
        writtenPulseBpm: 72,
        durationMs: 20000,
        notes: notes,
      );

  NoteTrace n(int midi, double cents) =>
      NoteTrace(midi: midi, measure: 1, cents: cents);

  test('corde et doigt en premiere position', () {
    expect(fingeringOf(55), isNull, reason: 'sol a vide');
    expect(fingeringOf(57), (ViolinString.g, FingerPlace.one));
    expect(fingeringOf(66), (ViolinString.d, FingerPlace.high2), reason: 'fa#');
    expect(fingeringOf(65), (ViolinString.d, FingerPlace.low2), reason: 'fa');
    expect(fingeringOf(74), (ViolinString.a, FingerPlace.three), reason: 're5');
    expect(fingeringOf(69), isNull, reason: 'la a vide, pas 4e doigt');
    expect(fingeringOf(90), isNull, reason: 'hors premiere position');
  });

  test('un 2e doigt haut qui tombe bas sur toutes les cordes se voit', () {
    // fa# (re), do# (la), si (sol), sol# (mi) : tous en 2e doigt haut, bas.
    final TakeHistory h = TakeHistory.vide
        .withTake(prise(0, <NoteTrace>[
          n(66, -20), n(73, -18), n(59, -22), n(80, -15),
          // Le reste tombe juste.
          n(64, 2), n(71, -3), n(57, 4), n(67, 1),
        ]))
        .withTake(prise(10, <NoteTrace>[
          n(66, -17),
          n(73, -24),
          n(64, -1),
          n(71, 3),
        ]));
    final FingerDiagnosis d = FingerDiagnosis.of(h);
    final FingerFinding f = d.main!;
    expect(f.place, FingerPlace.high2);
    expect(f.flat, isTrue);
    expect(f.medianCents, closeTo(-20, 3));
    expect(f.strings.length, greaterThanOrEqualTo(3));
    expect(d.findings, hasLength(1), reason: 'les autres doigts sont justes');
  });

  test('un accident isole n est pas un defaut de la main', () {
    final TakeHistory h = TakeHistory.vide.withTake(prise(0, <NoteTrace>[
      n(66, -30),
      n(66, -28),
    ]));
    expect(FingerDiagnosis.of(h).main, isNull);
  });

  test('les cordes a vide ne disent rien de la main', () {
    final TakeHistory h = TakeHistory.vide.withTake(prise(0, <NoteTrace>[
      for (int i = 0; i < 10; i++) n(62, -25),
      for (int i = 0; i < 10; i++) n(69, -25),
    ]));
    expect(FingerDiagnosis.of(h).main, isNull);
  });
}
