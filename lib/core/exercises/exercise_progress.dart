import 'exercise.dart';
import 'exercise_catalog.dart';

/// Ce qui a ete joue sur un exercice, une fois.
class ExerciseAttempt {
  const ExerciseAttempt({
    required this.exerciseId,
    required this.score,
    required this.tempoBpm,
    this.coverage = 1,
  })  : assert(score >= 0 && score <= 100, 'un score va de 0 a 100'),
        assert(tempoBpm > 0, 'un tempo est strictement positif'),
        assert(coverage >= 0 && coverage <= 1, 'une part va de 0 a 1');

  final String exerciseId;

  /// Score de justesse du passage, de 0 a 100.
  final int score;

  /// Tempo auquel l'exercice a ete joue.
  final int tempoBpm;

  /// Part des notes de l'exercice reellement entendues, entre 0 et 1.
  ///
  /// **Sans ce chiffre, le score seul serait trompeur.** La note d'ensemble
  /// ne compte que les notes entendues, parce que compter un silence pour zero
  /// punirait un archet rate ou un micro trop loin. Mais quatre notes justes
  /// sur vingt-neuf donneraient alors cent, et l'exercice serait declare
  /// acquis : l'application ne le proposerait plus jamais, sur la foi de quatre
  /// notes.
  final double coverage;
}

/// Le meilleur de ce qui a ete joue sur un exercice.
///
/// **Rien ici ne peut baisser.** C'est la regle produit la plus ancienne du
/// projet : une erreur ne remet jamais un compteur a zero. Une mauvaise prise
/// n'efface donc pas une bonne, elle ajoute juste un essai.
class ExerciseBest {
  const ExerciseBest({
    required this.exerciseId,
    required this.meilleurScore,
    required this.meilleurTempoPropre,
    required this.essais,
  });

  final String exerciseId;

  /// Meilleur score obtenu, a n'importe quel tempo. C'est la donnee qui monte.
  final int meilleurScore;

  /// Tempo le plus rapide **tenu proprement**, ou zero si rien ne l'a ete.
  ///
  /// **Les deux ne se combinent pas, et c'est tout l'interet de garder ce
  /// chiffre a part.** Retenir separement le meilleur score et le meilleur
  /// tempo laisserait un score de 95 obtenu a 50 et un tempo de 80 tenu a 40
  /// s'additionner en un exercice declare acquis a 80 -- qui n'a jamais ete
  /// joue proprement a 80.
  final int meilleurTempoPropre;

  final int essais;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': exerciseId,
        'score': meilleurScore,
        'tempo': meilleurTempoPropre,
        'essais': essais,
      };

  /// Relit ce qui a ete range, en se mefiant de ce qu'on relit.
  ///
  /// Une valeur absente ou d'un autre type rend `null` plutot que de lever :
  /// un enregistrement abime ne doit pas empecher l'application de s'ouvrir.
  /// On perd un record, pas une seance.
  static ExerciseBest? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? id = json['id'];
    final Object? score = json['score'];
    final Object? tempo = json['tempo'];
    final Object? essais = json['essais'];
    if (id is! String || score is! int || tempo is! int || essais is! int) {
      return null;
    }
    if (score < 0 || score > 100 || tempo < 0 || essais < 0) {
      return null;
    }
    return ExerciseBest(
      exerciseId: id,
      meilleurScore: score,
      meilleurTempoPropre: tempo,
      essais: essais,
    );
  }
}

/// Ou en est l'eleve dans le catalogue.
///
/// **Un palier s'ouvre quand le precedent est propre au tempo vise.** La
/// progression ne s'invente pas ici : elle lit l'ordre du catalogue, qui est
/// celui des methodes.
///
/// **La progression guide, elle ne verrouille pas** (ADR-011). Un palier non
/// ouvert se voit, se comprend, et reste jouable : c'est un conseil, pas une
/// porte fermee. Le professeur donne ce qu'il veut, quand il veut.
///
/// **Rien n'est encore persiste** (lot H1) : la progression vit le temps d'une
/// session. Mieux vaut un compteur honnetement volatile qu'un historique
/// sauvegarde a moitie.
class ExerciseProgress {
  ExerciseProgress({
    this.catalogue = ExerciseCatalog.all,
    this.scorePropre = 90,
  }) : assert(scorePropre > 0 && scorePropre <= 100, 'un seuil va de 1 a 100');

  final List<Exercise> catalogue;

  /// A partir de quel score une prise est dite propre.
  ///
  /// Quatre-vingt-dix, comme le halo de fin de mesure : cent demanderait
  /// chaque note dans la bande parfaite et n'arriverait presque jamais.
  final int scorePropre;

  /// Part de l'exercice qu'il faut avoir entendue pour qu'une prise compte.
  ///
  /// Trois quarts, pas la totalite : une note avalee, un changement de corde
  /// qui ne sonne pas ou un archet leve arrivent a toutes les prises, y compris
  /// aux bonnes. En dessous, en revanche, on ne sait pas ce qui a ete joue --
  /// la prise est comptee comme essai, mais elle ne rend rien acquis.
  static const double couvertureMinimale = 0.75;

