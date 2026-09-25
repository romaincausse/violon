import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/pitch_estimate.dart';
import 'package:violon/core/music/pitch_utils.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/scoring/live_tuning.dart';

void main() {
  const ScoreNote la4 = ScoreNote(
    id: 'n1',
    midi: 69,
    onsetTicks: 0,
    durationTicks: 480,
    measure: 1,
  );

  /// Une mesure a [cents] de la note temperee [midi].
  PitchEstimate joue(int midi, double cents, {double confidence = 1}) {
    return PitchEstimate(
      frequencyHz: PitchUtils.midiToFrequency(midi) *
          math.pow(2, cents / 1200).toDouble(),
      confidence: confidence,
      timestampMs: 0,
    );
  }

  group('LiveTuning', () {
    test('sans son, aucun verdict', () {
      expect(LiveTuning().verdictFor('n1'), TuningVerdict.unknown);
    });

    test('une seule mesure ne suffit pas a se prononcer', () {
      // Le temps de l'attaque, la hauteur glisse. Se prononcer sur la
      // premiere trame ferait clignoter la partition.
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, 0));
      expect(t.verdictFor('n1'), TuningVerdict.unknown);
      t.observe(la4, joue(69, 0));
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
    });

    test('juste, bas, haut', () {
      for (final (double cents, TuningVerdict attendu)
          in <(double, TuningVerdict)>[
        (0, TuningVerdict.inTune),
        (30, TuningVerdict.inTune),
        (-30, TuningVerdict.inTune),
        (60, TuningVerdict.high),
        (-60, TuningVerdict.low),
      ]) {
        final LiveTuning t = LiveTuning();
        t.observe(la4, joue(69, cents));
        t.observe(la4, joue(69, cents));
        expect(t.verdictFor('n1'), attendu, reason: '$cents cents');
      }
    });

    test('la tolerance se regle', () {
      // On ne teste pas la valeur pile sur la limite : elle se joue a la
      // representation d'un flottant, ce qui n'apprend rien sur le code.
      final LiveTuning t = LiveTuning(toleranceCents: 20);
      t.observe(la4, joue(69, 19));
      t.observe(la4, joue(69, 19));
      expect(t.verdictFor('n1'), TuningVerdict.inTune);

      final LiveTuning u = LiveTuning(toleranceCents: 20);
      u.observe(la4, joue(69, 21));
      u.observe(la4, joue(69, 21));
      expect(u.verdictFor('n1'), TuningVerdict.high);
    });

    test('un vibrato large ne rend pas la note fausse', () {
      // Cinquante cents d'oscillation, ce qui deborde largement la tolerance
      // a chaque extreme. La mediane retombe au centre : c'est exactement
      // pour ca qu'on ne prend pas la moyenne des ecarts absolus.
      final LiveTuning t = LiveTuning();
      for (final double cents in <double>[-50, 45, -48, 50, -46, 47, 0]) {
        t.observe(la4, joue(69, cents));
      }
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
    });

    test('une attaque fausse ne condamne pas une note tenue juste', () {
      // Le glissando du debut d'archet tire une moyenne ; la mediane l'ignore.
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, -180));
      t.observe(la4, joue(69, -90));
      for (int i = 0; i < 6; i++) {
        t.observe(la4, joue(69, 5));
      }
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
    });

    test('jouer juste la mauvaise note ne passe pas pour juste', () {
      // Le piege que la comparaison a la note temperee la plus proche ne
      // verrait pas : un si4 parfait la ou on attendait un la4.
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(71, 0));
      t.observe(la4, joue(71, 0));
      expect(t.verdictFor('n1'), TuningVerdict.high);
    });

    test('les mesures peu sures sont ignorees', () {
      // Changement d'archet, silence, bruit de la piece.
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 5; i++) {
        t.observe(la4, joue(69, 300, confidence: 0.2));
      }
      expect(t.sampleCountFor('n1'), 0);
      expect(t.verdictFor('n1'), TuningVerdict.unknown);
    });

    test('chaque note a son propre verdict', () {
      const ScoreNote si4 = ScoreNote(
        id: 'n2',
        midi: 71,
        onsetTicks: 480,
        durationTicks: 480,
        measure: 1,
      );
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 2; i++) {
        t.observe(la4, joue(69, 0));
        t.observe(si4, joue(71, -70));
      }
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
      expect(t.verdictFor('n2'), TuningVerdict.low);
    });

    test('le diapason de reference deplace le jugement', () {
      // Un enfant accorde a 442 joue son la4 a 442 Hz. Juge contre 440, il
      // est haut de 8 cents ; juge contre son propre accord, il est juste.
      const PitchEstimate a442 = PitchEstimate(
        frequencyHz: 442,
        confidence: 1,
        timestampMs: 0,
      );
      final LiveTuning contre440 = LiveTuning(toleranceCents: 5);
      final LiveTuning contre442 = LiveTuning(toleranceCents: 5, a4: 442);
      for (int i = 0; i < 2; i++) {
        contre440.observe(la4, a442);
        contre442.observe(la4, a442);
      }
      expect(contre440.verdictFor('n1'), TuningVerdict.high);
      expect(contre442.verdictFor('n1'), TuningVerdict.inTune);
    });

    test('recommencer le passage oublie le precedent', () {
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, -80));
      t.observe(la4, joue(69, -80));
      expect(t.verdictFor('n1'), TuningVerdict.low);
      t.reset();
      expect(t.verdictFor('n1'), TuningVerdict.unknown);
    });
  });

  group('LiveTuning, exclusion de l attaque', () {
    test('sans information de temps, tout est retenu', () {
      // Les appelants qui ne savent pas ou en est la note gardent l'ancien
      // comportement.
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, 0));
      t.observe(la4, joue(69, 0));
      expect(t.sampleCountFor('n1'), 2);
    });

    test('le debut de la note est ecarte', () {
      // Pendant qu'un archet se pose, la hauteur glisse sur des dizaines de
      // cents avant de se fixer. Le compter reviendrait a reprocher a
      // l'enfant la physique de son instrument.
      final LiveTuning t = LiveTuning(attackMs: 80);
      t.observe(la4, joue(69, -200), sinceNoteStartMs: 0);
      t.observe(la4, joue(69, -120), sinceNoteStartMs: 46);
      expect(t.sampleCountFor('n1'), 0);

      t.observe(la4, joue(69, 0), sinceNoteStartMs: 92);
      expect(t.sampleCountFor('n1'), 1);
    });

    test('une attaque ratee ne condamne plus une note tenue juste', () {
      final LiveTuning t = LiveTuning();
      t.observe(la4, joue(69, -250), sinceNoteStartMs: 0);
      t.observe(la4, joue(69, -180), sinceNoteStartMs: 46);
      for (int i = 0; i < 4; i++) {
        t.observe(la4, joue(69, 4), sinceNoteStartMs: 92 + i * 46);
      }
      expect(t.verdictFor('n1'), TuningVerdict.inTune);
      expect(t.scoreFor('n1'), 100);
    });
  });

  group('LiveTuning, note sur cent', () {
    test('la courbe est genereuse pres de la cible', () {
      // Dix cents, c'est en deca de ce que l'oreille distingue sur une note
      // isolee : y perdre des points serait absurde.
      expect(LiveTuning.noteScoreForCents(0), 100);
      expect(LiveTuning.noteScoreForCents(10), 100);
      expect(LiveTuning.noteScoreForCents(-10), 100);
    });

    test('elle descend regulierement jusqu au demi-ton', () {
      // On teste la forme de la courbe, pas un point precis : figer une
      // valeur intermediaire revient a figer `perfectCents`, et la moindre
      // revision du bareme casse un test qui ne dit rien de plus.
      expect(LiveTuning.noteScoreForCents(100), 0, reason: 'une autre note');
      expect(LiveTuning.noteScoreForCents(-100), 0);
      expect(LiveTuning.noteScoreForCents(LiveTuning.perfectCents), 100);

      int precedent = 101;
      for (double cents = LiveTuning.perfectCents;
          cents <= LiveTuning.worstCents;
          cents += 5) {
        final int note = LiveTuning.noteScoreForCents(cents);
        expect(note, lessThanOrEqualTo(precedent),
            reason: 'jouer plus faux ne rapporte jamais plus');
        precedent = note;
      }
    });

    test('la courbe est symetrique : trop bas vaut trop haut', () {
      for (final double cents in <double>[30, 45, 70, 90]) {
        expect(LiveTuning.noteScoreForCents(cents),
            LiveTuning.noteScoreForCents(-cents));
      }
    });

    test('au-dela du demi-ton, on ne descend pas sous zero', () {
      expect(LiveTuning.noteScoreForCents(400), 0);
    });

    test('une note non entendue n a pas de note', () {
      final LiveTuning t = LiveTuning();
      expect(t.scoreFor('n1'), isNull);
      t.observe(la4, joue(69, 0));
      expect(t.scoreFor('n1'), isNull,
          reason: 'une seule mesure ne suffit pas');
    });

    test('la note d ensemble est la moyenne des notes entendues', () {
      const ScoreNote si4 = ScoreNote(
        id: 'n2',
        midi: 71,
        onsetTicks: 480,
        durationTicks: 480,
        measure: 1,
      );
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 2; i++) {
        t.observe(la4, joue(69, 0));
        t.observe(si4, joue(71, 55));
      }
      final int? juste = t.scoreFor('n1');
      final int? faux = t.scoreFor('n2');
      expect(juste, 100);
      expect(faux, lessThan(100));
      expect(t.overallScore, ((juste! + faux!) / 2).round());
    });

    test('une note non entendue ne compte pas pour zero', () {
      // La compter punirait un silence, un archet rate ou un micro trop loin
      // comme une fausse note.
      const ScoreNote si4 = ScoreNote(
        id: 'n2',
        midi: 71,
        onsetTicks: 480,
        durationTicks: 480,
        measure: 1,
      );
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 2; i++) {
        t.observe(la4, joue(69, 0));
      }
      t.observe(si4, joue(71, 0)); // une seule mesure : pas assez
      expect(t.overallScore, 100);
      expect(t.heardNoteIds, <String>['n1']);
    });

    test('sans rien entendu, il n y a pas de note d ensemble', () {
      expect(LiveTuning().overallScore, isNull);
    });

    test('recommencer efface la note d ensemble', () {
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 2; i++) {
        t.observe(la4, joue(69, 0));
      }
      expect(t.overallScore, 100);
      t.reset();
      expect(t.overallScore, isNull);
    });
  });

  group('intonation expressive', () {
    // Un violoniste ne joue pas tempere. La gamme temperee est un compromis
    // de clavier ; sur un instrument a hauteur libre, deux references sont
    // enseignees et toutes deux sont justes. Elles vont en sens INVERSE :
    // en jeu melodique on monte les tierces et les sensibles, en double
    // corde ou sur un bourdon on les baisse pour que l'accord sonne.
    //
    // Ecarts au tempere, en cents, calcules depuis les rapports de
    // frequences exacts.
    const Map<String, (double, double)> intervalles =
        <String, (double, double)>{
      // nom                        juste   pythagoricienne
      'tierce mineure': (15.6, -5.9),
      'tierce majeure': (-13.7, 7.8),
      'sixte majeure': (-15.6, 5.9),
      'septieme majeure': (-11.7, 9.8),
    };

    test('les deux references valent cent sur cent', () {
      intervalles.forEach((String nom, (double, double) ecarts) {
        expect(LiveTuning.noteScoreForCents(ecarts.$1), 100,
            reason: '\$nom juste');
        expect(LiveTuning.noteScoreForCents(ecarts.$2), 100,
            reason: '\$nom pythagoricienne');
      });
    });

    test('une sensible poussee haute vaut cent sur cent', () {
      // Le geste le plus enseigne du repertoire : la sensible se serre contre
      // la tonique. Vingt cents est courant, et ce n'est pas une faute.
      expect(LiveTuning.noteScoreForCents(20), 100);
    });

    test('le bareme est plus large que l ecart entre deux bonnes reponses', () {
      // C'est l'argument du lot. Sur la tierce majeure, les deux systemes
      // valides different de 21,5 cents. Noter plus finement, c'est
      // distinguer deux reponses correctes l'une de l'autre : on mesure du
      // bruit, et on retire des points a un enfant qui fait exactement ce que
      // son professeur lui demande.
      final (double, double) tierce = intervalles['tierce majeure']!;
      final double desaccord = (tierce.$2 - tierce.$1).abs();
      expect(desaccord, closeTo(21.5, 0.5));
      expect(LiveTuning.perfectCents, greaterThanOrEqualTo(desaccord));
    });

    test('mais un quart de ton reste une fausse note', () {
      // L'elargissement ne doit pas rendre le bareme complaisant : un demi
      // demi-ton n'appartient a aucun systeme d'intonation.
      expect(LiveTuning.noteScoreForCents(50), lessThan(75));
      expect(LiveTuning.noteScoreForCents(90), lessThan(20));
    });
  });

  group('rien a retravailler', () {
    test('un passage joue juste ne designe aucune mesure', () {
      // Defaut trouve en elargissant le bareme : quand toutes les notes
      // valent cent, la plus faible restait la premiere, et l'application
      // demandait de retravailler ce qui etait deja juste. C'est la regle
      // produit prise a l'envers.
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 3; i++) {
        t.observe(la4, joue(69, 3));
      }
      expect(t.overallScore, 100);
      expect(t.weakestNoteId, isNull);
    });

    test('des qu une note perd des points, elle est designee', () {
      const ScoreNote si4 = ScoreNote(
        id: 'n2',
        midi: 71,
        onsetTicks: 480,
        durationTicks: 480,
        measure: 2,
      );
      final LiveTuning t = LiveTuning();
      for (int i = 0; i < 3; i++) {
        t.observe(la4, joue(69, 0));
        t.observe(si4, joue(71, 60));
      }
      expect(t.weakestNoteId, 'n2');
    });
  });
}
