import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/violin_synth.dart';
import '../music/passage.dart';
import '../music/score_note.dart';

/// Une note jouee dans une prise de synthese : le son, et ce qu'il visait.
class PlayedNote {
  const PlayedNote({
    required this.sound,
    required this.noteId,
    required this.wrong,
  });

  final BowedNote sound;

  /// Note de la partition que l'eleve visait. Nul pour une note qui ne
  /// correspond a rien : ajoutee, essai de doigt.
  final String? noteId;

  /// Jouee au bon endroit, mais pas a la bonne hauteur.
  final bool wrong;

  /// L'etiquette que l'annotateur aurait posee, dans la syntaxe du protocole
  /// (`docs/banc-d-essai.md`).
  String get label => switch (noteId) {
        null => 'x',
        final String id when wrong => '$id faux',
        final String id => id,
      };
}

/// Une prise de synthese : ce qui a ete joue, dans l'ordre, et sa duree.
///
/// **Sa raison d'etre est la verite terrain gratuite.** Une vraie prise coute
/// une demi-heure d'annotation par minute de jeu ; celle-ci sait deja, note par
/// note, ce que l'eleve visait. Et elle la rend au **format exact** des vraies
/// prises, pour que l'aligneur les lise avec le meme code.
class SyntheticTake {
  SyntheticTake({required this.notes, required this.length});

  final List<PlayedNote> notes;
  final Duration length;

  /// Un silence plus long que celui-ci est un arret, et s'annote comme tel.
  static const Duration stopThreshold = Duration(seconds: 1);

  Float32List render(ViolinSynth synth) => synth.render(
        <BowedNote>[for (final PlayedNote n in notes) n.sound],
        length: length,
      );

  /// Les etiquettes au format d'export d'Audacity : une ligne par etiquette,
  /// debut et fin en secondes, separes par des tabulations.
  ///
  /// Une etiquette ponctuelle au debut de chaque note jouee, et une region
  /// `arret` du dernier son au suivant quand le silence depasse une seconde --
  /// exactement ce que le protocole demande a l'annotateur.
  String audacityLabels() {
    final StringBuffer sortie = StringBuffer();
    void etiquette(Duration debut, Duration fin, String texte) {
      sortie.writeln('${_secondes(debut)}\t${_secondes(fin)}\t$texte');
    }

    for (int i = 0; i < notes.length; i++) {
      final PlayedNote note = notes[i];
      if (i > 0) {
        final Duration finPrecedente = notes[i - 1].sound.end;
        if (note.sound.start - finPrecedente > stopThreshold) {
          etiquette(finPrecedente, note.sound.start, 'arret');
        }
      }
      etiquette(note.sound.start, note.sound.start, note.label);
    }
    return sortie.toString();
  }

  static String _secondes(Duration d) =>
      (d.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(6);
}

/// Scenario d'une prise : ce que l'eleve joue, dans l'ordre ou il le joue.
///
/// Un enfant qui travaille ne joue pas du debut a la fin : il s'arrete,
/// reprend la mesure, saute, se trompe. Le scenario s'ecrit donc comme on
/// raconterait la prise, et non comme une partition :
///
/// ```dart
/// final TakeScript prise = TakeScript(passage, tempoBpm: 74)
///   ..play('n1', 'n8')
///   ..pause(const Duration(seconds: 2))
///   ..play('n5', 'n12', centsOff: <String, double>{'n10': 70});
/// ```
///
/// Tout ce qui varie d'une note a l'autre -- un rythme jamais parfaitement
/// regulier, une justesse jamais parfaitement exacte -- est tire d'une
/// [seed] : deux prises du meme scenario sont identiques a l'echantillon pres.
class TakeScript {
  TakeScript(
    this.passage, {
    int? tempoBpm,
    this.seed = 0,
    this.timingJitter = const Duration(milliseconds: 15),
    this.intonationSpreadCents = 6,
    this.vibratoCents = 0,
    this.amplitude = 0.3,
    Duration leadIn = const Duration(seconds: 1),
  })  : _tempoBpm = tempoBpm ?? passage.writtenTempoBpm,
        _hasard = math.Random(seed),
        _now = leadIn;

  final Passage passage;
  final int seed;

  /// Ecart maximal, dans un sens ou dans l'autre, sur la duree de chaque note.
  /// Personne ne joue exactement en mesure, pas meme un professionnel.
  final Duration timingJitter;

  /// Ecart maximal de justesse, en cents, sur une note jouee "juste". Reste
  /// bien en dessous du demi-ton : c'est l'imprecision de tous les jours, pas
  /// une fausse note -- celles-la passent par `centsOff`.
  final double intonationSpreadCents;

