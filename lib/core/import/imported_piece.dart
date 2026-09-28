import '../music/meter.dart';
import '../music/passage.dart';
import '../music/score_note.dart';

/// Un morceau entier, importe d'un fichier, et range sur le telephone.
///
/// **Le morceau n'est pas ce qu'on travaille.** On travaille un passage : deux,
/// huit, seize mesures. Le morceau est la source ou on le decoupe, comme le
/// papier sur le pupitre, et il reste entier pour qu'on puisse y revenir
/// demain sur d'autres mesures.
class ImportedPiece {
  ImportedPiece({
    required this.id,
    required this.title,
    required this.passage,
    this.composer,
    this.slurredInto = const <String>{},
    this.warnings = const <String>[],
  });

  /// Identifiant stable, tire du contenu : reimporter le meme fichier
  /// remplace le morceau au lieu de le dedoubler.
  final String id;

  final String title;
  final String? composer;

  /// Tout le morceau, chiffrage, armure et mesures compris.
  final Passage passage;

  /// Notes jouees dans le meme archet que la precedente, donc sans attaque.
  ///
  /// Le suiveur en aura besoin (voir `BenchScore`) ; on la garde des l'import
  /// plutot que de devoir redemander le fichier le jour ou il la lira.
  final Set<String> slurredInto;

  /// Ce que l'import n'a pas pu rendre fidelement, dit a l'utilisateur.
  ///
  /// **Dit, jamais tu.** Une double corde reduite a sa note aigue ou une voix
  /// ignoree sont des choix raisonnables ; les faire en silence ne l'est pas,
  /// car l'application jugerait ensuite l'enfant sur une partition qui n'est
  /// pas tout a fait la sienne.
  final List<String> warnings;

  int get firstMeasure =>
      passage.bars?.first.number ?? passage.notes.first.measure;
  int get lastMeasure =>
      passage.bars?.last.number ?? passage.notes.last.measure;

  /// Le passage des mesures [from] a [to], bornes comprises, ou `null` s'il
  /// n'y a aucune note a jouer entre les deux.
  Passage? excerpt(int from, int to) {
    final List<ScoreNote> notes = <ScoreNote>[
      for (final ScoreNote n in passage.notes)
        if (n.measure >= from && n.measure <= to) n,
    ];
    if (notes.isEmpty) {
      return null;
    }
    final bool tout = from <= firstMeasure && to >= lastMeasure;
    return passage.withNotes(
      notes,
      // Une mesure de silence demandee reste la : on compte ses temps de
      // pause sur le papier, il faut les compter ici aussi.
      alsoBars: (Bar b) => b.number >= from && b.number <= to,
      title: tout
          ? title
          : from == to
              ? '$title - mesure $from'
              : '$title - mesures $from a $to',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'version': _version,
        'id': id,
        'title': title,
        if (composer != null) 'composer': composer,
        'warnings': warnings,
        'slurredInto': slurredInto.toList(),
        'passage': passageToJson(passage),
      };

  static const int _version = 1;

  /// Relit un morceau range, ou `null` s'il est illisible.
  ///
  /// **Ne leve jamais**, pour la meme raison que `RememberedSession` : un
  /// morceau abime ne doit pas empecher d'ouvrir l'application. On le perd,
  /// les autres restent.
  static ImportedPiece? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? id = json['id'];
    final Object? title = json['title'];
    final Passage? passage = passageFromJson(json['passage']);
    if (id is! String || title is! String || passage == null) {
      return null;
    }
    final Object? composer = json['composer'];
    final Object? warnings = json['warnings'];
    final Object? liees = json['slurredInto'];
    return ImportedPiece(
      id: id,
      title: title,
      composer: composer is String ? composer : null,
      passage: passage,
      warnings: warnings is List<Object?>
          ? <String>[
              for (final Object? w in warnings)
                if (w is String) w
            ]
          : const <String>[],
      slurredInto: liees is List<Object?>
          ? <String>{
              for (final Object? l in liees)
                if (l is String) l
            }
          : const <String>{},
    );
  }
}

/// Un passage mis a plat, tel qu'on le range.
Map<String, Object?> passageToJson(Passage p) => <String, Object?>{
      'title': p.title,
      'ticksPerBeat': p.ticksPerBeat,
      'tempo': p.writtenTempoBpm,
      if (p.meter != null) 'meter': p.meter!.toJson(),
      if (p.keyFifths != null) 'keyFifths': p.keyFifths,
      if (p.bars != null)
        'bars': <Map<String, Object?>>[for (final Bar b in p.bars!) b.toJson()],
      'notes': <Map<String, Object?>>[
        for (final ScoreNote n in p.notes)
          <String, Object?>{
            'id': n.id,
            'midi': n.midi,
            'onset': n.onsetTicks,
            'duration': n.durationTicks,
            'measure': n.measure,
          },
      ],
    };

/// L'inverse de [passageToJson], ou `null` au moindre champ invalide.
Passage? passageFromJson(Object? json) {
  if (json is! Map<String, Object?>) {
    return null;
  }
  final Object? brutes = json['notes'];
  final Object? tpb = json['ticksPerBeat'];
  if (brutes is! List<Object?> || tpb is! int || tpb <= 0) {
    return null;
  }
  final List<ScoreNote> notes = <ScoreNote>[];
  for (final Object? b in brutes) {
    if (b is! Map<String, Object?>) {
      return null;
    }
    final Object? id = b['id'];
    final Object? midi = b['midi'];
    final Object? onset = b['onset'];
    final Object? duree = b['duration'];
    final Object? mesure = b['measure'];
    if (id is! String ||
        midi is! int ||
        onset is! int ||
        duree is! int ||
        duree <= 0 ||
        mesure is! int) {
      return null;
    }
    notes.add(
      ScoreNote(
        id: id,
        midi: midi,
        onsetTicks: onset,
        durationTicks: duree,
        measure: mesure,
      ),
    );
  }
  if (notes.isEmpty) {
    return null;
  }
  final Object? bars = json['bars'];
  final Object? tempo = json['tempo'];
  final Object? fifths = json['keyFifths'];
  final Object? title = json['title'];
  List<Bar>? mesures;
  if (bars is List<Object?>) {
    mesures = <Bar>[];
    for (final Object? b in bars) {
      final Bar? bar = Bar.fromJson(b);
      if (bar == null) {
        return null;
      }
      mesures.add(bar);
    }
  }
  return Passage(
    title: title is String ? title : '',
    notes: notes,
    ticksPerBeat: tpb,
    writtenTempoBpm: tempo is int && tempo > 0 ? tempo : 80,
    meter: Meter.fromJson(json['meter']),
    keyFifths: fifths is int && fifths.abs() <= 7 ? fifths : null,
    bars: mesures,
  );
}
