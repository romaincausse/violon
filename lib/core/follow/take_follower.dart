import '../audio/pitch_smoother.dart';
import '../music/passage.dart';
import '../music/pitch_utils.dart';
import '../music/score_note.dart';
import '../scoring/live_tuning.dart';
import '../scoring/rhythm_judge.dart';
import '../scoring/take_report.dart';
import 'offline_aligner.dart';
import 'online_follower.dart';
import 'performance_features.dart';
import 'tempo_tracker.dart';

/// Une hauteur entendue, rattachee a la note que l'eleve jouait.
class HeardPitch {
  const HeardPitch({required this.note, required this.pitch});

  final ScoreNote note;
  final SmoothedPitch pitch;
}

/// Une prise suivie, du premier son a l'archet pose (lot S4).
///
/// **Toute la mecanique du suivi, sans un widget.** L'ecran de seance branche
/// les deux flux du micro ici et lit ce qui en sort : ou en est l'eleve, quelle
/// note colorer, quand la prise est finie, et la note finale.
///
/// **Deux temps, deux lecteurs** (journal, octobre 2026) :
///
/// - **pendant la prise**, le suiveur en direct ([OnlineFollower]) dit ou en
///   est l'eleve, et chaque hauteur est rattachee a la note qu'il joue -- pas
///   a celle qu'une horloge attendrait (ADR-009) ;
/// - **une fois l'archet pose**, [rescore] reprend toute la prise avec
///   l'aligneur hors ligne, qui voit la suite et corrige ce que le direct a
///   rattache de travers dans un passage repete. C'est cette note-la qui
///   compte.
///
/// **Les deux flux n'arrivent pas au meme rythme.** Les hauteurs sortent de
/// YIN avant que le suiveur ait tranche la position de leur instant (il
/// retarde de deux trames). Une hauteur attend donc que le suiveur ait depasse
/// son horodatage pour etre rattachee : la rattacher a la position courante la
/// donnerait parfois a la note precedente.
class TakeFollower {
  TakeFollower(
    this.passage, {
    this.a4 = PitchUtils.defaultA4,
    this.slurredInto = const <String>{},
    this.featureA4 = PitchUtils.defaultA4,
    this.endSilenceMs = defaultEndSilenceMs,
  })  : _suiveur = OnlineFollower(passage, slurredInto: slurredInto),
        tempo = TempoTracker(passage),
        tuning = LiveTuning(a4: a4);

  /// Le tempo qu'il tient, deduit de ses attaques (lot D3).
  final TempoTracker tempo;

  /// Instant de la derniere trame recue : l'horloge de la prise.
  int lastFrameMs = 0;

  final Passage passage;

  /// Le la mesure de l'instrument : la justesse se juge contre lui.
  final double a4;

  final Set<String> slurredInto;

  /// Le la auquel le flux de trames rapporte ses hauteurs (440 en direct).
  final double featureA4;

  /// Combien de silence apres la derniere note termine la prise.
  final int endSilenceMs;

  static const int defaultEndSilenceMs = 1500;

  final OnlineFollower _suiveur;

  /// La justesse en direct, note par note. Remplacee par [rescore].
  LiveTuning tuning;

  final List<FeatureFrame> _trames = <FeatureFrame>[];
  final List<SmoothedPitch> _hauteurs = <SmoothedPitch>[];
  final List<SmoothedPitch> _enAttente = <SmoothedPitch>[];

  /// Derniere position rendue par le suiveur, ou `null` au tout debut.
  FollowPosition? position;

  /// Instant ou la note en cours a commence, pour ecarter son attaque.
  int? _debutDeLaNote;

  int? _derniereNote;

  /// La confiance du suiveur, lissee sur une dizaine de trames (lot S5).
  ///
  /// Lissee parce qu'une trame isolee hesite toujours un peu, au passage
  /// d'une attaque : un curseur qui palirait a chaque coup d'archet ne dirait
  /// plus rien.
  double confidence = 1;

  /// En dessous, le suiveur dit qu'il cherche. Regle sur les prises du banc :
  /// au-dessus, le direct est d'accord avec l'aligneur 88 % du temps ; en
  /// dessous, une fois sur deux.
  static const double unsureBelow = 0.4;

  /// Il ne sait plus ou en est l'eleve.
  ///
  /// **Il le dit, plutot que de noter au hasard** : tant qu'il doute, rien
  /// n'est rattache en direct. Les hauteurs ne sont pas perdues -- [rescore]
  /// les reprend toutes, avec l'aligneur qui voit la suite.
  bool get unsure => started && confidence < unsureBelow;

  /// Vrai des que la derniere note du passage a ete jouee.
  bool reachedEnd = false;

  /// Le suiveur a-t-il entendu quelque chose qui ressemble au passage ?
  bool get started => position?.started ?? false;

  /// La note que l'eleve joue en ce moment, ou `null` s'il ne joue pas.
  ScoreNote? get currentNote {
    final FollowPosition? p = position;
    return p == null || !p.playing ? null : passage.notes[p.noteIndex!];
  }

  /// La mesure ou il en est, qu'il joue ou qu'il se soit arrete.
  int? get currentMeasure {
    final int? i = position?.noteIndex;
    return i == null ? null : passage.notes[i].measure;
  }

