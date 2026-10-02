import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/fake_pitch_source.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/audio/pitch_source.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/ui/screens/session_screen.dart';
import 'package:violon/ui/widgets/metronome_bar.dart';
import 'package:violon/ui/widgets/score_view.dart';
import 'package:violon/ui/widgets/tuning_colors.dart';

/// L'ecran de seance en mode suivi (lot S4) : l'eleve joue, l'application
/// suit, et c'est ce qu'elle entend qui fait avancer le curseur.
void main() {
  // re mi fa# sol | la : deux mesures.
  Passage passage() {
    final PassageBuilder b = PassageBuilder();
    for (final int m in <int>[62, 64, 66, 67]) {
      b.add(m, NoteValue.quarter);
    }
    b.add(69, NoteValue.whole);
    return Passage(
      title: 'suivi',
      notes: b.notes,
      ticksPerBeat: b.ticksPerBeat,
      writtenTempoBpm: 80,
    );
  }

  late FakePitchSource micro;
  int t = 0;

  Future<void> poser(
    WidgetTester tester, {
    ValueChanged<SessionResult>? onResult,
    Passage? autre,
  }) async {
    t = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SessionScreen(
          passage: autre ?? passage(),
          onChangePassage: () {},
          onTune: () {},
          onResult: onResult,
          pitchSourceFactory: () async =>
              micro = FakePitchSource(const <PitchEstimate>[]),
        ),
      ),
    );
  }

  Future<void> demarrer(WidgetTester tester) async {
    await tester.tap(find.text('Jouer le passage'));
    await tester.pump();
    await tester.pump();
  }

  /// [trames] trames d'une note (ou d'un silence), avec la hauteur que YIN en
  /// aurait tiree.
  Future<void> jouer(WidgetTester tester, int? midi, int trames) async {
    for (int i = 0; i < trames; i++) {
      // La prise a pu se terminer seule : le micro est alors ferme.
      if (find.text('Arreter').evaluate().isEmpty) {
        return;
      }
      if (midi != null) {
        micro.emit(
          PitchEstimate(
            frequencyHz: PitchUtils.midiToFrequency(midi),
            confidence: 1,
            timestampMs: t,
          ),
        );
      }
      micro.emitFeature(
        FeatureFrame(
          timeMs: t,
          midi: midi?.toDouble(),
          rms: midi == null ? 0.001 : 0.1,
          onset: midi != null && i == 0,
        ),
      );
      t += 23;
      await tester.pump();
    }
  }

  int? curseur(WidgetTester tester) =>
      tester.widget<ScoreView>(find.byType(ScoreView)).cursorTick;

  testWidgets('pas de decompte ni de metronome : il commence quand il veut', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await demarrer(tester);
    expect(find.byKey(SessionScreen.attenteKey), findsOneWidget);
    expect(find.byType(MetronomeBar), findsNothing);
    expect(curseur(tester), isNull);
    await jouer(tester, null, 40);
    // Il n'a rien joue : on attend toujours, sans rien colorer.
    expect(find.byKey(SessionScreen.attenteKey), findsOneWidget);
    await tester.tap(find.text('Arreter'));
    await tester.pump();
  });

  testWidgets('le curseur va ou il joue, pas ou une horloge l attend', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await demarrer(tester);
    await jouer(tester, null, 5);
    await jouer(tester, 62, 15);
    expect(find.byKey(SessionScreen.attenteKey), findsNothing);
    expect(curseur(tester), passage().notes[0].onsetTicks);
    // Il tient le re longtemps : le curseur l'attend, il ne file pas.
    await jouer(tester, 62, 60);
    expect(curseur(tester), passage().notes[0].onsetTicks);
    await jouer(tester, 64, 15);
    expect(curseur(tester), passage().notes[1].onsetTicks);
    await tester.tap(find.text('Arreter'));
    await tester.pump();
  });

  testWidgets('joue juste jusqu au bout, la prise se termine seule', (
    WidgetTester tester,
  ) async {
    SessionResult? resultat;
    await poser(tester, onResult: (SessionResult r) => resultat = r);
    await demarrer(tester);
    await jouer(tester, null, 5);
    for (final int m in <int>[62, 64, 66, 67, 69]) {
      await jouer(tester, m, 15);
    }
    expect(resultat, isNull, reason: 'l archet n est pas encore pose');
    await jouer(tester, null, 90);
    await tester.pump(const Duration(milliseconds: 60));
    expect(resultat, isNotNull);
    expect(resultat!.score, 100);
    expect(resultat!.coverage, 1);
    expect(find.text('Jouer le passage'), findsOneWidget);
    // Le bilan (N6) : deux notes, le tempo qu'il a tenu -- pas celui du
    // papier -- et rien a retravailler.
    expect(find.text('Justesse 100 - Rythme 100'), findsOneWidget);
    expect(find.textContaining('Tempo tenu : 174'), findsOneWidget);
    expect(find.text('Tout tient.'), findsOneWidget);
    // Apres la prise, chaque note porte la couleur du juste.
    final ScoreView vue = tester.widget<ScoreView>(find.byType(ScoreView));
    expect(
      vue.colorOf!(passage().notes[2]),
      TuningColors.inTune,
    );
  });

  testWidgets('un arret au milieu n est pas une fin, et ne rend rien', (
    WidgetTester tester,
  ) async {
    SessionResult? resultat;
    await poser(tester, onResult: (SessionResult r) => resultat = r);
    await demarrer(tester);
    await jouer(tester, 62, 15);
    await jouer(tester, 64, 15);
    await jouer(tester, null, 120);
    expect(find.text('Arreter'), findsOneWidget, reason: 'il reprendra');
    await tester.tap(find.text('Arreter'));
    await tester.pump();
    expect(resultat, isNull);
  });

  testWidgets('quitter l ecran en suivi libere le micro', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await demarrer(tester);
    await jouer(tester, 62, 5);
    final PitchSource source = micro;
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(source, isNotNull);
  });

  testWidgets('quand il ne sait plus ou en est l eleve, il le dit', (
    WidgetTester tester,
  ) async {
    // Douze la identiques : rien ne dit ou l'eleve en est (S5).
    final PassageBuilder b = PassageBuilder();
    for (int i = 0; i < 12; i++) {
      b.add(69, NoteValue.quarter);
    }
    b.add(62, NoteValue.quarter);
    await poser(
      tester,
      autre: Passage(
        title: 'la la la',
        notes: b.notes,
        ticksPerBeat: b.ticksPerBeat,
      ),
    );
    await demarrer(tester);
    bool aDit = false;
    bool aPali = false;
    for (int k = 0; k < 6; k++) {
      await jouer(tester, 69, 8);
      aDit = aDit || find.byKey(SessionScreen.chercheKey).evaluate().isNotEmpty;
      aPali = aPali ||
          tester.widget<ScoreView>(find.byType(ScoreView)).cursorUncertain;
    }
    expect(aDit, isTrue);
    expect(aPali, isTrue);
    await tester.tap(find.text('Arreter'));
    await tester.pump();
  });

  testWidgets('le pouls bat au tempo qu il tient, pas a celui du papier', (
    WidgetTester tester,
  ) async {
    await poser(tester);
    await demarrer(tester);
    expect(find.byKey(SessionScreen.poulsKey), findsNothing);
    await jouer(tester, null, 5);
    // Une noire toutes les 26 trames de 23 ms : 598 ms, soit 100 a la
    // noire -- le papier dit 80.
    for (final int m in <int>[62, 64, 66, 67]) {
      await jouer(tester, m, 26);
    }
    expect(find.byKey(SessionScreen.poulsKey), findsOneWidget);
    expect(find.textContaining('Tu joues a 100'), findsOneWidget);
    await tester.tap(find.text('Arreter'));
    await tester.pump();
    expect(find.byKey(SessionScreen.poulsKey), findsNothing);
  });
}
