import 'dart:math' as math;

import '../follow/offline_aligner.dart';
import '../music/passage.dart';
import '../music/score_note.dart';

/// Une note jouee, telle que l'aligneur l'a reconnue dans la prise.
class PlayedEvent {
  const PlayedEvent({
    required this.noteIndex,
    required this.startMs,
    required this.endMs,
  });

  final int noteIndex;
  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;
}

/// Ce que le juge dit d'un enchainement : une note, et le temps jusqu'a la
/// suivante.
class RhythmVerdict {
  const RhythmVerdict({
    required this.noteIndex,
    required this.startMs,
    required this.ratio,
    required this.hesitation,
  });

  final int noteIndex;
  final int startMs;

  /// Duree jouee rapportee a la duree ecrite **au tempo tenu**. 1 : en place ;
  /// 0,5 : une noire jouee comme une croche ; 2 : comme une blanche.
  final double ratio;

  /// Un arret avant la note suivante : ni une faute de rythme, ni un tempo
  /// (ADR-010). Compte a part.
  final bool hesitation;

  /// Note de rythme sur cent, ou `null` pour une hesitation.
  int? get score => hesitation ? null : RhythmJudge.scoreForRatio(ratio);
}

/// Le juge de rythme (lots N2, N3, N4) : **strict, parce qu'il ne suit rien**
/// (ADR-010).
///
/// Il reprend les attaques que l'aligneur a reconnues sur la prise entiere,
/// en deduit **le tempo reellement tenu**, et mesure chaque note **a ce
/// tempo-la**. C'est ce qui separe, comme un professeur a l'oreille :
///
/// | Ce qui est joue | Verdict |
/// |---|---|
/// | Tout a 74 au lieu de 92, rythme impeccable | Tempo tenu : 74. Pas une faute |
/// | Une noire jouee comme une croche | Faute de rythme sur cette note |
/// | Deux secondes d'arret avant le do# | Une hesitation, comptee a part |
///
/// **Ne se juge que ce qui s'enchaine.** Une reprise, un saut ou un arret de
/// travail coupent la prise en morceaux ; le rythme se mesure a l'interieur
/// de chacun, jamais par-dessus une coupure.
class RhythmJudge {
  RhythmJudge._(this.passage, this.events, this.verdicts, this.quarterBpm);

  final Passage passage;

  /// Les notes jouees, dans l'ordre du jeu.
  final List<PlayedEvent> events;

  /// Un verdict par enchainement.
  final List<RhythmVerdict> verdicts;

  /// Le tempo tenu, a la noire, ou `null` si trop peu s'est enchaine.
  final double? quarterBpm;

  /// Un silence plus long coupe la prise : c'est un arret de travail.
  static const int stopMs = 1000;

  /// Au-dela, l'attente avant la note suivante est une hesitation : deux fois
  /// la duree ecrite, et au moins une demi-seconde de trop.
  static const double hesitationRatio = 2;
  static const int hesitationExtraMs = 500;

  /// En dessous de cet ecart, une note est en place : 15 %, ce qu'un rubato
  /// d'eleve, un changement d'archet ou de position laissent passer.
  static const double toleranceRatio = 1.15;

  /// A cet ecart, une noire est devenue une croche ou une blanche : zero.
  static const double faultRatio = 2;

  /// Moins d'enchainements que ca, et le tempo n'est pas dit.
  static const int minIntervals = 3;

  /// Juge la prise que [alignment] decrit.
  static RhythmJudge judge(Passage passage, Alignment alignment) {
    final Map<String, int> index = <String, int>{
      for (int i = 0; i < passage.notes.length; i++) passage.notes[i].id: i,
    };
    final List<PlayedEvent> events = <PlayedEvent>[
      for (final AlignedNote a in alignment.notes)
        PlayedEvent(
          noteIndex: index[a.noteId]!,
          startMs: a.startMs,
          endMs: a.endMs,
        ),
    ];
    return fromEvents(passage, events);
  }