  /// La derniere note jouee, apres un silence, ne bouge plus : la prise est
  /// finie. **Seulement au bout du passage** -- un arret au milieu est un
  /// arret de travail, pas une fin (ADR-009).
  bool get finished {
    final FollowPosition? p = position;
    if (!reachedEnd || p == null || !p.resting) {
      return false;
    }
    if (p.noteIndex != passage.notes.length - 1) {
      return false;
    }
    final int? silence = _debutDuSilence;
    return silence != null && p.timeMs - silence >= endSilenceMs;
  }

  int? _debutDuSilence;

  /// Depuis combien de temps il ne joue plus, ou zero s'il joue.
  int get restingForMs {
    final int? debut = _debutDuSilence;
    return debut == null || position == null ? 0 : position!.timeMs - debut;
  }

  /// Ajoute une trame du flux du suiveur. Rend les hauteurs qu'elle a permis
  /// de rattacher, dans l'ordre.
  List<HeardPitch> addFrame(FeatureFrame brute) {
    final FeatureFrame trame = brute.retuned(fromA4: featureA4, toA4: a4);
    _trames.add(trame);
    lastFrameMs = trame.timeMs;
    final FollowPosition? p = _suiveur.add(trame);
    if (p == null) {
      return const <HeardPitch>[];
    }
    position = p;
    confidence = 0.8 * confidence + 0.2 * p.confidence;
    if (p.playing) {
      _debutDuSilence = null;
      if (p.noteIndex != _derniereNote) {
        _derniereNote = p.noteIndex;
        _debutDeLaNote = p.timeMs;
        // Le tempo ne se lit que sur ce dont le suiveur est sur.
        if (!unsure) {
          tempo.noteStarted(p.noteIndex!, p.timeMs);
        }
      }
      if (p.noteIndex == passage.notes.length - 1) {
        reachedEnd = true;
      }
    } else {
      _debutDuSilence ??= p.timeMs;
      if (_derniereNote != null) {
        tempo.stopped();
      }
      _derniereNote = null;
    }
    return _rattacher(p);
  }

  /// Ajoute une hauteur entendue. Elle sera rattachee quand le suiveur aura
  /// tranche la position de son instant.
  List<HeardPitch> addPitch(SmoothedPitch pitch) {
    _hauteurs.add(pitch);
    _enAttente.add(pitch);
    final FollowPosition? p = position;
    return p == null ? const <HeardPitch>[] : _rattacher(p);
  }

  /// Une trame dure 23 ms : une hauteur jusqu'a cet instant-la est couverte
  /// par la position rendue.
  static const int _pas = 23;

  List<HeardPitch> _rattacher(FollowPosition p) {
    final List<HeardPitch> sortie = <HeardPitch>[];
    while (_enAttente.isNotEmpty &&
        _enAttente.first.estimate.timestampMs <= p.timeMs + _pas) {
      final SmoothedPitch h = _enAttente.removeAt(0);
      final ScoreNote? note = currentNote;
      if (note == null || unsure) {
        continue;
      }
      final int? debut = _debutDeLaNote;
      tuning.observe(
        note,
        h.estimate,
        sinceNoteStartMs: debut == null ? null : h.estimate.timestampMs - debut,
      );
      sortie.add(HeardPitch(note: note, pitch: h));
    }
    return sortie;
  }

  /// Le juge de rythme de la prise entiere, une fois [rescore] passe.
  RhythmJudge? rhythm;

  /// Le diagnostic mesure par mesure, une fois [rescore] passe (N5).
  TakeReport? get report {
    final RhythmJudge? r = rhythm;
    return r == null ? null : TakeReport.of(passage, r, tuning);
  }

  /// Reprend toute la prise avec l'aligneur hors ligne, et rend la justesse
  /// qui compte (ADR-010).
  ///
  /// L'aligneur voit la suite : la ou le direct a rattache une hauteur a la
  /// mesure 19 avant de comprendre qu'on etait revenu a la 15, il la rend a
  /// la 15. Les couleurs de fin de prise sont celles-la.
  LiveTuning rescore() {
    final LiveTuning juste = LiveTuning(a4: a4);
    if (_trames.isEmpty) {
      tuning = juste;
      return juste;
    }
    final Alignment a =
        OfflineAligner(passage, slurredInto: slurredInto).align(_trames);
    // Le meme alignement juge le rythme : un seul alignement, deux lectures
    // (ADR-010).
    rhythm = RhythmJudge.judge(passage, a);
    final Map<String, ScoreNote> parId = <String, ScoreNote>{
      for (final ScoreNote n in passage.notes) n.id: n,
    };
    // Le debut de chaque note jouee, trame par trame.
    final List<int?> debuts = List<int?>.filled(a.frameNotes.length, null);
    for (int t = 0; t < a.frameNotes.length; t++) {
      final String? id = a.frameNotes[t];
      if (id == null) {
        continue;
      }
      debuts[t] = t > 0 && a.frameNotes[t - 1] == id
          ? debuts[t - 1]
          : a.frameTimesMs[t];
    }
    int t = 0;
    for (final SmoothedPitch h in _hauteurs) {
      final int ms = h.estimate.timestampMs;
      while (t + 1 < a.frameTimesMs.length && a.frameTimesMs[t + 1] <= ms) {
        t++;
      }
      final String? id = a.frameNotes[t];
      if (id == null) {
        continue;
      }
      juste.observe(
        parId[id]!,
        h.estimate,
        sinceNoteStartMs: ms - debuts[t]!,
      );
    }
    tuning = juste;
    return juste;
  }
}
