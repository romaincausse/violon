import 'dart:math' as math;

import '../music/pitch_utils.dart';
import 'pitch_estimate.dart';

/// Hauteur lissee, avec ce qu'on a appris de sa stabilite.
class SmoothedPitch {
  const SmoothedPitch({
    required this.estimate,
    required this.excursionCents,
    required this.vibrato,
  });

  /// La hauteur retenue : mediane des dernieres mesures de la meme note.
  final PitchEstimate estimate;

  /// Amplitude crete a crete des mesures recentes, en cents. Zero tant qu'il
  /// n'y a pas de quoi juger.
  final double excursionCents;

  /// L'oscillation ressemble-t-elle a un vibrato voulu ?
  final bool vibrato;

  double get frequencyHz => estimate.frequencyHz;
  int get timestampMs => estimate.timestampMs;
}

/// Lisse le flux de hauteurs, et reconnait un vibrato.
///
/// **Une mediane, pas une moyenne.** YIN se trompe parfois d'octave sur une
/// trame isolee. Une moyenne deplacerait la hauteur de plusieurs centaines de
/// cents ; une mediane ignore la valeur aberrante.
///
/// **La mediane ne franchit pas les notes.** Une fenetre de trois trames dure
/// 138 ms, alors qu'une double croche a 120 a la noire n'en dure que 125.
/// Lisser a travers un changement de note produirait une hauteur qui n'a
/// jamais ete jouee, pile entre les deux. D'ou la remise a zero des qu'un
/// saut depasse [jumpCents] : un grand ecart n'est pas du bruit, c'est une
/// note suivante.
class PitchSmoother {
  PitchSmoother({
    this.windowSize = 3,
    this.vibratoWindow = 15,
    this.jumpCents = 80,
    this.minVibratoCents = 15,
    this.maxVibratoCents = 150,
    this.minAlternations = 4,
  })  : assert(windowSize > 0, 'la fenetre doit etre non vide'),
        assert(vibratoWindow > 2, 'il faut de quoi voir une oscillation');

  /// Mesures sur lesquelles porte la mediane.
  final int windowSize;

  /// Mesures sur lesquelles on cherche une oscillation. Quinze trames font
  /// 690 ms, soit trois a cinq periodes d'un vibrato de violon.
  final int vibratoWindow;

  /// Au-dela de cet ecart avec la mediane courante, on considere qu'une
  /// nouvelle note commence et on oublie l'historique.
  ///
  /// **La marge est etroite, et c'est inevitable.** Le seuil doit passer
  /// au-dessus du vibrato le plus large -- une cinquantaine de cents de part
  /// et d'autre du centre -- et rester sous le plus petit intervalle
  /// melodique, le demi-ton, qui vaut cent cents. Quatre-vingts se tient
  /// entre les deux.
  ///
  /// Le placer au-dessus de cent, comme on serait tente de le faire pour
  /// etre large, aurait l'effet inverse de celui recherche : un vrai
  /// changement de note ne remettrait plus rien a zero, et la premiere trame
  /// de chaque note serait tiree vers la precedente.
  final double jumpCents;

  /// En dessous, l'oscillation est du bruit de mesure, pas un vibrato.
  final double minVibratoCents;

  /// Au-dela, ce n'est plus un vibrato mais une hesitation ou un glissando.
  final double maxVibratoCents;

  /// Alternances minimales autour de la mediane pour parler d'oscillation.
  ///
  /// **La cadence d'analyse limite ce qu'on peut voir.** Une trame toutes les
  /// 46 ms echantillonne a 21,5 Hz, donc au mieux 10 Hz d'oscillation. Un
  /// vibrato de violon bat entre 5 et 7 Hz : on le voit, mais de justesse.
  /// Ce detecteur dit "ca oscille", il ne mesure pas une frequence.
  final int minAlternations;

  final List<PitchEstimate> _recentes = <PitchEstimate>[];

  /// Mesure isolee deja sortie de la fourchette, en attente de confirmation.
  PitchEstimate? _suspecte;
  int _sensDeLaSuspecte = 0;

