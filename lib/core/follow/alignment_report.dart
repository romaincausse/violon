import '../music/passage.dart';
import '../music/score_note.dart';
import 'offline_aligner.dart';

/// Une note etiquetee par l'annotateur.
class LabelledNote {
  const LabelledNote({
    required this.timeMs,
    required this.noteId,
    this.wrong = false,
    this.doubtful = false,
  });

  final int timeMs;

  /// Note visee. Nulle pour une note hors partition (`x`) ou un doute (`?`).
  final String? noteId;

  final bool wrong;
  final bool doubtful;

  bool get extra => noteId == null && !doubtful;
}

/// La verite terrain d'une prise : les etiquettes de l'annotateur, lues dans
/// l'export d'Audacity. La syntaxe est celle de `docs/banc-d-essai.md`.
class GroundTruth {
  GroundTruth({required this.notes, required this.stops});

  /// Dans l'ordre du temps.
  final List<LabelledNote> notes;

  /// Les regions `arret` : debut et fin, en millisecondes.
  final List<(int, int)> stops;

  static final RegExp _note = RegExp(r'^(n\d+)( faux)?$');

  /// **Une etiquette illisible est une erreur, pas une ligne sautee** : une
  /// faute de frappe de l'annotateur qui disparaitrait en silence fausserait
  /// le chiffre du jalon sans que personne ne le voie.
  static GroundTruth parseAudacity(String texte) {
    final List<LabelledNote> notes = <LabelledNote>[];
    final List<(int, int)> stops = <(int, int)>[];
    final List<String> lignes = texte.split('\n');
    for (int l = 0; l < lignes.length; l++) {
      final String ligne = lignes[l].trimRight();
      // Audacity ecrit une ligne commencant par une barre oblique inverse pour
      // la selection spectrale : elle ne porte pas d'etiquette.
      if (ligne.trim().isEmpty || ligne.startsWith(r'\')) {
        continue;
      }
      final List<String> champs = ligne.split('\t');
      if (champs.length < 3) {
        throw FormatException('ligne ${l + 1} : trois champs attendus', ligne);
      }
      final int debut = _ms(champs[0], l);
      final int fin = _ms(champs[1], l);
      final String etiquette = champs.sublist(2).join('\t').trim();
      final RegExpMatch? m = _note.firstMatch(etiquette);
      if (etiquette == 'arret') {
        stops.add((debut, fin));
      } else if (etiquette == 'x') {
        notes.add(LabelledNote(timeMs: debut, noteId: null));
      } else if (etiquette == '?') {
        notes.add(LabelledNote(timeMs: debut, noteId: null, doubtful: true));
      } else if (m != null) {
        notes.add(
          LabelledNote(
            timeMs: debut,
            noteId: m.group(1),
            wrong: m.group(2) != null,
          ),
        );
      } else {
        throw FormatException(
          'ligne ${l + 1} : etiquette inconnue "$etiquette"',
          ligne,
        );
      }
    }
    notes
        .sort((LabelledNote a, LabelledNote b) => a.timeMs.compareTo(b.timeMs));
    return GroundTruth(notes: notes, stops: stops);
  }

  static int _ms(String champ, int ligne) {
    final double? secondes = double.tryParse(champ.trim());
    if (secondes == null) {
      throw FormatException('ligne ${ligne + 1} : instant illisible', champ);
    }
    return (secondes * 1000).round();
  }
}

/// Le sort d'une note etiquetee.
class NoteVerdict {
  const NoteVerdict({required this.label, required this.alignedId});

  final LabelledNote label;

  /// Note que l'aligneur a reconnue a cet endroit. Nulle s'il n'y a vu que du
  /// silence.
  final String? alignedId;
}

/// Ce que vaut un alignement face a la verite terrain.
///
/// **Les regles sont celles du protocole, fixees avant d'avoir vu un
/// chiffre** (`docs/banc-d-essai.md`) :
///  - le denominateur est fait des notes `nX` et `nX faux` ;
///  - une note est **dans la bonne mesure** si la note reconnue a la meme
///    mesure, **sur la bonne note** si c'est exactement elle ;
///  - les `x` et les `?` sont exclus du denominateur. Un `x` pris pour une
///    note de la partition est une erreur, comptee a part.
class AlignmentReport {
  AlignmentReport._(this.verdicts, this._mesureDe);