  /// Le meme jugement, a partir des notes jouees directement.
  static RhythmJudge fromEvents(Passage passage, List<PlayedEvent> events) {
    // Les enchainements : note puis note suivante sur le papier, sans arret.
    final List<(PlayedEvent, PlayedEvent)> paires =
        <(PlayedEvent, PlayedEvent)>[
      for (int k = 0; k + 1 < events.length; k++)
        if (events[k + 1].noteIndex == events[k].noteIndex + 1 &&
            events[k + 1].startMs - events[k].endMs < stopMs)
          (events[k], events[k + 1]),
    ];

    double msParNoire(PlayedEvent a, PlayedEvent b) {
      final int ticks = passage.notes[b.noteIndex].onsetTicks -
          passage.notes[a.noteIndex].onsetTicks;
      return (b.startMs - a.startMs) * passage.ticksPerBeat / ticks;
    }

    // Le tempo tenu : la mediane, puis la mediane de ce qui n'est pas une
    // hesitation au regard de la premiere. Une seule passe laisserait trois
    // hesitations sur dix tirer le tempo vers le bas.
    double? noire;
    if (paires.length >= minIntervals) {
      final List<double> tous = <double>[
        for (final (PlayedEvent a, PlayedEvent b) in paires) msParNoire(a, b),
      ]..sort();
      final double premiere = tous[tous.length ~/ 2];
      final List<double> retenus = <double>[
        for (final double v in tous)
          if (v < premiere * hesitationRatio && v > premiere / hesitationRatio)
            v,
      ];
      final List<double> base = retenus.isEmpty ? tous : retenus;
      noire = base[base.length ~/ 2];
    }

    final List<RhythmVerdict> verdicts = <RhythmVerdict>[];
    if (noire != null) {
      for (final (PlayedEvent a, PlayedEvent b) in paires) {
        final int ticks = passage.notes[b.noteIndex].onsetTicks -
            passage.notes[a.noteIndex].onsetTicks;
        final double attendu = ticks * noire / passage.ticksPerBeat;
        final double joue = (b.startMs - a.startMs).toDouble();
        verdicts.add(
          RhythmVerdict(
            noteIndex: a.noteIndex,
            startMs: a.startMs,
            ratio: joue / attendu,
            hesitation: joue >= attendu * hesitationRatio &&
                joue - attendu >= hesitationExtraMs,
          ),
        );
      }
    }
    return RhythmJudge._(
      passage,
      events,
      verdicts,
      noire == null ? null : 60000 / noire,
    );
  }

  /// La note de rythme d'un ecart, sur cent.
  static int scoreForRatio(double ratio) {
    final double ecart = math.log(ratio).abs();
    final double tolere = math.log(toleranceRatio);
    final double faute = math.log(faultRatio);
    if (ecart <= tolere) {
      return 100;
    }
    if (ecart >= faute) {
      return 0;
    }
    return (100 * (faute - ecart) / (faute - tolere)).round();
  }

  /// Le tempo tenu, dans l'unite ou se bat le morceau (noire pointee en 6/8).
  int? get pulseBpm {
    final double? q = quarterBpm;
    if (q == null) {
      return null;
    }
    final int pulsation =
        passage.meter?.beatTicks(passage.ticksPerBeat) ?? passage.ticksPerBeat;
    return (q * passage.ticksPerBeat / pulsation).round();
  }

  /// Le tempo tenu rapporte au tempo ecrit : 0,8 joue a 80 % du papier.
  ///
  /// **Une information, pas une faute** : jouer plus lentement que le papier
  /// est un choix de travail.
  double? get tempoRatio {
    final double? q = quarterBpm;
    return q == null ? null : q / passage.writtenTempoBpm;
  }

  /// La note de rythme d'une note, sur cent, moyenne de ses passages ; `null`
  /// si elle n'a jamais ete jugee.
  int? scoreFor(int noteIndex) {
    final List<int> s = <int>[
      for (final RhythmVerdict v in verdicts)
        if (v.noteIndex == noteIndex && v.score != null) v.score!,
    ];
    return s.isEmpty
        ? null
        : (s.reduce((int a, int b) => a + b) / s.length).round();
  }

  /// La note de rythme du passage, moyenne des enchainements juges.
  int? get overallScore {
    final List<int> s = <int>[
      for (final RhythmVerdict v in verdicts)
        if (v.score != null) v.score!,
    ];
    return s.isEmpty
        ? null
        : (s.reduce((int a, int b) => a + b) / s.length).round();
  }

  /// Les hesitations, dans l'ordre : la note **avant** laquelle il s'est
  /// arrete, c'est-a-dire celle qu'il n'osait pas attaquer.
  List<ScoreNote> get hesitations => <ScoreNote>[
        for (final RhythmVerdict v in verdicts)
          if (v.hesitation) passage.notes[v.noteIndex + 1],
      ];
}