  /// Ajoute une mesure et rend la hauteur lissee correspondante.
  SmoothedPitch add(PitchEstimate estimate) {
    _reagirAuxGrandsEcarts(estimate);
    _recentes.add(estimate);
    while (_recentes.length > vibratoWindow) {
      _recentes.removeAt(0);
    }

    final double mediane = _medianeDes(_recentes, windowSize)!;
    return SmoothedPitch(
      estimate: PitchEstimate(
        frequencyHz: mediane,
        confidence: estimate.confidence,
        timestampMs: estimate.timestampMs,
      ),
      excursionCents: _excursion(),
      vibrato: _estUnVibrato(),
    );
  }

  /// Decide si un grand ecart signale une nouvelle note, et oublie alors
  /// l'historique.
  ///
  /// **Il en faut deux de suite, dans le meme sens.** Un vibrato de plus ou
  /// moins cinquante cents saute de cent cents d'une trame a l'autre, soit
  /// exactement l'ecart d'un demi-ton : sur une seule mesure, les deux sont
  /// indiscernables. Mais un vibrato repart aussitot dans l'autre sens, la ou
  /// une note nouvelle reste ou elle est. Deux mesures suffisent donc a
  /// trancher, au prix d'une trame de retard.
  void _reagirAuxGrandsEcarts(PitchEstimate estimate) {
    final double? mediane = _medianeDes(_recentes, windowSize);
    if (mediane == null) {
      return;
    }
    final double ecart = PitchUtils.centsBetween(estimate.frequencyHz, mediane);
    if (ecart.abs() <= jumpCents) {
      _suspecte = null;
      _sensDeLaSuspecte = 0;
      return;
    }
    final int sens = ecart > 0 ? 1 : -1;
    if (_suspecte != null && sens == _sensDeLaSuspecte) {
      // Confirmee : on repart de la suspecte, qui appartient deja a la note
      // nouvelle. La jeter perdrait la premiere trame de chaque note.
      _recentes
        ..clear()
        ..add(_suspecte!);
      _suspecte = null;
      _sensDeLaSuspecte = 0;
      return;
    }
    _suspecte = estimate;
    _sensDeLaSuspecte = sens;
  }

  /// Mediane des [combien] dernieres mesures, ou `null` s'il n'y en a aucune.
  static double? _medianeDes(List<PitchEstimate> mesures, int combien) {
    if (mesures.isEmpty) {
      return null;
    }
    final int debut = math.max(0, mesures.length - combien);
    final List<double> valeurs = <double>[
      for (int i = debut; i < mesures.length; i++) mesures[i].frequencyHz,
    ]..sort();
    final int milieu = valeurs.length ~/ 2;
    return valeurs.length.isOdd
        ? valeurs[milieu]
        : (valeurs[milieu - 1] + valeurs[milieu]) / 2;
  }

  /// Ecart crete a crete des mesures retenues, en cents.
  double _excursion() {
    if (_recentes.length < 3) {
      return 0;
    }
    double mini = _recentes.first.frequencyHz;
    double maxi = mini;
    for (final PitchEstimate e in _recentes) {
      mini = math.min(mini, e.frequencyHz);
      maxi = math.max(maxi, e.frequencyHz);
    }
    return PitchUtils.centsBetween(maxi, mini);
  }

  /// Compte les passages de part et d'autre de la mediane de la fenetre.
  ///
  /// Un vibrato traverse sa hauteur centrale a chaque demi-periode ; une note
  /// qui derive lentement ne la traverse qu'une fois.
  bool _estUnVibrato() {
    if (_recentes.length < vibratoWindow) {
      return false;
    }
    final double excursion = _excursion();
    if (excursion < minVibratoCents || excursion > maxVibratoCents) {
      return false;
    }
    final double centre = _medianeDes(_recentes, _recentes.length)!;
    int alternances = 0;
    int? signePrecedent;
    for (final PitchEstimate e in _recentes) {
      final double ecart = e.frequencyHz - centre;
      if (ecart == 0) {
        continue;
      }
      final int signe = ecart > 0 ? 1 : -1;
      if (signePrecedent != null && signe != signePrecedent) {
        alternances++;
      }
      signePrecedent = signe;
    }
    return alternances >= minAlternations;
  }

  /// Oublie tout : a appeler entre deux prises.
  void reset() {
    _recentes.clear();
    _suspecte = null;
    _sensDeLaSuspecte = 0;
  }
}
