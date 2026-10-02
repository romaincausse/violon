import '../music/passage.dart';
import 'accompaniment.dart';
import 'accompaniment_plan.dart';

/// L'accompagnement qui suit l'eleve (lot J5, ADR-016).
///
/// **Il ne joue pas une partition a tempo fixe : il se recale a chaque
/// attaque.** Quand le suiveur reconnait que l'eleve attaque une note, on
/// sait ou il en est dans la partition (le tick de la note) et quand (l'instant
/// de l'attaque, rapporte a l'horloge du moteur). Avec le tempo qu'il tient,
/// on pose les notes d'accompagnement qui tombent **jusqu'a un temps plus
/// loin**, pas davantage.
///
/// **Un temps d'avance seulement, et c'est voulu.** Une note posee dans le
/// moteur ne se reprend plus. Planifier loin, c'est jouer longtemps a cote si
/// l'eleve s'arrete, ralentit ou revient en arriere ; planifier court, c'est
/// se tromper d'un temps au plus, puis se recaler sur l'attaque suivante.
///
/// **Les horloges.** Une attaque est datee par le micro ; [micToEngineMs]
/// la rapporte a l'horloge du moteur, et [latencyMs] (J2, aller-retour)
/// retranche ce que le son met a sortir puis a etre entendu : un son pose a
/// `instant de l'attaque + ecart - latence` sonne en meme temps que l'eleve.
class FollowingAccompanist {
  FollowingAccompanist({
    required this.passage,
    required this.notes,
    required this.latencyMs,
    this.horizonBeats = 1,
  });

  final Passage passage;

  /// L'accompagnement, dans le temps du passage (ticks).
  final List<AccompanimentNote> notes;

  /// La latence aller-retour mesuree (J2).
  final int latencyMs;

  /// Jusqu'ou planifier apres l'attaque, en temps battus.
  final double horizonBeats;

  /// Rien ne se pose moins loin que ca dans le futur : le moteur doit avoir
  /// le temps de le recevoir.
  static const int safetyMs = 30;

  /// Le dernier tick jusqu'auquel on a deja planifie, pour ne rien poser deux
  /// fois.
  int? _planifieJusqua;
  int? _derniereNote;

  /// L'eleve vient d'attaquer la note [noteIndex] a l'instant [attackMicMs]
  /// du micro. Rend les notes a poser, en temps du moteur.
  ///
  /// [quarterBpm] est le tempo qu'il tient (D3), ou `null` -- on prend alors
  /// le tempo du passage.
  List<TimedNote> noteStarted({
    required int noteIndex,
    required int attackMicMs,
    required int micToEngineMs,
    required int nowEngineMs,
    double? quarterBpm,
  }) {
    final int tick = passage.notes[noteIndex].onsetTicks;
    final int? avant = _derniereNote;
    _derniereNote = noteIndex;
    // Une reprise ou un saut : ce qui etait planifie plus loin ne vaut plus,
    // on repart de la ou il est.
    if (avant == null || noteIndex <= avant || noteIndex > avant + 3) {
      _planifieJusqua = tick - 1;
    }
    final double noire = quarterBpm ?? passage.writtenTempoBpm.toDouble();
    final double msParTick = 60000 / noire / passage.ticksPerBeat;
    final int pulsation =
        passage.meter?.beatTicks(passage.ticksPerBeat) ?? passage.ticksPerBeat;
    final int jusqua = tick + (horizonBeats * pulsation).round();
    final int ancre = attackMicMs + micToEngineMs - latencyMs;
    final int depuis = _planifieJusqua ?? tick - 1;

    final List<TimedNote> sortie = <TimedNote>[];
    for (final AccompanimentNote n in notes) {
      if (n.onsetTicks <= depuis || n.onsetTicks > jusqua) {
        continue;
      }
      final int a = ancre + ((n.onsetTicks - tick) * msParTick).round();
      if (a < nowEngineMs + safetyMs) {
        // Trop tard pour celle-la : mieux vaut la taire que la jouer en
        // retard.
        continue;
      }
      sortie.add(
        TimedNote(
          at: Duration(milliseconds: a),
          duration:
              Duration(milliseconds: (n.durationTicks * msParTick).round()),
          midi: n.midi,
          velocity: n.velocity,
        ),
      );
    }
    _planifieJusqua = jusqua;
    return sortie;
  }

  /// Il s'est arrete : la prochaine attaque repartira de zero.
  void stopped() {
    _derniereNote = null;
  }
}
