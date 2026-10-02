import '../music/passage.dart';
import '../music/score_note.dart';

/// Le tempo que l'eleve tient en ce moment, deduit de ce qu'il joue (lot D3).
///
/// **Le tempo de l'eleve, pas celui du papier** (ADR-009, ADR-010). Chaque
/// fois qu'il passe d'une note a la suivante, l'ecart entre les deux attaques
/// rapporte a ce que la partition met entre elles donne un tempo instantane.
/// La mediane des derniers fait le tempo tenu : une hesitation ne le fait pas
/// s'effondrer, une note precipitee ne le fait pas s'emballer.
///
/// **Ne comptent que les enchainements.** Une reprise, un saut ou un arret
/// ne disent rien du tempo -- la note suivante n'est pas celle qui suit sur
/// le papier, ou le silence entre les deux n'est pas ecrit.
class TempoTracker {
  TempoTracker(this.passage, {this.window = 8});

  final Passage passage;

  /// Combien d'enchainements recents font la mediane.
  final int window;

  final List<double> _recents = <double>[];
  int? _derniereNote;
  int? _derniereAttaqueMs;

  /// Instant d'une attaque sur un temps, pour caler la pulsation.
  int? _ancreMs;

  /// Moins d'enchainements que ca, et on ne dit rien.
  static const int minIntervals = 3;

  /// Un ecart qui depasse trois fois ce qu'on attendait n'est pas un tempo,
  /// c'est une hesitation : il est ecarte.
  static const double _hesitation = 3;

  /// L'eleve vient d'attaquer la note [noteIndex] a l'instant [timeMs].
  void noteStarted(int noteIndex, int timeMs) {
    final int? avant = _derniereNote;
    final int? avantMs = _derniereAttaqueMs;
    _derniereNote = noteIndex;
    _derniereAttaqueMs = timeMs;
    final ScoreNote note = passage.notes[noteIndex];
    if (note.onsetTicks % _pulsation == 0) {
      _ancreMs = timeMs;
    }
    if (avant == null || avantMs == null || noteIndex != avant + 1) {
      return;
    }
    final int ticks = note.onsetTicks - passage.notes[avant].onsetTicks;
    final int ms = timeMs - avantMs;
    if (ticks <= 0 || ms <= 0) {
      return;
    }
    final double noire = ticks / passage.ticksPerBeat * 60000 / ms;
    final double? courant = quarterBpm;
    if (courant != null &&
        (noire > courant * _hesitation || noire * _hesitation < courant)) {
      return;
    }
    _recents.add(noire);
    if (_recents.length > window) {
      _recents.removeAt(0);
    }
  }

  /// L'eleve s'est arrete : la prochaine attaque ne s'enchaine sur rien.
  void stopped() {
    _derniereNote = null;
    _derniereAttaqueMs = null;
  }

  /// Le tempo tenu, a la noire, ou `null` tant qu'on n'en sait pas assez.
  double? get quarterBpm {
    if (_recents.length < minIntervals) {
      return null;
    }
    final List<double> tries = List<double>.of(_recents)..sort();
    return tries[tries.length ~/ 2];
  }

  /// Le meme, dans l'unite ou se bat le morceau : la noire pointee en 6/8.
  int? get pulseBpm {
    final double? q = quarterBpm;
    if (q == null) {
      return null;
    }
    return (q * passage.ticksPerBeat / _pulsation).round();
  }

  int get _pulsation =>
      passage.meter?.beatTicks(passage.ticksPerBeat) ?? passage.ticksPerBeat;

  /// Ou en est le temps a l'instant [nowMs], entre 0 (sur le temps) et 1, ou
  /// `null` si l'on ne sait pas encore.
  ///
  /// **Calee sur ses attaques, pas sur une horloge** : la derniere note qu'il
  /// a posee sur un temps fixe le temps, et la pulsation repart de la. Elle
  /// respire avec lui.
  double? beatPhase(int nowMs) {
    final double? q = quarterBpm;
    final int? ancre = _ancreMs;
    if (q == null || ancre == null || nowMs < ancre) {
      return null;
    }
    final double periodeMs = 60000 / q * _pulsation / passage.ticksPerBeat;
    return ((nowMs - ancre) / periodeMs) % 1;
  }

  void reset() {
    _recents.clear();
    _derniereNote = null;
    _derniereAttaqueMs = null;
    _ancreMs = null;
  }
}
