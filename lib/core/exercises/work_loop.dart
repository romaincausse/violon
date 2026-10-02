import '../music/meter.dart';
import '../music/passage.dart';
import '../music/score_note.dart';
import '../scoring/take_report.dart';

/// Les mesures a retravailler, de [from] a [to] incluses.
class BarSelection {
  const BarSelection(this.from, this.to) : assert(from <= to, 'de a a');

  final int from;
  final int to;

  int get length => to - from + 1;

  bool contains(int measure) => measure >= from && measure <= to;

  @override
  bool operator ==(Object other) =>
      other is BarSelection && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => from == to ? 'mesure $from' : 'mesures $from a $to';
}

/// Un essai de la boucle, tel que la prise l'a mesure.
class LoopAttempt {
  const LoopAttempt({
    required this.reachedEnd,
    required this.tuningScore,
    required this.rhythmScore,
    required this.heldPulseBpm,
    required this.stops,
    required this.targetPulseBpm,
  });

  /// Il a joue la selection jusqu'au bout.
  final bool reachedEnd;
  final int? tuningScore;
  final int? rhythmScore;

  /// Le tempo qu'il a tenu, ou `null` si trop court pour le dire.
  final int? heldPulseBpm;

  /// Arrets de plus d'une seconde dans la selection.
  final int stops;

  /// L'objectif de cet essai.
  final int targetPulseBpm;

  /// **Reussi : d'un trait, juste, en place, a l'objectif.** Exigeant, parce
  /// qu'une reussite fait monter le tempo -- et qu'on ne monte pas sur un
  /// passage qui ne tient pas.
  bool get success =>
      reachedEnd &&
      stops == 0 &&
      (tuningScore ?? 0) >= WorkLoop.tuningToPass &&
      (rhythmScore ?? 0) >= WorkLoop.rhythmToPass &&
      heldPulseBpm != null &&
      heldPulseBpm! >= targetPulseBpm * WorkLoop.tempoTolerance;
}

/// Ce que la boucle propose de faire ensuite.
enum LoopStep {
  /// Encore une fois, au meme tempo.
  again,

  /// Ca tient deux fois de suite : un cran plus vite (R3).
  faster,

  /// Le point de rupture est trouve : on redescend consolider (C2).
  consolidate,

  /// L'objectif est atteint, au tempo ecrit : la boucle a fait son travail.
  done,
}

/// La boucle de travail (jalon 8) : la mesure designe la mesure, et le tempo
/// monte quand ca tient.
///
/// **C'est ici que survit la reponse a la lassitude.** Ce n'est plus l'enfant
/// qui decide de rejouer la meme mesure pour la dixieme fois : c'est la
/// mesure qui l'a designee (R1), et chaque essai a un but visible -- deux
/// reussites, et le tempo monte (R3).
///
/// **Le tempo est un objectif, jamais une contrainte.** En mode suivi
/// (ADR-009), l'eleve joue a son tempo ; l'objectif dit seulement ou viser,
/// et une reussite en dessous ne compte pas comme une montee.
///
/// **Une erreur ne remet jamais un compteur a zero** : un essai rate laisse
/// les reussites a leur place, il interrompt seulement la serie qui fait
/// monter.
class WorkLoop {
  WorkLoop({
    required this.selection,
    required this.startPulseBpm,
    required this.writtenPulseBpm,
    this.findBreakingPoint = false,
  }) : _objectif = startPulseBpm;

  final BarSelection selection;

  /// Le tempo de depart : celui qu'il tenait quand la boucle a commence.
  final int startPulseBpm;

  /// Le tempo du papier : la montee s'y arrete, sauf en recherche du point
  /// de rupture (C2).
  final int writtenPulseBpm;

  /// Monter jusqu'a ce que ca casse, noter le chiffre, et redescendre (C2).
  final bool findBreakingPoint;

  /// Il faut tant de reussites de suite pour monter d'un cran.
  static const int successesToClimb = 2;

  /// Un cran : six battements, comme pour les exercices (E4).
  static const int step = 6;

  static const int tuningToPass = 85;
  static const int rhythmToPass = 80;

  /// A 5 % pres, l'objectif est tenu : il ne joue pas au metronome.
  static const double tempoTolerance = 0.95;