  final List<NoteVerdict> verdicts;
  final Map<String, int> _mesureDe;

  /// Apres l'etiquette, on laisse passer l'attaque avant de regarder ce que
  /// l'aligneur a reconnu : l'etiquette est posee a la main, a vingt
  /// millisecondes pres, et la premiere trame entend encore la note d'avant.
  static const int settleMs = 30;

  /// Au-dela, on ne regarde plus : une note tenue plus longtemps n'apprend
  /// rien de plus sur sa position.
  static const int maxWindowMs = 1500;

  static AlignmentReport evaluate(
    Alignment alignment,
    GroundTruth truth,
    Passage passage,
  ) {
    final List<NoteVerdict> verdicts = <NoteVerdict>[];
    for (int i = 0; i < truth.notes.length; i++) {
      final LabelledNote label = truth.notes[i];
      int fin = label.timeMs + maxWindowMs;
      if (i + 1 < truth.notes.length) {
        fin = _min(fin, truth.notes[i + 1].timeMs);
      }
      for (final (int debutArret, _) in truth.stops) {
        if (debutArret > label.timeMs) {
          fin = _min(fin, debutArret);
        }
      }
      verdicts.add(
        NoteVerdict(
          label: label,
          alignedId: _majorite(alignment, label.timeMs + settleMs, fin),
        ),
      );
    }
    return AlignmentReport._(verdicts, <String, int>{
      for (final ScoreNote n in passage.notes) n.id: n.measure,
    });
  }

  /// La note la plus souvent reconnue entre [debut] et [fin]. Si la fenetre
  /// est plus courte qu'une trame, on prend la trame qui la contient.
  static String? _majorite(Alignment a, int debut, int fin) {
    final Map<String, int> compte = <String, int>{};
    int? derniere;
    for (int t = 0; t < a.frameTimesMs.length; t++) {
      final int temps = a.frameTimesMs[t];
      if (temps <= debut) {
        derniere = t;
      }
      if (temps >= debut && temps < fin) {
        final String? id = a.frameNotes[t];
        if (id != null) {
          compte[id] = (compte[id] ?? 0) + 1;
        }
      }
    }
    if (compte.isEmpty) {
      return derniere == null ? null : a.frameNotes[derniere];
    }
    return compte.entries
        .reduce((MapEntry<String, int> x, MapEntry<String, int> y) =>
            y.value > x.value ? y : x)
        .key;
  }

  static int _min(int a, int b) => a < b ? a : b;

  Iterable<NoteVerdict> get _comptees =>
      verdicts.where((NoteVerdict v) => v.label.noteId != null);

  /// Notes au denominateur.
  int get counted => _comptees.length;

  int get rightMeasure => _comptees
      .where(
        (NoteVerdict v) =>
            v.alignedId != null &&
            _mesureDe[v.alignedId] == _mesureDe[v.label.noteId],
      )
      .length;

  int get rightNote =>
      _comptees.where((NoteVerdict v) => v.alignedId == v.label.noteId).length;

  double get measureRate => counted == 0 ? 1 : rightMeasure / counted;
  double get noteRate => counted == 0 ? 1 : rightNote / counted;

  int get extras => verdicts.where((NoteVerdict v) => v.label.extra).length;

  /// Notes hors partition que l'aligneur a prises pour une nouvelle note de la
  /// partition. Rester sur la note d'avant n'est pas une faute : c'est
  /// exactement ce qu'un suiveur tolerant doit faire.
  int get extrasTakenForNotes {
    int n = 0;
    for (int i = 0; i < verdicts.length; i++) {
      final NoteVerdict v = verdicts[i];
      if (!v.label.extra || v.alignedId == null) {
        continue;
      }
      final String? avant = i > 0 ? verdicts[i - 1].alignedId : null;
      if (v.alignedId != avant) {
        n++;
      }
    }
    return n;
  }

  int get doubtful =>
      verdicts.where((NoteVerdict v) => v.label.doubtful).length;

  /// Les notes mal placees, pour comprendre ou ca casse.
  Iterable<NoteVerdict> get misses =>
      _comptees.where((NoteVerdict v) => v.alignedId != v.label.noteId);
}
