import '../music/passage.dart';
import '../score/staff_layout.dart';
import 'accompaniment.dart';
import 'metronome_clock.dart';

/// Une note a jouer, dans le temps depuis le depart.
class TimedNote {
  const TimedNote({
    required this.at,
    required this.duration,
    required this.midi,
    required this.velocity,
  });

  final Duration at;
  final Duration duration;
  final int midi;
  final double velocity;

  @override
  String toString() =>
      'TimedNote($midi @ ${at.inMilliseconds} ms +${duration.inMilliseconds})';
}

/// Un clic du decompte, dans le temps depuis le depart.
class TimedClick {
  const TimedClick(this.at, this.accent);

  final Duration at;
  final PulseAccent accent;
}

/// L'accompagnement d'un passage, mis dans le temps.
///
/// **Ici c'est l'application qui mene**, et c'est voulu : l'accompagnement
/// est un mode a part (ADR-008), ou l'on joue *avec* quelqu'un, a son tempo.
/// Le mode ou l'application suit l'eleve est l'autre, celui qui ecoute ; les
/// deux ne se melangent pas, faute de pouvoir ecouter pendant qu'on joue.
///
/// Pur : un tempo, un passage, des notes, et tout se calcule. Aucun minuteur,
/// aucun moteur -- c'est [AccompanimentScheduler] qui decide quand poser.
class AccompanimentPlan {
  AccompanimentPlan({
    required this.passage,
    required List<AccompanimentNote> notes,
    this.loop = false,
  })  : notes = List<AccompanimentNote>.unmodifiable(notes),
        _debut = StaffLayout.barsOf(passage).first.startTicks,
        _fin = StaffLayout.barsOf(passage).last.endTicks;

  final Passage passage;
  final List<AccompanimentNote> notes;

  /// Rejouer le passage en boucle, sans s'arreter.
  final bool loop;

  final int _debut;
  final int _fin;

  /// Premier et dernier instant du passage, en ticks.
  int get firstTick => _debut;
  int get endTick => _fin;

  /// Duree d'un tick au tempo du passage (a la noire).
  Duration get _tick => Duration(
        microseconds:
            60 * 1000000 ~/ (passage.writtenTempoBpm * passage.ticksPerBeat),
      );

  Duration _ticks(int n) => Duration(
        microseconds: n *
            60 *
            1000000 ~/
            (passage.writtenTempoBpm * passage.ticksPerBeat),
      );

  /// Une mesure de decompte, en temps battus : deux "clics" a la noire
  /// pointee en 6/8, quatre a la noire en 4/4.
  int get countInPulses => passage.pulsesPerMeasure ?? 4;

  Duration get pulse => Duration(
        microseconds: 60 * 1000000 ~/ passage.pulseBpm,
      );

  Duration get countIn => pulse * countInPulses;

  List<TimedClick> get countInClicks => <TimedClick>[
        for (int i = 0; i < countInPulses; i++)
          TimedClick(
            pulse * i,
            i == 0 ? PulseAccent.downbeat : PulseAccent.beat,
          ),
      ];

  /// Duree d'un passage entier, sans le decompte.
  Duration get length => _ticks(_fin - _debut);

  /// Les notes d'un tour, dans le temps depuis le debut du tour.
  late final List<TimedNote> _tour = <TimedNote>[
    for (final AccompanimentNote n in clipTo(notes, _debut, _fin))
      TimedNote(
        at: _ticks(n.onsetTicks - _debut),
        duration: _ticks(n.durationTicks),
        midi: n.midi,
        velocity: n.velocity,
      ),
  ]..sort((TimedNote a, TimedNote b) => a.at.compareTo(b.at));

  List<TimedNote> get oneLoop => _tour;

  /// Les notes du tour [numero] (base 0), dans le temps depuis le depart,
  /// decompte compris.
  List<TimedNote> loopNotes(int numero) {
    final Duration decalage = countIn + length * numero;
    return <TimedNote>[
      for (final TimedNote n in _tour)
        TimedNote(
          at: n.at + decalage,
          duration: n.duration,
          midi: n.midi,
          velocity: n.velocity,
        ),
    ];
  }

  /// Ou en est la partition a [elapsed] depuis le depart, en ticks ; `null`
  /// pendant le decompte et une fois le passage fini.
  int? tickAt(Duration elapsed) {
    final Duration dansLePassage = elapsed - countIn;
    if (dansLePassage.isNegative) {
      return null;
    }
    int us = dansLePassage.inMicroseconds;
    final int tour = length.inMicroseconds;
    if (us >= tour) {
      if (!loop) {
        return null;
      }
      us %= tour;
    }
    return _debut + us ~/ _tick.inMicroseconds;
  }

  /// Le passage est-il fini a [elapsed] ? Jamais, en boucle.
  bool isFinishedAt(Duration elapsed) => !loop && elapsed >= countIn + length;
}

/// Decide quelles notes poser dans le moteur, et quand.
///
/// Meme principe que `MetronomeScheduler` : **rien n'est declenche, tout est
/// planifie d'avance**, et un minuteur ne fait que remplir la file. S'il se
/// reveille en retard, il pose les memes notes aux memes instants.
class AccompanimentScheduler {
  AccompanimentScheduler(
    this.plan, {
    this.lookahead = const Duration(milliseconds: 1500),
  });

  final AccompanimentPlan plan;
  final Duration lookahead;

  bool _decomptePose = false;
  int _tour = 0;
  int _indexDansLeTour = 0;

  /// Ce qu'il faut poser maintenant, si l'on en est a [now] depuis le
  /// depart : les clics du decompte au premier appel, puis les notes dont
  /// l'instant tombe avant l'horizon.
  (List<TimedClick>, List<TimedNote>) due(Duration now) {
    final Duration horizon = now + lookahead;
    final List<TimedClick> clics =
        _decomptePose ? const <TimedClick>[] : plan.countInClicks;
    _decomptePose = true;
    final List<TimedNote> notes = <TimedNote>[];
    final List<TimedNote> tour = plan.oneLoop;
    while (true) {
      if (!plan.loop && _tour > 0) {
        break;
      }
      if (_indexDansLeTour >= tour.length) {
        // Fin du tour. Sans boucle, c'est fini ; en boucle, on n'entame le
        // tour suivant que s'il commence avant l'horizon.
        if (!plan.loop) {
          _tour++;
          break;
        }
        if (plan.countIn + plan.length * (_tour + 1) > horizon) {
          break;
        }
        _tour++;
        _indexDansLeTour = 0;
        continue;
      }
      final TimedNote n = tour[_indexDansLeTour];
      final Duration at = n.at + plan.countIn + plan.length * _tour;
      if (at > horizon) {
        break;
      }
      notes.add(
        TimedNote(
          at: at,
          duration: n.duration,
          midi: n.midi,
          velocity: n.velocity,
        ),
      );
      _indexDansLeTour++;
    }
    return (clics, notes);
  }
}
