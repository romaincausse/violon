import '../music/passage.dart';
import '../music/score_note.dart';
import 'offline_aligner.dart';

/// L'annotation corrigee (`docs/banc-d-essai.md`) : l'aligneur propose un
/// marqueur par note, l'annotateur ecoute et ne corrige que ses erreurs.
///
/// **Le marqueur se lit a l'oreille** : `m5 re n23`, la mesure, le nom de la
/// note, puis son identifiant. L'annotateur qui corrige ecrit ce qu'il
/// entend -- `m6 mi` -- sans avoir a trouver un identifiant : c'est
/// [ProposedLabels.resolve] qui le retrouve dans la partition.
class ProposedLabels {
  ProposedLabels._();

  static const List<String> _noms = <String>[
    'do', 'do#', 're', 're#', 'mi', 'fa', 'fa#', 'sol', 'sol#', 'la', 'la#',
    'si', //
  ];

  static const Map<String, int> _bemols = <String, int>{
    'dob': 11,
    'reb': 1,
    'mib': 3,
    'fab': 4,
    'solb': 6,
    'lab': 8,
    'sib': 10,
  };

  static String nom(int midi) => _noms[midi % 12];

  /// La classe de hauteur d'un nom ecrit a la main, ou `null`.
  static int? classe(String brut) {
    final String n = brut
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('♯', '#')
        .replaceAll('♭', 'b');
    final int i = _noms.indexOf(n);
    return i >= 0 ? i : _bemols[n];
  }

  /// Un marqueur Audacity par note reconnue, dans l'ordre du jeu.
  static String propose(Alignment alignement, Passage passage) {
    final Map<String, ScoreNote> parId = <String, ScoreNote>{
      for (final ScoreNote n in passage.notes) n.id: n,
    };
    final StringBuffer sortie = StringBuffer();
    for (final AlignedNote a in alignement.notes) {
      final ScoreNote? n = parId[a.noteId];
      if (n == null) {
        continue;
      }
      final String t = (a.startMs / 1000).toStringAsFixed(3);
      sortie.writeln('$t\t$t\tm${n.measure} ${nom(n.midi)} ${n.id}');
    }
    return sortie.toString();
  }

  static final RegExp _marqueur = RegExp(
    r'^(?:m(\d+)\s+)?(\S+?)(?:\s+(n\d+))?(\s+faux)?$',
  );

  /// Traduit les marqueurs corriges en etiquettes du protocole (`n12`,
  /// `n12 faux`, `x`, `?`, `arret`).
  ///
  /// **Un identifiant garde n'est cru que s'il s'accorde avec le nom et la
  /// mesure ecrits a cote** : l'annotateur qui corrige `m5 re n23` en
  /// `m6 mi n23` a change ce qu'il entendait, pas oublie d'effacer n23.
  /// Sinon, la note est cherchee dans la mesure ecrite, et parmi plusieurs
  /// notes du meme nom on prend la premiere apres la note precedente --
  /// on joue en avancant. Chaque identifiant ainsi deduit est signale dans
  /// [notes], pour que l'annotateur puisse le relire.
  static (String etiquettes, List<String> notes) resolve(
    String corrige,
    Passage passage,
  ) {
    final List<ScoreNote> partition = passage.notes;
    final StringBuffer sortie = StringBuffer();
    final List<String> notes = <String>[];
    int precedente = -1;
    final List<String> lignes = corrige.split('\n');
    for (int l = 0; l < lignes.length; l++) {
      final String ligne = lignes[l].trimRight();
      if (ligne.trim().isEmpty || ligne.startsWith(r'\')) {
        continue;
      }
      final List<String> champs = ligne.split('\t');
      if (champs.length < 3) {
        throw FormatException('ligne ${l + 1} : trois champs attendus', ligne);
      }
      final String texte = champs.sublist(2).join(' ').trim();
      final String temps = '${champs[0]}\t${champs[1]}';
      if (texte == 'x' || texte == '?' || texte == 'arret') {
        sortie.writeln('$temps\t$texte');
        continue;
      }
      final RegExpMatch? m = _marqueur.firstMatch(texte);
      final int? classeEcrite = m == null ? null : classe(m.group(2)!);
      if (m == null || classeEcrite == null) {
        throw FormatException(
          'ligne ${l + 1} : marqueur illisible "$texte" '
          '(attendu par exemple "m5 re", "x", "?")',
          ligne,
        );
      }
      final int? mesure = m.group(1) == null ? null : int.parse(m.group(1)!);
      final String? id = m.group(3);
      final bool faux = m.group(4) != null;

      bool convient(ScoreNote n) =>
          n.midi % 12 == classeEcrite &&
          (mesure == null || n.measure == mesure);

      int trouvee = id == null
          ? -1
          : partition.indexWhere((ScoreNote n) => n.id == id && convient(n));
      if (trouvee < 0) {
        final List<int> candidates = <int>[
          for (int i = 0; i < partition.length; i++)
            if (convient(partition[i])) i,
        ];
        if (candidates.isEmpty) {
          throw FormatException(
            'ligne ${l + 1} : aucun ${m.group(2)} '
            '${mesure == null ? 'dans la partition' : 'en mesure $mesure'}'
            '. Une note fausse s ecrit avec le nom de la note attendue, '
            'suivi de "faux".',
            ligne,
          );
        }
        trouvee = candidates.firstWhere(
          (int i) => i > precedente,
          orElse: () => candidates.first,
        );
        notes.add(
          '${champs[0]}s  "$texte"  ->  ${partition[trouvee].id}'
          '${candidates.length > 1 ? ' (${candidates.length} possibles)' : ''}',
        );
      }
      precedente = trouvee;
      sortie.writeln(
        '$temps\t${partition[trouvee].id}${faux ? ' faux' : ''}',
      );
    }
    return (sortie.toString(), notes);
  }
}
