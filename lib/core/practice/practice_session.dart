import '../music/passage.dart';
import 'variation.dart';
import 'variation_generator.dart';

/// Resultat d'un tour. Une erreur ne remet jamais le compteur a zero :
/// c'est exactement la frustration qu'on cherche a supprimer.
enum RoundOutcome { pending, clean, shaky, skipped }

/// Etat d'une session de travail en boucle.
///
/// Regles de conception, toutes issues du meme constat (la repetition
/// fatigue) :
///  - l'objectif est fini et visible des le premier tour ;
///  - on avance toujours, meme apres une erreur ;
///  - le tempo monte tout seul quand c'est propre, pour rendre le progres
///    visible sans que l'enfant ait a en decider.
class PracticeSession {
  PracticeSession({
    required this.passage,
    required this.variations,
    required this.startTempoBpm,
    this.tempoStepBpm = 4,
    this.maxTempoBpm = 200,
  })  : assert(variations.isNotEmpty, 'une session a au moins un tour'),
        _outcomes = List<RoundOutcome>.filled(
          variations.length,
          RoundOutcome.pending,
        );

  factory PracticeSession.forPassage(
    Passage passage, {
    int rounds = 10,
    int? startTempoBpm,
    int? seed,
  }) {
    return PracticeSession(
      passage: passage,
      variations: const VariationGenerator()
          .buildSession(passage, rounds: rounds, seed: seed),
      startTempoBpm: startTempoBpm ?? (passage.writtenTempoBpm * 0.75).round(),
    );
  }

  final Passage passage;
  final List<Variation> variations;
  final int startTempoBpm;
  final int tempoStepBpm;
  final int maxTempoBpm;

  final List<RoundOutcome> _outcomes;

  int _currentRound = 0;
  int _workingTempoBpm = -1;

  List<RoundOutcome> get outcomes => List<RoundOutcome>.unmodifiable(_outcomes);
  int get totalRounds => variations.length;

  /// Base 1, pour l'affichage "Tour 4 / 10".
  ///
  /// Plafonne a [totalRounds] : une fois la session finie `_currentRound` vaut
  /// deja `variations.length`, et un compteur nu annoncerait "Tour 11 / 10".
  /// Un objectif fini qui se termine au-dela de sa propre borne, c'est
  /// exactement ce que le projet cherche a eviter.
  int get currentRoundNumber => isFinished ? totalRounds : _currentRound + 1;

  bool get isFinished => _currentRound >= variations.length;

  Variation get currentVariation =>
      isFinished ? variations.last : variations[_currentRound];

  int get workingTempoBpm =>
      _workingTempoBpm < 0 ? startTempoBpm : _workingTempoBpm;

  /// Tempo effectif du tour courant, variation appliquee.
  int get currentTempoBpm {
    if (currentVariation.id == VariationGenerator.asWritten.id) {
      return passage.writtenTempoBpm;
    }
    return (workingTempoBpm * currentVariation.tempoFactor)
        .round()
        .clamp(20, maxTempoBpm);
  }

  int get cleanRounds =>
      _outcomes.where((RoundOutcome o) => o == RoundOutcome.clean).length;

  /// Ce qu'on affiche a l'enfant : un decompte vers l'avant, jamais le
  /// nombre d'echecs.
  int get roundsRemaining =>
      (totalRounds - _currentRound).clamp(0, totalRounds);

  /// Enregistre le resultat du tour courant et passe au suivant.
  void completeRound(RoundOutcome outcome) {
    if (isFinished) {
      return;
    }
    if (outcome == RoundOutcome.pending) {
      throw ArgumentError('un tour termine ne peut pas rester "pending"');
    }
    _outcomes[_currentRound] = outcome;

    if (outcome == RoundOutcome.clean) {
      _workingTempoBpm =
          (workingTempoBpm + tempoStepBpm).clamp(20, maxTempoBpm);
    }
    _currentRound++;
  }

  /// "Celle-la je n'aime pas" : le tour est consomme sans penalite et sans
  /// montee de tempo.
  void skipVariation() => completeRound(RoundOutcome.skipped);
}
