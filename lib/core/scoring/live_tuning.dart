import '../audio/pitch_estimate.dart';
import '../music/pitch_utils.dart';
import '../music/score_note.dart';

/// Ce que l'application a a dire d'une note, pendant qu'elle est jouee.
///
/// Trois verdicts et pas un de plus : a ce stade on ne montre aucun chiffre,
/// seulement une couleur. Un ecart mesure en cents viendra au lot N1, une
/// fois l'attaque exclue et le vibrato lisse.
enum TuningVerdict {
  /// Pas encore assez de son pour se prononcer. Ce n'est pas un echec : c'est
  /// l'etat normal au debut de chaque note, et celui d'un silence.
  unknown,

  low,
  inTune,
  high,
}

/// Justesse en direct, note par note.
///
/// **Contre la note attendue, pas contre la note la plus proche.** Comparer a
/// la note temperee voisine dirait "juste" a un enfant qui joue un demi-ton
/// a cote : il serait parfaitement juste sur la mauvaise note.
///
/// **La mediane, pas la moyenne.** Le vibrato fait osciller la hauteur de 20 a
/// 50 cents volontairement. Une moyenne s'en accommode a peu pres, mais
/// l'attaque -- ou la hauteur glisse sur une centaine de cents en quelques
/// dizaines de millisecondes -- la tirerait franchement. La mediane ignore
/// les deux.
class LiveTuning {
  LiveTuning({
    this.toleranceCents = 35,
    this.minConfidence = 0.7,
    this.minSamples = 2,
    this.attackMs = 80,
    this.a4 = PitchUtils.defaultA4,
  })  : assert(toleranceCents > 0, 'une tolerance est strictement positive'),
        assert(minSamples > 0, 'il faut au moins une mesure'),
        assert(attackMs >= 0, 'une duree d attaque n est pas negative');

  /// Au-dela, la note est dite basse ou haute.
  ///
  /// Genereux a dessein. Le projet dit qu'une partition rouge partout est une
  /// regression : mieux vaut ne rien dire que decourager sur un ecart qu'une
  /// oreille de professeur laisserait passer.
  final double toleranceCents;

  /// En dessous, YIN n'a probablement pas entendu une note tenue : changement
  /// d'archet, silence, ou bruit de la piece.
  final double minConfidence;

  /// Mesures necessaires avant d'oser un verdict. Deux trames font une
  /// centaine de millisecondes : de quoi laisser passer l'attaque sans
  /// attendre la fin de la note.
  final int minSamples;

  /// Debut de note ignore, en millisecondes.
  ///
  /// **L'attaque n'est pas la note.** Pendant qu'un archet se pose, la
  /// hauteur glisse sur des dizaines de cents avant de se fixer : c'est
  /// inevitable, meme chez un professionnel, et le compter reviendrait a
  /// reprocher a l'enfant la physique de son instrument.
  ///
  /// Quatre-vingts millisecondes valent moins d'une double croche a 92 a la
  /// noire : meme sur les notes les plus breves, il reste de quoi juger.
  final int attackMs;

  /// Diapason de reference.
  ///
  /// La justesse se juge par rapport a l'accord reel de l'instrument, pas a
  /// une reference absolue : 440 n'est qu'un repli tant que l'accordeur (lot
  /// A6) n'a pas mesure la vraie valeur.
  final double a4;

  final Map<String, List<double>> _ecarts = <String, List<double>>{};

  /// Enregistre ce qui a ete entendu pendant que [note] etait attendue.
  ///
  /// [sinceNoteStartMs] dit depuis combien de temps la note a commence, pour
  /// que l'attaque soit ecartee. Sans cette information, tout est retenu.
  void observe(
    ScoreNote note,
    PitchEstimate estimate, {
    int? sinceNoteStartMs,
  }) {
    if (estimate.confidence < minConfidence) {
      return;
    }
    if (sinceNoteStartMs != null && sinceNoteStartMs < attackMs) {
      return;
    }
    final double attendue = PitchUtils.midiToFrequency(note.midi, a4: a4);
    _ecarts
        .putIfAbsent(note.id, () => <double>[])
        .add(PitchUtils.centsBetween(estimate.frequencyHz, attendue));
  }

