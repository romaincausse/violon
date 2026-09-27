import '../music/passage.dart';
import '../music/score_note.dart';

/// Une partition du banc d'essai, telle que le protocole la decrit
/// (`docs/banc-d-essai.md`) : les champs de [ScoreNote], plus deux
/// informations que le modele pivot n'a pas et que le suivi exige.
///
/// - `slur` : identifiant de liaison. Deux notes consecutives de meme `slur`
///   sont dans le meme archet : la seconde arrive **sans attaque**.
/// - `tie` : la note prolonge la precedente. Aucune nouvelle hauteur ni
///   attaque : pour l'oreille, ce n'est pas une note. Elle est fondue dans la
///   precedente, et l'annotateur ne l'etiquette pas.
///
/// Ces deux champs restent ici plutot que dans [ScoreNote] : P2 ne touche
/// pas au modele, et il est encore trop tot pour savoir sous quelle forme le
/// suiveur en ligne en aura besoin.
class BenchScore {
  BenchScore({required this.passage, required this.slurredInto});

  final Passage passage;

  /// Notes jouees dans le meme archet que la precedente.
  final Set<String> slurredInto;

  static BenchScore fromJson(Map<String, Object?> json) {
    final List<Object?> brutes =
        _champ<List<Object?>>(json, 'notes', 'partition');
    final List<ScoreNote> notes = <ScoreNote>[];
    final Set<String> liees = <String>{};
    Object? liaisonPrecedente;
    for (int i = 0; i < brutes.length; i++) {
      final Object? brute = brutes[i];
      if (brute is! Map<String, Object?>) {
        throw FormatException('note ${i + 1} : objet attendu');
      }
      final String ou = 'note ${i + 1}';
      final ScoreNote note = ScoreNote(
        id: _champ<String>(brute, 'id', ou),
        midi: _champ<int>(brute, 'midi', ou),
        onsetTicks: _champ<int>(brute, 'onsetTicks', ou),
        durationTicks: _champ<int>(brute, 'durationTicks', ou),
        measure: _champ<int>(brute, 'measure', ou),
      );
      if (brute['tie'] == true) {
        if (notes.isEmpty) {
          throw FormatException('$ou : une tenue sans note a prolonger');
        }
        final ScoreNote tenue = notes.removeLast();
        notes.add(
          tenue.copyWith(
            durationTicks: note.offsetTicks - tenue.onsetTicks,
          ),
        );
        continue;
      }
      final Object? liaison = brute['slur'];
      if (liaison != null && liaison == liaisonPrecedente) {
        liees.add(note.id);
      }
      liaisonPrecedente = liaison;
      notes.add(note);
    }
    if (notes.isEmpty) {
      throw const FormatException('partition sans note');
    }
    return BenchScore(
      passage: Passage(
        title: (json['title'] as String?) ?? '',
        notes: notes,
        ticksPerBeat: _champ<int>(json, 'ticksPerBeat', 'partition'),
        writtenTempoBpm: (json['writtenTempoBpm'] as int?) ?? 80,
      ),
      slurredInto: liees,
    );
  }

  /// L'inverse de [fromJson], pour ecrire dans le banc les partitions des
  /// prises de synthese. Une note liee a la precedente partage son `slur`.
  static Map<String, Object?> toJson(
    Passage passage, {
    Set<String> slurredInto = const <String>{},
  }) {
    int liaison = 0;
    return <String, Object?>{
      'title': passage.title,
      'ticksPerBeat': passage.ticksPerBeat,
      'writtenTempoBpm': passage.writtenTempoBpm,
      'notes': <Map<String, Object?>>[
        for (final ScoreNote n in passage.notes)
          <String, Object?>{
            'id': n.id,
            'midi': n.midi,
            'onsetTicks': n.onsetTicks,
            'durationTicks': n.durationTicks,
            'measure': n.measure,
            'slur': slurredInto.contains(n.id) ? 's$liaison' : 's${++liaison}',
          },
      ],
    };
  }

  static T _champ<T>(Map<String, Object?> json, String cle, String ou) {
    final Object? v = json[cle];
    if (v is! T) {
      throw FormatException('$ou : champ "$cle" absent ou mal type');
    }
    return v;
  }
}
