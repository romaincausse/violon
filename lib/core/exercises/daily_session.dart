import '../music/meter.dart';
import '../music/passage.dart';
import '../score/staff_layout.dart';
import '../store/homework.dart';
import '../store/take_history.dart';
import 'exercise.dart';
import 'exercise_catalog.dart';

/// Les trois etapes d'une seance (lot V1).
enum SessionStep {
  /// Une gamme dans la tonalite du morceau, trois minutes au plus.
  warmup,

  /// Les mesures designees, en boucle.
  work,

  /// Le morceau entier, avec l'accompagnement : on finit en musique.
  music,
}

/// Des mesures a travailler, et pourquoi elles.
class WorkChoice {
  const WorkChoice({
    required this.from,
    required this.to,
    required this.why,
  });

  final int from;
  final int to;

  /// "Le devoir de la semaine", "la mesure qui a coince hier"...
  final String why;

  @override
  bool operator ==(Object other) =>
      other is WorkChoice &&
      other.from == from &&
      other.to == to &&
      other.why == why;

  @override
  int get hashCode => Object.hash(from, to, why);
}

/// Ce que la seance propose : l'echauffement, et une ou deux options de
/// travail. **L'application propose, il dispose** (R5) : c'est l'enfant qui
/// choisit laquelle, et dans quel ordre il echauffe et travaille.
class DailySessionPlan {
  const DailySessionPlan({required this.warmup, required this.choices});

  final ScaleExercise warmup;

  /// Une ou deux, la premiere recommandee.
  final List<WorkChoice> choices;
}

/// Construit le plan d'une seance a partir de ce que l'application sait.
class DailySessionPlanner {
  const DailySessionPlanner._();

  /// La gamme la plus proche de la tonalite de [passage], les mesures a
  /// travailler d'apres le devoir ou la derniere prise.
  static DailySessionPlan plan({
    required Passage passage,
    required String workKey,
    required TakeHistory history,
    required HomeworkList homework,
    List<Exercise>? catalog,
  }) {
    final List<Exercise> exos = catalog ?? ExerciseCatalog.all;
    return DailySessionPlan(
      warmup: _gammePour(passage, exos),
      choices: _choix(passage, workKey, history, homework),
    );
  }

  /// Une gamme (pas un arpege), dans la tonalite ou la plus proche sur le
  /// cycle des quintes, au palier le plus bas : on s'echauffe, on ne se
  /// depasse pas.
  static ScaleExercise _gammePour(Passage passage, List<Exercise> exos) {
    final List<ScaleExercise> gammes = <ScaleExercise>[
      for (final Exercise e in exos)
        if (e is ScaleExercise && e.id.startsWith('gamme-')) e,
    ];
    final int? tonalite = passage.keyFifths;
    ScaleExercise? meilleure;
    int ecart = 1 << 30;
    for (final ScaleExercise g in gammes) {
      final int d = tonalite == null
          ? g.palier
          : (g.keyFifths - tonalite).abs() * 10 + g.palier;
      if (d < ecart) {
        ecart = d;
        meilleure = g;
      }
    }
    return meilleure ?? (exos.whereType<ScaleExercise>().first);
  }

  static List<WorkChoice> _choix(
    Passage passage,
    String workKey,
    TakeHistory history,
    HomeworkList homework,
  ) {
    final List<Bar> mesures = StaffLayout.barsOf(passage);
    final int premiere = mesures.first.number;
    final int derniere = mesures.last.number;
    final List<WorkChoice> choix = <WorkChoice>[];

    // Le devoir d'abord : c'est ce que le professeur a demande.
    for (final Homework d in homework.items) {
      final int? de = d.fromMeasure;
      final int? a = d.toMeasure;
      if (d.workKey == workKey && de != null && a != null) {
        choix.add(WorkChoice(from: de, to: a, why: 'Le devoir de la semaine'));
        break;
      }
    }
    // Puis ce qui a coince a la derniere prise : la mesure la plus dure, et
    // sa voisine si elle est fragile aussi (R1).
    final List<TakeRecord> prises = history.forKey(workKey);
    if (prises.isNotEmpty) {
      final List<MeasureTrace> traces = <MeasureTrace>[...prises.last.measures]
        ..sort((MeasureTrace a, MeasureTrace b) =>
            b.difficulty.compareTo(a.difficulty));
      for (final MeasureTrace t in traces) {
        if (t.difficulty <= 0) {
          break;
        }
        final bool voisineFragile = traces.any((MeasureTrace v) =>
            v.measure == t.measure + 1 && v.difficulty >= t.difficulty ~/ 2);
        final WorkChoice c = WorkChoice(
          from: t.measure,
          to: voisineFragile ? t.measure + 1 : t.measure,
          why: 'La mesure qui a coince la derniere fois',
        );
        if (!choix.any((WorkChoice x) => x.from == c.from && x.to == c.to)) {
          choix.add(c);
        }
        if (choix.length == 2) {
          break;
        }
      }
    }
    if (choix.isEmpty) {
      choix.add(WorkChoice(
        from: premiere,
        to: derniere,
        why: 'Le passage entier, pour commencer',
      ));
    }
    return List<WorkChoice>.unmodifiable(choix.take(2));
  }
}

/// La seance du jour en train de se faire : trois etapes, dans l'ordre
/// choisi, et ce qui reste toujours visible.
///
/// **On finit toujours par la musique**, c'est le point du lot : l'ordre des
/// deux premieres etapes se choisit, la troisieme non.
class DailySession {
  DailySession({
    required this.plan,
    required this.startedAt,
    required this.chosen,
    bool workFirst = false,
  }) : order = List<SessionStep>.unmodifiable(workFirst
            ? const <SessionStep>[
                SessionStep.work,
                SessionStep.warmup,
                SessionStep.music,
              ]
            : const <SessionStep>[
                SessionStep.warmup,
                SessionStep.work,
                SessionStep.music,
              ]);

  final DailySessionPlan plan;
  final DateTime startedAt;
  final List<SessionStep> order;
  final WorkChoice chosen;

  /// L'echauffement s'arrete la, meme si la gamme n'est pas allee au bout :
  /// une seance de vingt minutes ne commence pas par dix minutes de gamme.
  static const Duration warmupBudget = Duration(minutes: 3);

  /// Le travail aussi a une fin : six essais, puis on termine sur une
  /// reussite (R4) et on passe a la musique.
  static const int workAttempts = 6;

  final Set<SessionStep> _faites = <SessionStep>{};

  Set<SessionStep> get done => Set<SessionStep>.unmodifiable(_faites);

  bool get finished => _faites.length == order.length;

  /// L'etape en cours, `null` quand tout est fait.
  SessionStep? get current {
    for (final SessionStep s in order) {
      if (!_faites.contains(s)) {
        return s;
      }
    }
    return null;
  }

  /// Ce qui reste apres l'etape en cours, dans l'ordre.
  List<SessionStep> get remaining => <SessionStep>[
        for (final SessionStep s in order)
          if (!_faites.contains(s) && s != current) s,
      ];

  /// Une etape faite ne se refait pas, et en marquer une qui n'est pas en
  /// cours est permis : il a pu lancer la boucle de lui-meme.
  void complete(SessionStep step) => _faites.add(step);

  int get stepNumber => _faites.length + 1;
}

/// Le nom d'une etape, pour l'ecran.
String stepLabel(SessionStep s) => switch (s) {
      SessionStep.warmup => 'Echauffement',
      SessionStep.work => 'Travail',
      SessionStep.music => 'Musique',
    };