  /// Ecart median a la note attendue, ou `null` faute de mesures.
  double? medianCentsFor(String noteId) {
    final List<double>? mesures = _ecarts[noteId];
    if (mesures == null || mesures.length < minSamples) {
      return null;
    }
    final List<double> triees = List<double>.of(mesures)..sort();
    final int milieu = triees.length ~/ 2;
    return triees.length.isOdd
        ? triees[milieu]
        : (triees[milieu - 1] + triees[milieu]) / 2;
  }

  TuningVerdict verdictFor(String noteId) {
    final double? cents = medianCentsFor(noteId);
    if (cents == null) {
      return TuningVerdict.unknown;
    }
    if (cents.abs() <= toleranceCents) {
      return TuningVerdict.inTune;
    }
    return cents < 0 ? TuningVerdict.low : TuningVerdict.high;
  }

  /// Mesures retenues pour une note. Sert a savoir si elle a ete entendue.
  int sampleCountFor(String noteId) => _ecarts[noteId]?.length ?? 0;

  /// Note de justesse sur cent, ou `null` faute de mesures.
  ///
  /// **La courbe est genereuse, et c'est un choix.** Cent jusqu'a dix cents
  /// d'ecart -- au-dela de ce que l'oreille distingue sur une note isolee --
  /// puis une descente reguliere jusqu'a zero au demi-ton, la ou ce n'est
  /// plus la meme note. Une courbe severe donnerait des scores humiliants a
  /// un enfant qui joue correctement, et le projet montre des donnees qui
  /// montent, pas des reproches.
  int? scoreFor(String noteId) {
    final double? cents = medianCentsFor(noteId);
    if (cents == null) {
      return null;
    }
    return noteScoreForCents(cents);
  }

  /// Ecart parfait au-dela duquel la note commence a perdre des points.
  static const double perfectCents = 10;

  /// Ecart a partir duquel la note vaut zero : un demi-ton, soit une autre
  /// note.
  static const double worstCents = 100;

  /// Convertit un ecart en cents en note sur cent.
  static int noteScoreForCents(double cents) {
    final double ecart = cents.abs();
    if (ecart <= perfectCents) {
      return 100;
    }
    if (ecart >= worstCents) {
      return 0;
    }
    final double part = (ecart - perfectCents) / (worstCents - perfectCents);
    return (100 * (1 - part)).round();
  }

  /// Note d'ensemble du passage : moyenne des notes obtenues.
  ///
  /// Les notes qui n'ont pas ete entendues ne comptent pas. Les compter pour
  /// zero punirait un silence, un archet rate ou un micro trop loin comme une
  /// fausse note.
  int? get overallScore {
    final List<int> notes = <int>[
      for (final String id in _ecarts.keys)
        if (scoreFor(id) != null) scoreFor(id)!,
    ];
    if (notes.isEmpty) {
      return null;
    }
    return (notes.reduce((int a, int b) => a + b) / notes.length).round();
  }

  /// Identifiants des notes effectivement entendues.
  Iterable<String> get heardNoteIds =>
      _ecarts.keys.where((String id) => scoreFor(id) != null);

  /// La note la moins bien reussie, ou `null` si rien n'a ete entendu.
  ///
  /// **C'est la prochaine tache, pas la liste des echecs.** Le projet dit que
  /// l'application montre ce qu'il y a a travailler, pas tout ce qui a rate :
  /// une seule note designee vaut mieux qu'un bilan qui accable.
  ///
  /// En cas d'egalite, la premiere dans l'ordre d'ecoute : on travaille le
  /// passage dans le sens ou on le joue.
  String? get weakestNoteId {
    String? pire;
    int meilleurScore = 101;
    for (final String id in heardNoteIds) {
      final int score = scoreFor(id)!;
      if (score < meilleurScore) {
        meilleurScore = score;
        pire = id;
      }
    }
    return pire;
  }

  /// Oublie tout : a appeler a chaque nouveau passage sur le morceau.
  void reset() => _ecarts.clear();
}