  /// La recherche du point de rupture redescend de tant de crans.
  static const int consolidationSteps = 2;

  int _objectif;
  int _serie = 0;
  int _reussites = 0;
  int? _meilleur;
  int? _rupture;
  bool _consolide = false;
  final List<LoopAttempt> attempts = <LoopAttempt>[];

  /// L'objectif du prochain essai.
  int get targetPulseBpm => _objectif;

  /// Reussites depuis le debut : un nombre qui ne fait que monter.
  int get successes => _reussites;

  /// Reussites de suite au tempo vise : ce qui fait monter.
  int get streak => _serie;

  /// Le tempo le plus haut auquel la selection a tenu, ou `null`.
  int? get bestPulseBpm => _meilleur;

  /// Le premier tempo auquel ca a casse, en recherche de rupture (C2).
  int? get breakingPointBpm => _rupture;

  /// Note un essai et dit quoi faire ensuite.
  LoopStep record(LoopAttempt attempt) {
    attempts.add(attempt);
    if (!attempt.success) {
      _serie = 0;
      if (findBreakingPoint && _rupture == null && _reussites > 0) {
        // Ca casse ici : on le note, et on redescend la ou ca tenait bien.
        _rupture = _objectif;
        _objectif =
            (_meilleur ?? startPulseBpm) - (consolidationSteps - 1) * step;
        _consolide = true;
        return LoopStep.consolidate;
      }
      return LoopStep.again;
    }
    _reussites++;
    _serie++;
    final int tenu = attempt.heldPulseBpm!;
    if (_meilleur == null || tenu > _meilleur!) {
      _meilleur = tenu;
    }
    if (_serie < successesToClimb) {
      return LoopStep.again;
    }
    _serie = 0;
    if (_consolide) {
      return LoopStep.done;
    }
    if (!findBreakingPoint && _objectif >= writtenPulseBpm) {
      return LoopStep.done;
    }
    _objectif = findBreakingPoint
        ? _objectif + step
        : (_objectif + step).clamp(0, writtenPulseBpm);
    return LoopStep.faster;
  }

  /// Le dernier essai avant de s'arreter, s'il en faut un (R4) : **on
  /// termine toujours sur une reussite**. Si le dernier essai a rate, on
  /// propose une derniere fois au tempo ou ca tenait ; `null` si le dernier
  /// essai etait deja reussi.
  int? get finishOnSuccessPulseBpm {
    if (attempts.isEmpty || attempts.last.success) {
      return null;
    }
    return _meilleur ?? (startPulseBpm - step);
  }

  /// La selection a travailler apres une prise (R1) : la mesure que le
  /// diagnostic designe, et sa voisine si elle est fragile aussi -- un
  /// passage difficile deborde souvent d'une mesure.
  static BarSelection? weakBars(TakeReport report) {
    final MeasureReport? tache = report.nextTask;
    if (tache == null) {
      return null;
    }
    int de = tache.measure;
    int a = tache.measure;
    final MeasureReport? avant = report.byMeasure(tache.measure - 1);
    final MeasureReport? apres = report.byMeasure(tache.measure + 1);
    final bool avantFragile =
        avant != null && avant.heard && avant.difficulty > TakeReport.taskAbove;
    final bool apresFragile =
        apres != null && apres.heard && apres.difficulty > TakeReport.taskAbove;
    if (apresFragile &&
        (!avantFragile || apres.difficulty >= avant.difficulty)) {
      a = apres.measure;
    } else if (avantFragile) {
      de = avant.measure;
    }
    return BarSelection(de, a);
  }

  /// Le passage de la selection, decoupe dans [passage].
  static Passage? excerpt(Passage passage, BarSelection s) {
    final List<int> mesures = <int>[
      for (int m = s.from; m <= s.to; m++) m,
    ];
    final List<ScoreNote> notes = passage.notes
        .where((ScoreNote n) => mesures.contains(n.measure))
        .toList();
    if (notes.isEmpty) {
      return null;
    }
    return passage.withNotes(
      notes,
      alsoBars: (Bar b) => s.contains(b.number),
      title: '${passage.title} - $s',
    );
  }
}
