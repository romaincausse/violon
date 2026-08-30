import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/demo_passage.dart';
import 'package:violon/core/practice/practice_session.dart';
import 'package:violon/core/practice/variation_generator.dart';

void main() {
  PracticeSession session({int rounds = 10, int startTempoBpm = 60}) {
    return PracticeSession.forPassage(
      buildDemoPassage(),
      rounds: rounds,
      startTempoBpm: startTempoBpm,
      seed: 1,
    );
  }

  group('PracticeSession', () {
    test('affiche la totalite des tours des le depart', () {
      final PracticeSession s = session();
      expect(s.totalRounds, 10);
      expect(s.outcomes.length, 10);
      expect(s.outcomes.every((RoundOutcome o) => o == RoundOutcome.pending),
          isTrue);
      expect(s.currentRoundNumber, 1);
    });

    test('une erreur fait quand meme avancer le compteur', () {
      final PracticeSession s = session();
      s.completeRound(RoundOutcome.shaky);
      expect(s.currentRoundNumber, 2);
      expect(s.outcomes.first, RoundOutcome.shaky);
    });

    test('le tempo monte apres un tour propre', () {
      final PracticeSession s = session(startTempoBpm: 60);
      expect(s.workingTempoBpm, 60);
      s.completeRound(RoundOutcome.clean);
      expect(s.workingTempoBpm, 64);
    });

    test('le tempo ne monte pas apres un tour approximatif', () {
      final PracticeSession s = session(startTempoBpm: 60);
      s.completeRound(RoundOutcome.shaky);
      expect(s.workingTempoBpm, 60);
    });

    test('le tempo ne monte pas sur une variation passee', () {
      final PracticeSession s = session(startTempoBpm: 60);
      s.skipVariation();
      expect(s.workingTempoBpm, 60);
      expect(s.outcomes.first, RoundOutcome.skipped);
    });

    test('plafonne le tempo', () {
      final PracticeSession s = PracticeSession.forPassage(
        buildDemoPassage(),
        rounds: 40,
        startTempoBpm: 195,
        seed: 3,
      );
      for (int i = 0; i < 10; i++) {
        s.completeRound(RoundOutcome.clean);
      }
      expect(s.workingTempoBpm, lessThanOrEqualTo(200));
    });

    test('le dernier tour se joue au tempo ecrit', () {
      final PracticeSession s = session();
      while (s.currentRoundNumber < s.totalRounds) {
        s.completeRound(RoundOutcome.clean);
      }
      expect(s.currentVariation.id, VariationGenerator.asWritten.id);
      expect(s.currentTempoBpm, buildDemoPassage().writtenTempoBpm);
    });

    test('le compteur de tours ne depasse jamais le total', () {
      final PracticeSession s = session(rounds: 3);
      for (int i = 0; i < 3; i++) {
        s.completeRound(RoundOutcome.clean);
      }
      expect(s.isFinished, isTrue);
      // Sans plafond, l'ecran de bilan annoncait "Tour 4 / 3".
      expect(s.currentRoundNumber, 3);
    });

    test('se termine apres le dernier tour', () {
      final PracticeSession s = session(rounds: 3);
      for (int i = 0; i < 3; i++) {
        s.completeRound(RoundOutcome.clean);
      }
      expect(s.isFinished, isTrue);
      expect(s.roundsRemaining, 0);
    });

    test('ignore les tours supplementaires une fois terminee', () {
      final PracticeSession s = session(rounds: 2);
      s.completeRound(RoundOutcome.clean);
      s.completeRound(RoundOutcome.clean);
      s.completeRound(RoundOutcome.clean);
      expect(s.cleanRounds, 2);
    });

    test('decompte vers l\'avant', () {
      final PracticeSession s = session(rounds: 10);
      expect(s.roundsRemaining, 10);
      s.completeRound(RoundOutcome.shaky);
      expect(s.roundsRemaining, 9);
    });

    test('refuse de cloturer un tour en "pending"', () {
      expect(
        () => session().completeRound(RoundOutcome.pending),
        throwsArgumentError,
      );
    });
  });
}
