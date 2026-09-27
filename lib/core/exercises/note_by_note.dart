import '../music/finger_pattern.dart';
import '../scoring/live_tuning.dart';

/// Un motif joue **note a note** : on n'avance que sur la bonne note.
///
/// **Et seulement pour un motif de doigts.** Sur un morceau, bloquer detruit
/// la ligne musicale -- on ne joue plus de la musique, on repond a un
/// questionnaire -- et punit exactement ce qu'un enfant qui travaille fait
/// naturellement : s'arreter, reprendre, sauter. Sur huit notes de Sevcik il
/// n'y a aucune ligne a casser, un doigt a la fois, et la justesse note a
/// note *est* le sujet. Bloquer y devient la bonne pedagogie.
///
/// **Bloquer oui, impasse non.** Une attente infinie contredirait deux regles
/// du projet : l'application dit *« voila ta prochaine tache »*, et une erreur
/// ne remet jamais un compteur a zero. Un enfant coince sur une note qu'il ne
/// trouve pas n'a plus de prochaine tache, il a un mur. D'ou trois temps, et
/// **aucun appui** : on cherche, l'aide arrive, puis on passe -- et la note
/// manquee devient la prochaine tache au lieu de disparaitre.
class NoteByNote {
  NoteByNote({
    required this.placements,
    this.toleranceCents = LiveTuning.defaultToleranceCents,
    this.confirmations = 2,
    this.helpAfter = const Duration(seconds: 4),
    this.skipAfter = const Duration(seconds: 9),
  })  : assert(placements.isNotEmpty, 'un motif a des notes'),
        assert(confirmations > 0, 'il faut au moins une confirmation'),
        assert(
          skipAfter > helpAfter,
          'on montre l aide avant de passer, pas apres',
        );

  /// Le motif, corde et doigt compris.
  final List<FingerPlacement> placements;

  /// Au-dela, ce n'est plus la note attendue.
  ///
  /// La meme que partout ailleurs : un bareme different ici apprendrait a
  /// l'oreille que "juste" veut dire deux choses.
  final double toleranceCents;

  /// Trames justes d'affilee avant de valider.
  ///
  /// **D'affilee, et pas une mediane.** Ailleurs on juge une note tenue dont
  /// on connait le debut ; ici l'enfant **cherche**, et il traverse la bonne
  /// note en glissant. Une mediane sur toute la recherche dirait faux, et une
  /// seule trame validerait un passage au vol.
  final int confirmations;

  /// Depuis combien de temps on cherche avant que l'aide s'affiche.
  final Duration helpAfter;

  /// Depuis combien de temps on cherche avant de passer a la suivante.
  final Duration skipAfter;

  int _index = 0;
  Duration _depuis = Duration.zero;
  int _confirmees = 0;
  bool _aide = false;
  final List<int> _aRetravailler = <int>[];

  /// L'index de la note attendue. Vaut [total] une fois le motif fini.
  int get index => _index;

  int get total => placements.length;

  bool get isFinished => _index >= total;

  /// La note attendue, ou `null` si le motif est fini.
  FingerPlacement? get expected => isFinished ? null : placements[_index];

  /// Vrai quand l'aide -- quelle corde, quel doigt -- doit etre affichee.
  bool get showHelp => _aide && !isFinished;

  /// Les index passes sans avoir ete joues juste.
  ///
  /// **La prochaine tache, pas une liste d'echecs.** C'est le mecanisme que le
  /// projet met au centre : ce qu'on a manque revient, ce n'est pas efface.
  List<int> get toRework => List<int>.unmodifiable(_aRetravailler);

  /// Combien de notes ont ete trouvees.
  int get found => _index - _aRetravailler.length;

  /// Une hauteur entendue, a l'instant [now].
  ///
  /// [midi] est fractionnaire : c'est la hauteur reelle, pas la note la plus
  /// proche.
  void hear(double midi, Duration now) {
    if (isFinished) {
      return;
    }
    final FingerPlacement attendue = placements[_index];
    final double cents = (midi - attendue.midi) * 100;
    if (cents.abs() <= toleranceCents) {
      _confirmees++;
      if (_confirmees >= confirmations) {
        _avancer(now, manquee: false);
        return;
      }
    } else {
      // On repart de zero : deux trames justes separees par une fausse ne
      // sont pas une note tenue, c'est un glissando qui passe dessus.
      _confirmees = 0;
    }
    _regarderLHorloge(now);
  }

  /// Le temps passe sans qu'on entende de hauteur.
  ///
  /// Un archet qui ne touche pas la corde, un silence, une note trop faible
  /// pour YIN : rien de tout cela n'est une faute, mais le temps court.
  void wait(Duration now) {
    if (isFinished) {
      return;
    }
    _regarderLHorloge(now);
  }

  void _regarderLHorloge(Duration now) {
    final Duration cherche = now - _depuis;
    if (cherche >= skipAfter) {
      _avancer(now, manquee: true);
      return;
    }
    if (cherche >= helpAfter) {
      _aide = true;
    }
  }

  void _avancer(Duration now, {required bool manquee}) {
    if (manquee) {
      _aRetravailler.add(_index);
    }
    _index++;
    _depuis = now;
    _confirmees = 0;
    _aide = false;
  }

  /// Recommence le motif depuis le debut.
  void reset() {
    _index = 0;
    _depuis = Duration.zero;
    _confirmees = 0;
    _aide = false;
    _aRetravailler.clear();
  }
}
