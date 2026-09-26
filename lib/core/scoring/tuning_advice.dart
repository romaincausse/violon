import 'tuner.dart';

/// Ce qu'il faut faire de ses mains.
enum TuningAction {
  /// Rien d'exploitable n'est entendu : il n'y a pas de conseil a donner.
  play,

  /// La hauteur bouge encore. Un archet qui demarre fait varier la note de
  /// plusieurs dizaines de cents : conseiller un geste maintenant, c'est le
  /// conseiller au hasard.
  hold,

  /// La corde est juste. Le seul conseil est de ne plus y toucher.
  stop,

  /// Petit ecart : le tendeur suffit, et il est bien plus sur qu'une cheville.
  fineTuner,

  /// Gros ecart : le tendeur n'a pas assez de course, il faut la cheville.
  peg,
}

/// Dans quel sens tourner.
enum TuningTurn {
  /// La corde est trop basse : il faut la tendre.
  tighten,

  /// La corde est trop haute : il faut la detendre.
  loosen,
}

/// Un conseil, pret a etre dit en trois mots.
class TuningAdvice {
  const TuningAdvice({required this.action, this.turn, this.stringMidi});

  final TuningAction action;

  /// Le sens de rotation, quand il y a quelque chose a tourner.
  final TuningTurn? turn;

  /// La corde concernee, quand une corde est entendue.
  final int? stringMidi;

  /// Y a-t-il quelque chose a tourner ?
  bool get turns =>
      action == TuningAction.fineTuner || action == TuningAction.peg;
}

/// Traduit une mesure en geste.
///
/// **Le lot qui manquait a l'accordeur.** Il mesurait et affichait -- un ecart
/// en cents, une jauge, les quintes -- sans jamais dire ce qu'il fallait faire
/// de ses mains. Trois mots manquaient : quelle cheville, dans quel sens, et
/// quand s'arreter. Sans eux l'enfant mesure, constate, et appelle son pere,
/// ce que l'application est precisement censee eviter.
///
/// **Le "quand s'arreter" ne se dit pas, il se voit.** Le conseil passe de la
/// cheville au tendeur quand l'ecart se resserre, puis a "c'est bon" : le
/// geste lui-meme annonce qu'on approche.
///
/// **Aucun chiffre en hertz n'entre ici.** L'ecart vient de `TunerReading`,
/// donc du diapason que l'accordeur utilise -- celui de l'instrument s'il a
/// ete adopte (lot O4). Dire "monte a 440" contredirait la mesure affichee
/// juste au-dessus ; le conseil dit un sens, et s'arrete quand c'est juste.
class TuningCoach {
  const TuningCoach({
    this.fineTunerRangeCents = 25,
    this.fineTuners = _quatreCordes,
  });

  /// En deca de cet ecart, on renvoie au tendeur.
  ///
  /// Un tendeur a peu de course : passe une vingtaine de cents il arrive en
  /// butee, et l'enfant force sur une vis au lieu de prendre la cheville.
  /// Au-dela, la cheville est le bon outil meme si elle fait peur.
  final double fineTunerRangeCents;

  /// Les cordes qui portent un tendeur.
  ///
  /// **Les quatre par defaut**, comme sur la plupart des violons d'etude. Un
  /// instrument qui n'en a qu'un, sur le mi, se declare en passant la seule
  /// corde concernee -- sans quoi le conseil enverrait vers une vis qui
  /// n'existe pas.
  final List<int> fineTuners;

  static const List<int> _quatreCordes = <int>[55, 62, 69, 76];

  TuningAdvice advise(TunerReading? reading) {
    if (reading == null) {
      return const TuningAdvice(action: TuningAction.play);
    }
    if (!reading.steady) {
      return TuningAdvice(
        action: TuningAction.hold,
        stringMidi: reading.stringMidi,
      );
    }
    if (reading.inTune) {
      return TuningAdvice(
        action: TuningAction.stop,
        stringMidi: reading.stringMidi,
      );
    }
    final double ecart = reading.centsOffset;
    final bool petit = ecart.abs() <= fineTunerRangeCents &&
        fineTuners.contains(reading.stringMidi);
    return TuningAdvice(
      action: petit ? TuningAction.fineTuner : TuningAction.peg,
      // Trop bas, on tend ; trop haut, on detend. C'est la seule convention
      // du lot, et elle n'a pas le droit d'etre inversee.
      turn: ecart < 0 ? TuningTurn.tighten : TuningTurn.loosen,
      stringMidi: reading.stringMidi,
    );
  }
}
