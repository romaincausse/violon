import 'note_value.dart';
import 'passage.dart';
import 'score_note.dart';

/// Construit un [Passage] note par note, sans MusicXML.
///
/// C'est la seule facon d'entrer un passage aujourd'hui : le gravage de
/// partition arrive au jalon suivant. Toute l'arithmetique vit ici plutot que
/// dans l'ecran de saisie, pour rester testable sans `pumpWidget`.
///
/// Deux quantites sont deduites, jamais saisies :
///  - `onsetTicks`, cumul des durees precedentes ;
///  - `measure`, deduit de l'onset et du nombre de temps par mesure.
///
/// L'eleve saisit donc uniquement des hauteurs et des figures, ce qui est
/// exactement ce qu'il lit sur sa partition.
class PassageBuilder {
  PassageBuilder({
    this.ticksPerBeat = 480,
    this.beatsPerMeasure = 4,
    this.firstMeasure = 1,
  })  : assert(ticksPerBeat > 0, 'ticksPerBeat doit etre > 0'),
        assert(beatsPerMeasure > 0, 'une mesure a au moins un temps'),
        assert(firstMeasure >= 1, 'les mesures sont numerotees a partir de 1');

  /// Resolution temporelle. 480 est un multiple de 8, donc une double-croche
  /// pointee tombe encore sur un entier.
  final int ticksPerBeat;

  /// Chiffrage : 4 pour du 4/4 ou du 2/2, 3 pour du 3/4, 6 pour du 6/8 lu a
  /// la croche. Sert uniquement a numeroter les mesures.
  final int beatsPerMeasure;

  /// Numero de la premiere mesure du passage, tel qu'il est imprime sur la
  /// partition. C'est ce qui permet de dire "mesures 12 a 13" plutot que
  /// "mesures 1 a 2".
  final int firstMeasure;

  final List<ScoreNote> _notes = <ScoreNote>[];
  int _totalTicks = 0;

  int get ticksPerMeasure => ticksPerBeat * beatsPerMeasure;

  int get noteCount => _notes.length;
  bool get isEmpty => _notes.isEmpty;
  bool get isNotEmpty => _notes.isNotEmpty;

  /// Duree cumulee, en ticks.
  int get totalTicks => _totalTicks;

  /// Notes saisies jusqu'ici, dans l'ordre. Copie : modifier la liste rendue
  /// ne touche pas le constructeur.
  List<ScoreNote> get notes => List<ScoreNote>.unmodifiable(_notes);

  /// Derniere mesure atteinte. Vaut [firstMeasure] tant que rien n'est saisi.
  int get lastMeasure => _notes.isEmpty ? firstMeasure : _notes.last.measure;

  /// Ajoute une note a la suite.
  void add(int midi, NoteValue value, {bool dotted = false}) {
    final int onset = _totalTicks;
    _notes.add(
      ScoreNote(
        id: 'n${_notes.length + 1}',
        midi: midi,
        onsetTicks: onset,
        durationTicks: value.ticksIn(ticksPerBeat, dotted: dotted),
        measure: firstMeasure + onset ~/ ticksPerMeasure,
      ),
    );
    _totalTicks += _notes.last.durationTicks;
  }

  /// Annule la derniere note. Sans effet si rien n'a ete saisi : la saisie
  /// est un geste repete, elle ne doit jamais lever d'exception.
  void removeLast() {
    if (_notes.isEmpty) {
      return;
    }
    _totalTicks -= _notes.removeLast().durationTicks;
  }

  void clear() {
    _notes.clear();
    _totalTicks = 0;
  }

  /// Titre par defaut, aligne sur le vocabulaire de la partition.
  String get suggestedTitle => firstMeasure == lastMeasure
      ? 'Mesure $firstMeasure'
      : 'Mesures $firstMeasure a $lastMeasure';

  /// Fige la saisie en [Passage].
  ///
  /// Le passage recoit une copie des notes : continuer a saisir apres un
  /// `build()` ne modifie pas le passage deja rendu.
  Passage build({String? title, int writtenTempoBpm = 80}) {
    if (_notes.isEmpty) {
      throw StateError('un passage contient au moins une note');
    }
    final String trimmed = (title ?? '').trim();
    return Passage(
      title: trimmed.isEmpty ? suggestedTitle : trimmed,
      notes: List<ScoreNote>.of(_notes),
      ticksPerBeat: ticksPerBeat,
      writtenTempoBpm: writtenTempoBpm,
    );
  }
}