  final Map<String, ExerciseBest> _meilleurs = <String, ExerciseBest>{};

  /// Enregistre une prise. Ne garde que ce qui ameliore.
  void record(ExerciseAttempt attempt) {
    final ExerciseBest? avant = _meilleurs[attempt.exerciseId];
    final bool propre =
        attempt.score >= scorePropre && attempt.coverage >= couvertureMinimale;
    _meilleurs[attempt.exerciseId] = ExerciseBest(
      exerciseId: attempt.exerciseId,
      meilleurScore: avant == null
          ? attempt.score
          : (attempt.score > avant.meilleurScore
              ? attempt.score
              : avant.meilleurScore),
      meilleurTempoPropre: propre
          ? (avant == null || attempt.tempoBpm > avant.meilleurTempoPropre
              ? attempt.tempoBpm
              : avant.meilleurTempoPropre)
          : (avant?.meilleurTempoPropre ?? 0),
      essais: (avant?.essais ?? 0) + 1,
    );
  }

  ExerciseBest? bestFor(String exerciseId) => _meilleurs[exerciseId];

  /// Tout ce qui a ete retenu, pour le ranger.
  Map<String, ExerciseBest> get bests =>
      Map<String, ExerciseBest>.unmodifiable(_meilleurs);

  /// Repart de ce qui avait ete range.
  ///
  /// Les records d'exercices disparus du catalogue sont ignores : le catalogue
  /// peut changer entre deux versions, la memoire ne doit pas ressusciter un
  /// exercice qui n'existe plus.
  void restore(Iterable<ExerciseBest> bests) {
    _meilleurs.clear();
    final Set<String> connus = catalogue.map((Exercise e) => e.id).toSet();
    for (final ExerciseBest best in bests) {
      if (connus.contains(best.exerciseId)) {
        _meilleurs[best.exerciseId] = best;
      }
    }
  }

  /// Nombre de prises enregistrees, tous exercices confondus.
  int get essais => _meilleurs.values
      .fold(0, (int total, ExerciseBest b) => total + b.essais);

  /// Vrai si l'exercice a ete tenu proprement au tempo vise.
  bool estAcquis(Exercise exercise) {
    final ExerciseBest? best = _meilleurs[exercise.id];
    return best != null && best.meilleurTempoPropre >= exercise.tempoVise;
  }

  int get acquis => catalogue.where(estAcquis).length;

  /// Le plus haut palier ouvert.
  ///
  /// Les paliers s'ouvrent dans l'ordre : le premier l'est toujours, et chaque
  /// suivant l'est des que le precedent est entierement acquis. Comme rien ne
  /// peut baisser, ce numero ne peut que monter.
  int get palierOuvert {
    int ouvert = 1;
    for (final Palier palier in ExerciseCatalog.paliers) {
      final List<Exercise> duPalier = catalogue
          .where((Exercise e) => e.palier == palier.numero)
          .toList(growable: false);
      if (duPalier.isEmpty || !duPalier.every(estAcquis)) {
        return palier.numero;
      }
      ouvert = palier.numero + 1;
    }
    return ouvert;
  }

  bool palierEstOuvert(int numero) => numero <= palierOuvert;

  /// Combien d'exercices manquent pour ouvrir le palier suivant.
  int resteAuPalier(int numero) => catalogue
      .where((Exercise e) => e.palier == numero && !estAcquis(e))
      .length;

  /// De combien on monte quand un exercice est acquis.
  ///
  /// **Six battements.** Assez pour que ce soit un vrai pas -- en dessous, on
  /// ne sent pas la difference et le palier ne veut plus rien dire -- et assez
  /// peu pour que ce soit encore jouable le soir meme. C'est a peu pres le
  /// cran d'un metronome mecanique dans cette region.
  static const int pasDeTempo = 6;

  /// Le tempo a proposer pour la prochaine prise de [exercise].
  ///
  /// **Tant que l'exercice n'est pas acquis, c'est le tempo vise** : l'objectif
  /// ne bouge pas parce qu'on a rate. Une fois acquis, on propose le cran
  /// au-dessus du meilleur tempo reellement tenu -- c'est la seule facon dont
  /// une progression se voit, et elle ne redescend jamais.
  int tempoPropose(Exercise exercise) {
    final ExerciseBest? best = _meilleurs[exercise.id];
    if (best == null || best.meilleurTempoPropre < exercise.tempoVise) {
      return exercise.tempoVise;
    }
    return best.meilleurTempoPropre + pasDeTempo;
  }

  /// Le prochain exercice a travailler.
  ///
  /// **Une seule tache, pas une liste de manques.** L'application dit "voila
  /// ta prochaine tache", jamais "voila tout ce que tu n as pas fait" : c'est
  /// donc le premier exercice non acquis dans l'ordre du catalogue, borne au
  /// palier ouvert. `null` quand tout est acquis -- et ce jour-la, le
  /// catalogue a fait son travail.
  Exercise? get prochaineTache {
    final int limite = palierOuvert;
    for (final Exercise exercise in catalogue) {
      if (exercise.palier <= limite && !estAcquis(exercise)) {
        return exercise;
      }
    }
    return null;
  }
}
