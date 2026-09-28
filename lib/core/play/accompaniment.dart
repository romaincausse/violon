import '../music/passage.dart';
import '../music/score_note.dart';

/// Une note de l'accompagnement, dans le temps du passage.
///
/// Meme unite que [ScoreNote] -- des ticks, depuis le debut du morceau --
/// pour que l'accompagnement se cale sur la partition sans conversion : la
/// mesure 15 de l'accompagnement est la mesure 15 du violon.
class AccompanimentNote {
  const AccompanimentNote({
    required this.midi,
    required this.onsetTicks,
    required this.durationTicks,
    this.velocity = 1,
  });

  final int midi;
  final int onsetTicks;
  final int durationTicks;

  /// Force relative, de 0 a 1 : une basse et un accord ne sonnent pas aussi
  /// fort qu'une melodie.
  final double velocity;

  int get offsetTicks => onsetTicks + durationTicks;

  Map<String, Object?> toJson() => <String, Object?>{
        'midi': midi,
        'onset': onsetTicks,
        'duration': durationTicks,
        if (velocity != 1) 'velocity': velocity,
      };

  static AccompanimentNote? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? midi = json['midi'];
    final Object? onset = json['onset'];
    final Object? duree = json['duration'];
    final Object? force = json['velocity'];
    if (midi is! int || onset is! int || duree is! int || duree <= 0) {
      return null;
    }
    return AccompanimentNote(
      midi: midi,
      onsetTicks: onset,
      durationTicks: duree,
      velocity: force is num ? force.toDouble().clamp(0, 1) : 1,
    );
  }

  @override
  String toString() => 'AccompanimentNote($midi @ $onsetTicks +$durationTicks)';
}

/// Ce que joue l'accompagnement. C'est l'eleve qui choisit.
enum AccompanimentSource {
  /// Le passage lui-meme, pour l'entendre et se caler dessus. Le plus sur :
  /// c'est exactement ce qui est ecrit.
  melody,

  /// L'accompagnement ecrit dans le fichier importe -- la partie de piano,
  /// le plus souvent. Juste par construction, quand il existe.
  score,

  /// Une basse et des accords deduits de la melodie. Marche partout, et se
  /// trompe parfois : c'est une proposition d'harmonie, pas celle du
  /// compositeur.
  chords,
}

/// La melodie du passage, telle qu'ecrite.
List<AccompanimentNote> melodyOf(Passage passage) => <AccompanimentNote>[
      for (final ScoreNote n in passage.notes)
        AccompanimentNote(
          midi: n.midi,
          onsetTicks: n.onsetTicks,
          durationTicks: n.durationTicks,
        ),
    ];

/// Les notes d'un accompagnement qui tombent dans [debut, fin[, recoupees
/// aux bords : un accord tenu depuis la mesure precedente sonne encore au
/// debut du passage.
List<AccompanimentNote> clipTo(
  List<AccompanimentNote> notes,
  int debut,
  int fin,
) =>
    <AccompanimentNote>[
      for (final AccompanimentNote n in notes)
        if (n.offsetTicks > debut && n.onsetTicks < fin)
          AccompanimentNote(
            midi: n.midi,
            onsetTicks: n.onsetTicks < debut ? debut : n.onsetTicks,
            durationTicks: (n.offsetTicks > fin ? fin : n.offsetTicks) -
                (n.onsetTicks < debut ? debut : n.onsetTicks),
            velocity: n.velocity,
          ),
    ];
