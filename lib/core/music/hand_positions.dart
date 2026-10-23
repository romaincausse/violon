import 'finger_pattern.dart';
import 'passage.dart';
import 'score_note.dart';

/// Ou la main joue chaque note d'un passage (lot K3) : la corde, la position
/// et le doigt.
///
/// **Le doigte ecrit d'abord** (K2) : un "3" sur un re5 dit la premiere
/// position, un "1" sur le meme re5 dit la troisieme. Une edition ne doigte
/// que les changements de position : la position dite **dure** sur les notes
/// suivantes, tant qu'elles y tiennent.
///
/// **Sans doigte, le contexte** : la premiere position tant que rien ne dit
/// le contraire ; au-dessus de ce qu'elle atteint, ou a cote d'une telle
/// note, on ne sait plus.
///
/// **Faute de pouvoir trancher, la note n'a pas de place** (`null`) : mieux
/// vaut un diagnostic de moins qu'un doigt accuse a tort.
class HandPositions {
  const HandPositions._();

  /// Les cordes a vide, de la plus grave a la plus aigue.
  static const List<int> cordes = <int>[55, 62, 69, 76];

  /// La note la plus aigue de la premiere position : le 4e doigt sur mi.
  static const int plusAiguEnPremiere = 83;

  /// Les demi-tons au-dessus de la corde a vide que chaque doigt atteint,
  /// par position. En troisieme, le 1er doigt se pose ou le 3e se posait en
  /// premiere.
  static const Map<int, Map<int, List<int>>> _portee =
      <int, Map<int, List<int>>>{
    1: <int, List<int>>{
      1: <int>[1, 2],
      2: <int>[3, 4],
      3: <int>[5, 6],
      4: <int>[6, 7],
    },
    3: <int, List<int>>{
      1: <int>[4, 5],
      2: <int>[6, 7],
      3: <int>[8, 9],
      4: <int>[10, 11],
    },
  };

  /// La place de chaque note de [passage], par identifiant ; `null` quand on
  /// ne peut pas trancher. Une corde a vide a le doigt 0.
  static Map<String, FingerPlacement?> of(Passage passage) {
    final List<ScoreNote> notes = passage.notes;
    final Map<String, FingerPlacement?> places = <String, FingerPlacement?>{};
    // 1 ou 3 : la position tenue ; 0 : on ne sait plus ou est la main.
    int position = 1;
    int? corde;
    for (int i = 0; i < notes.length; i++) {
      final ScoreNote n = notes[i];
      final String? ecrit = n.fingering;
      final int? doigt = ecrit == null ? null : int.tryParse(ecrit);
      FingerPlacement? place;
      if (doigt == 0) {
        place = _aVide(n.midi);
      } else if (doigt != null && doigt >= 1 && doigt <= 4) {
        place = _avecDoigt(n.midi, doigt);
        position = place?.position ?? 0;
      } else if (cordes.contains(n.midi)) {
        // Une corde a vide sans doigte se joue a vide, dans toutes les
        // positions ; et elle ramene la main la ou elle sait etre.
        place = _aVide(n.midi);
        if (position == 0) {
          position = 1;
        }
      } else if (position == 1) {
        place = _voisinDUnPassageAigu(notes, i) ? null : _enPremiere(n.midi);
        if (place == null && n.midi > plusAiguEnPremiere) {
          position = 0;
        }
      } else if (position == 3) {
        place = _enTroisieme(n.midi, corde);
        if (place == null) {
          position = 0;
        }
      } else if (n.midi < cordes[1]) {
        // Sur la corde de sol, sous le re : la main est revenue en bas.
        position = 1;
        place = _enPremiere(n.midi);
      }
      if (place != null && place.finger > 0) {
        corde = place.stringMidi;
      }
      places[n.id] = place;
    }
    return places;
  }

  /// Les notes ou la main arrive d'un changement de position (K5) : la note
  /// d'avant etait doigtee, dans une autre position. Leur debut est un
  /// glissando.
  static Set<String> shiftArrivals(Passage passage) {
    final Map<String, FingerPlacement?> places = of(passage);
    final Set<String> arrivees = <String>{};
    FingerPlacement? avant;
    for (final ScoreNote n in passage.notes) {
      final FingerPlacement? p = places[n.id];
      if (p != null &&
          avant != null &&
          p.finger > 0 &&
          avant.finger > 0 &&
          p.position != avant.position) {
        arrivees.add(n.id);
      }
      avant = p;
    }
    return arrivees;
  }

  /// La place de [midi] dans la [position] donnee, doigt pose, sur la corde
  /// la plus grave qui l'atteint : c'est ainsi qu'une gamme en troisieme
  /// reste sur une corde aussi longtemps qu'elle peut. `null` si aucune.
  static FingerPlacement? placeIn(int midi, {required int position}) {
    final Map<int, List<int>>? doigts = _portee[position];
    if (doigts == null) {
      return null;
    }
    for (final int c in cordes) {
      for (int d = 1; d <= 4; d++) {
        if (doigts[d]!.contains(midi - c)) {
          return FingerPlacement(
            stringMidi: c,
            finger: d,
            midi: midi,
            position: position,
          );
        }
      }
    }
    return null;
  }

  static FingerPlacement? _aVide(int midi) => cordes.contains(midi)
      ? FingerPlacement(stringMidi: midi, finger: 0, midi: midi)
      : null;

  /// La place que dit un doigte ecrit : la premiere position si elle
  /// convient, sinon la troisieme.
  static FingerPlacement? _avecDoigt(int midi, int doigt) {
    for (final int p in <int>[1, 3]) {
      for (final int c in cordes) {
        if (_portee[p]![doigt]!.contains(midi - c)) {
          return FingerPlacement(
            stringMidi: c,
            finger: doigt,
            midi: midi,
            position: p,
          );
        }
      }
    }
    return null;
  }

  /// En premiere position : la corde la plus aigue qui l'atteint sans le 4e
  /// doigt, comme un eleve la joue.
  static FingerPlacement? _enPremiere(int midi) {
    for (final int c in cordes.reversed) {
      final int k = midi - c;
      if (k >= 1 && k <= 6) {
        return FingerPlacement(
          stringMidi: c,
          finger: (k + 1) ~/ 2,
          midi: midi,
        );
      }
    }
    return null;
  }

  /// En troisieme position, de preference sur la corde de la note d'avant.
  static FingerPlacement? _enTroisieme(int midi, int? corde) {
    final List<int> essais = <int>[
      if (corde != null) corde,
      for (final int c in cordes.reversed)
        if (c != corde) c,
    ];
    for (final int c in essais) {
      for (int d = 1; d <= 4; d++) {
        if (_portee[3]![d]!.contains(midi - c)) {
          return FingerPlacement(
            stringMidi: c,
            finger: d,
            midi: midi,
            position: 3,
          );
        }
      }
    }
    return null;
  }

  /// Une note qui touche, a deux notes pres, une note que la premiere
  /// position n'atteint pas : la main est sans doute montee avec elle.
  static bool _voisinDUnPassageAigu(List<ScoreNote> notes, int i) {
    if (notes[i].midi < 67) {
      return false;
    }
    for (int j = i - 2; j <= i + 2; j++) {
      if (j >= 0 && j < notes.length && notes[j].midi > plusAiguEnPremiere) {
        return true;
      }
    }
    return false;
  }
}