  /// Vibrato par defaut, en cents.
  final double vibratoCents;

  final double amplitude;

  final math.Random _hasard;
  final List<PlayedNote> _jouees = <PlayedNote>[];
  int _tempoBpm;
  Duration _now;

  /// Une note trop breve n'est plus une note, c'est un accident.
  static const Duration _shortest = Duration(milliseconds: 60);

  /// Change le tempo pour la suite de la prise : un enfant qui ralentit sur
  /// le passage difficile.
  void tempo(int bpm) {
    if (bpm <= 0) {
      throw ArgumentError.value(bpm, 'bpm', 'un tempo est strictement positif');
    }
    _tempoBpm = bpm;
  }

  /// Joue les notes de [from] a [to] inclus, dans l'ordre de la partition.
  ///
  /// - [slurred] : toutes sous le meme archet, seule la premiere attaque ;
  /// - [centsOff] : ecart volontaire par note, en cents. A partir d'un
  ///   demi-demi-ton, la note est fausse et s'annote comme telle ;
  /// - [skip] : notes sautees. Le temps ne s'arrete pas pour elles : l'eleve
  ///   enchaine sur la suivante ;
  /// - [vibratoCents] : remplace le vibrato par defaut sur ce fragment.
  void play(
    String from,
    String to, {
    bool slurred = false,
    Map<String, double> centsOff = const <String, double>{},
    Set<String> skip = const <String>{},
    double? vibratoCents,
  }) {
    final int debut = _indexOf(from);
    final int fin = _indexOf(to);
    if (fin < debut) {
      throw ArgumentError('$to vient avant $from dans la partition');
    }
    bool premiere = true;
    for (int i = debut; i <= fin; i++) {
      final ScoreNote note = passage.notes[i];
      if (skip.contains(note.id)) {
        continue;
      }
      final double ecart =
          (_hasard.nextDouble() * 2 - 1) * intonationSpreadCents +
              (centsOff[note.id] ?? 0);
      final double midi = note.midi + ecart / 100;
      _sonner(
        midi: midi,
        duree: _dureeDe(note),
        attack: premiere || !slurred,
        vibrato: vibratoCents ?? this.vibratoCents,
        noteId: note.id,
        wrong: midi.round() != note.midi,
      );
      premiere = false;
    }
  }

  /// Une note qui n'est pas dans la partition : un essai de doigt, une note
  /// ajoutee. Elle s'annote `x`.
  void extra(int midi,
      {Duration duration = const Duration(milliseconds: 300)}) {
    _sonner(
      midi: midi.toDouble(),
      duree: duration,
      attack: true,
      vibrato: 0,
      noteId: null,
      wrong: false,
    );
  }

  /// Un silence : l'archet leve, l'enfant relit, se reprend.
  void pause(Duration duration) {
    _now += duration;
  }

  /// La prise, avec [tail] de silence apres la derniere note -- le protocole
  /// en demande une seconde avant et apres chaque prise.
  SyntheticTake build({Duration tail = const Duration(seconds: 1)}) =>
      SyntheticTake(
        notes: List<PlayedNote>.unmodifiable(_jouees),
        length: _now + tail,
      );

  void _sonner({
    required double midi,
    required Duration duree,
    required bool attack,
    required double vibrato,
    required String? noteId,
    required bool wrong,
  }) {
    _jouees.add(
      PlayedNote(
        sound: BowedNote(
          start: _now,
          duration: duree,
          midi: midi,
          attack: attack,
          vibratoCents: vibrato,
          amplitude: amplitude,
        ),
        noteId: noteId,
        wrong: wrong,
      ),
    );
    // La note suivante commence exactement ou celle-ci finit : c'est ce qui
    // rend une liaison continue. L'espace entre deux coups d'archet detaches
    // vient de l'enveloppe de chaque note, pas d'un trou dans le temps.
    _now += duree;
  }

  Duration _dureeDe(ScoreNote note) {
    final int nominale = note.durationTicks *
        60 *
        Duration.microsecondsPerSecond ~/
        (passage.ticksPerBeat * _tempoBpm);
    final int jeu = timingJitter.inMicroseconds;
    final int ecart = jeu == 0 ? 0 : _hasard.nextInt(2 * jeu + 1) - jeu;
    return Duration(
      microseconds: math.max(_shortest.inMicroseconds, nominale + ecart),
    );
  }

  int _indexOf(String id) {
    final int i = passage.notes.indexWhere((ScoreNote n) => n.id == id);
    if (i < 0) {
      throw ArgumentError.value(id, 'id', 'absente de la partition');
    }
    return i;
  }
}
