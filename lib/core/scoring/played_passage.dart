import '../music/passage.dart';
import '../music/score_note.dart';
import 'live_tuning.dart';

/// Une note ecrite, et ce qui a ete entendu a sa place.
class PlayedNote {
  const PlayedNote({
    required this.written,
    required this.midi,
    required this.medianCents,
  });

  /// La note telle qu'elle est imprimee sur le papier.
  final ScoreNote written;

  /// Hauteur a graver, arrondie au demi-ton.
  ///
  /// **Arrondie, et c'est tout l'interet.** Un ecart de trente cents n'est pas
  /// une autre note : c'est la meme, jouee un peu bas, et la deplacer dirait
  /// faux. La tete ne bouge donc que lorsque ce qui a ete entendu est
  /// reellement une autre note -- ce que le ruban d'ecart, lui, ne dit pas.
  final int midi;

  /// Ecart median a la note ecrite, ou `null` si la note n'a pas ete entendue.
  final double? medianCents;

  bool get heard => medianCents != null;

  /// Vrai quand ce qui a ete entendu n'est pas ce qui etait ecrit.
  bool get moved => midi != written.midi;

  /// La note a graver : meme identifiant, meme rythme, meme mesure.
  ScoreNote get note => moved ? written.copyWith(midi: midi) : written;
}

/// Le passage tel qu'il a ete joue, pret a etre grave.
///
/// **Le rythme ecrit est conserve, seules les hauteurs changent.** Chaque note
/// garde son identifiant, son instant et sa duree : ce qui bouge, c'est la
/// tete. L'application sait ou l'eleve etait cense se trouver et ce qu'elle a
/// entendu la ; elle ne sait pas encore ce qu'il a joue *en trop* ni ce qu'il a
/// saute, parce que ca demande le suiveur (jalon 6) et le juge de rythme
/// (jalon 7).
///
/// C'est donc une reponse partielle, et il faut la dire ainsi : *voila ce que
/// tu as joue la ou une note etait attendue*. C'est deja ce qu'un professeur
/// montre du doigt en premier.
class PlayedPassage {
  PlayedPassage._({required this.passage, required this.notes})
      : _parId = <String, PlayedNote>{
          for (final PlayedNote note in notes) note.written.id: note,
        };

  /// Ce qu'il faut graver : memes rythmes, hauteurs entendues.
  final Passage passage;

  /// Les notes du passage, dans l'ordre ou elles sont ecrites.
  final List<PlayedNote> notes;

  final Map<String, PlayedNote> _parId;

  PlayedNote? byId(String id) => _parId[id];

  int get heardCount => notes.where((PlayedNote n) => n.heard).length;

  /// Combien de tetes ont change de place.
  int get movedCount => notes.where((PlayedNote n) => n.moved).length;

  /// Au-dela, on ne pretend pas savoir ce qui a ete joue.
  ///
  /// **Une octave, parce que c'est l'erreur classique de YIN.** Un detecteur de
  /// hauteur se trompe d'octave, et ce projet n'a pas encore de suiveur : quand
  /// le curseur se trompe de note attendue, l'ecart mesure peut valoir
  /// n'importe quoi. Dans les deux cas, ce n'est pas l'enfant qui a joue une
  /// autre note -- c'est nous qui ne savons pas. Graver une tete a une octave
  /// de la sienne serait alors une affirmation fausse, et elle ferait au
  /// passage retrecir toute la portee pour loger ses lignes supplementaires.
  ///
  /// La note est donc rendue **non entendue** plutot que deplacee : c'est
  /// exactement ce que l'application sait.
  static const int maxShiftSemitones = 12;
}

/// Ce qui a ete entendu, remis sur la portee a la place de ce qui etait ecrit.
///
/// La hauteur retenue est la **mediane** de ce qui a ete entendu pendant la
/// note, celle-la meme qui sert a la noter : le vibrato et l'attaque en sont
/// donc deja ecartes.
PlayedPassage playedPassage(
  Passage written,
  LiveTuning tuning, {
  int maxShiftSemitones = PlayedPassage.maxShiftSemitones,
}) {
  final List<PlayedNote> joues = <PlayedNote>[];
  for (final ScoreNote note in written.notes) {
    final double? cents = tuning.medianCentsFor(note.id);
    int decalage = 0;
    double? retenu = cents;
    if (cents != null) {
      decalage = (cents / 100).round();
      if (decalage.abs() >= maxShiftSemitones) {
        decalage = 0;
        retenu = null;
      }
    }
    joues.add(
      PlayedNote(
        written: note,
        midi: note.midi + decalage,
        medianCents: retenu,
      ),
    );
  }
  return PlayedPassage._(
    passage: Passage(
      title: written.title,
      notes: <ScoreNote>[for (final PlayedNote joue in joues) joue.note],
      ticksPerBeat: written.ticksPerBeat,
      writtenTempoBpm: written.writtenTempoBpm,
    ),
    notes: joues,
  );
}
