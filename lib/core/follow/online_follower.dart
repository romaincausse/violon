import 'dart:math' as math;
import 'dart:typed_data';

import '../music/passage.dart';
import '../music/score_note.dart';
import 'follow_model.dart';
import 'performance_features.dart';

/// Ou en est l'eleve, a un instant donne de la prise.
class FollowPosition {
  const FollowPosition({
    required this.timeMs,
    required this.noteIndex,
    required this.resting,
    required this.confidence,
  });

  /// La trame que cette position decrit.
  final int timeMs;

  /// La note qu'il joue, ou celle apres laquelle il s'est arrete. Nulle tant
  /// que rien n'a ete joue.
  final int? noteIndex;

  /// Il ne joue pas : silence avant de commencer, ou arret apres
  /// [noteIndex].
  final bool resting;

  /// Part de la vraisemblance portee par la note retenue, entre 0 et 1.
  ///
  /// **Pas une probabilite au sens strict** -- le suiveur garde le meilleur
  /// chemin, pas la somme de tous -- mais elle se lit pareil : pres de 1, une
  /// seule place explique ce qu'on entend ; vers 0,3, plusieurs se valent.
  /// C'est elle qui dira, au lot S5, quand le suiveur ne sait plus.
  final double confidence;

  bool get started => noteIndex != null;

  /// Il joue la note [noteIndex].
  bool get playing => noteIndex != null && !resting;

  @override
  String toString() => 'FollowPosition($timeMs ms, '
      '${noteIndex == null ? 'avant tout' : '${resting ? 'arret apres ' : ''}'
          'note $noteIndex'}, ${confidence.toStringAsFixed(2)})';
}

/// Le suiveur en ligne (lot S2) : la position de l'eleve, trame apres trame.
///
/// **Le modele de l'aligneur hors ligne, a l'identique** ([FollowModel]) :
/// memes etats, memes transitions, memes emissions. Ce que le banc mesure sur
/// l'un vaut pour l'autre, a une difference pres -- celle du direct.
///
/// **La difference du direct.** Hors ligne, Viterbi remonte le meilleur chemin
/// depuis la fin de la prise : une note mal reconnue se corrige quand la
/// suite la contredit. Ici, on ne connait pas la suite. Le suiveur dit donc ou
/// en est le meilleur chemin *a cet instant*, avec un **leger retard
/// volontaire** ([lagFrames]) : il tranche la position d'il y a deux trames
/// au vu des deux suivantes. Quarante-six millisecondes ne se voient pas sur
/// l'ecran ; elles suffisent a ne pas sauter sur la premiere trame d'une
/// attaque qui n'en etait pas une.
///
/// **Le cout est borne** : un pas par trame, proportionnel au nombre de notes
/// fois le nombre de mesures, et une memoire de [lagFrames] pas. Une heure de
/// travail ne coute pas plus qu'une minute.
class OnlineFollower {
  OnlineFollower(
    this.passage, {
    Set<String> slurredInto = const <String>{},
    this.lagFrames = 2,
  })  : assert(lagFrames >= 0, 'un retard est positif'),
        _modele = FollowModel(passage, slurredInto: slurredInto) {
    _retours = <Int32List>[
      for (int i = 0; i < lagFrames; i++) Int32List(_modele.stateCount),
    ];
    _temps = List<int>.filled(lagFrames + 1, 0);
  }

  final Passage passage;

  /// De combien de trames la position rendue retarde sur la derniere entendue.
  final int lagFrames;

  final FollowModel _modele;
  Float64List? _scores;
  late Float64List _suivants = Float64List(_modele.stateCount);

  /// Les `lagFrames` derniers pas de retour, en anneau.
  late final List<Int32List> _retours;

  /// Instants des trames encore dans la fenetre de retard, en anneau.
  late final List<int> _temps;
  int _vues = 0;

  /// Trames vues depuis le dernier [reset].
  int get framesSeen => _vues;

  /// Ajoute une trame et rend la position de la trame d'il y a [lagFrames]
  /// trames -- ou `null` pendant les toutes premieres.
  FollowPosition? add(FeatureFrame frame) {
    final Float64List? scores = _scores;
    _temps[_vues % _temps.length] = frame.timeMs;
    if (scores == null) {
      _scores = _modele.start(frame);
    } else {
      final Int32List? retour =
          lagFrames == 0 ? null : _retours[_vues % lagFrames];
      _modele.step(scores, _suivants, frame, retour: retour);
      _scores = _suivants;
      _suivants = scores;
    }
    _normaliser(_scores!);
    _vues++;
    if (_vues <= lagFrames) {
      return null;
    }
    return _position(_scores!);
  }

  /// Oublie la prise : la suivante repart d'avant la premiere note.
  void reset() {
    _scores = null;
    _vues = 0;
  }

  /// Ramene le meilleur score a zero. Sans cela les logarithmes derivent sans
  /// fin, et une longue seance finirait par les rendre infinis.
  void _normaliser(Float64List s) {
    double max = double.negativeInfinity;
    for (final double v in s) {
      if (v > max) {
        max = v;
      }
    }
    if (max.isFinite) {
      for (int i = 0; i < s.length; i++) {
        s[i] -= max;
      }
    }
  }

  FollowPosition _position(Float64List s) {
    int etat = 0;
    for (int i = 1; i < s.length; i++) {
      if (s[i] > s[etat]) {
        etat = i;
      }
    }
    // La confiance se lit au present : quelle part de ce qu'on entend la note
    // retenue explique-t-elle ?
    double total = 0;
    final Float64List parNote = Float64List(_modele.noteCount + 1);
    for (int i = 0; i < s.length; i++) {
      final double p = math.exp(s[i]);
      total += p;
      final int? n = _modele.noteIndexOf(i);
      parNote[n ?? _modele.noteCount] += p;
    }
    // Puis on remonte de lagFrames pas pour trancher la position d'alors.
    for (int k = 0; k < lagFrames; k++) {
      final int pas = (_vues - 1 - k) % lagFrames;
      etat = _retours[pas][etat];
    }
    final int? note = _modele.noteIndexOf(etat);
    return FollowPosition(
      timeMs: _temps[(_vues - 1 - lagFrames) % _temps.length],
      noteIndex: note,
      resting: _modele.isRest(etat),
      confidence: total == 0 ? 0 : parNote[note ?? _modele.noteCount] / total,
    );
  }

  /// La note d'une position, pour qui prefere un objet a un index.
  ScoreNote? noteOf(FollowPosition p) =>
      p.noteIndex == null ? null : passage.notes[p.noteIndex!];
}
