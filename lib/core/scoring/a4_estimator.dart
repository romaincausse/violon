import '../audio/pitch_smoother.dart';
import '../music/pitch_utils.dart';
import 'tuner.dart';

/// Mesure le diapason reel de l'instrument, et ne le rend qu'une fois sur.
///
/// **Une seule trame ne suffit pas, et c'est un vrai piege.** Le bruit d'une
/// piece produit reguliers des mesures que YIN juge fiables et que le lisseur
/// juge stables : sur un appareil pose sur une table, l'accordeur proposait
/// d'adopter un diapason alors que personne ne jouait. Or ce chiffre change
/// la facon dont **toutes** les notes sont ensuite jugees : il ne se decide
/// pas sur un hasard.
///
/// D'ou l'exigence d'une serie : plusieurs mesures d'affilee, toutes sur le
/// la, toutes stables, et toutes d'accord entre elles. Une corde tenue quatre
/// dixiemes de seconde y arrive sans effort ; un bruit de piece, non.
class A4Estimator {
  A4Estimator({
    Tuner? tuner,
    this.confirmations = 6,
    this.spreadCents = 10,
  })  : _tuner = tuner ?? Tuner(),
        assert(confirmations > 1, 'une seule mesure ne confirme rien'),
        assert(spreadCents > 0, 'la dispersion doit etre positive');

  final Tuner _tuner;

  /// Mesures consecutives exigees. Six trames font moins de trois dixiemes de
  /// seconde : une corde tenue les donne sans effort.
  final int confirmations;

  /// Dispersion maximale toleree dans la serie. Au-dela, ce n'est pas une
  /// corde tenue, c'est une suite de hasards.
  final double spreadCents;

  final List<double> _serie = <double>[];
  double? _confirme;

  /// Diapason confirme, ou `null` tant qu'aucune serie n'a abouti.
  double? get confirmed => _confirme;

  /// Ajoute une mesure et rend le diapason confirme, s'il vient de l'etre.
  double? add(SmoothedPitch pitch) {
    final double? mesure = _tuner.measuredA4From(pitch);
    if (mesure == null) {
      _serie.clear();
      return null;
    }
    // La serie doit rester groupee : une mesure qui s'ecarte recommence tout,
    // sans quoi une derive lente finirait par confirmer n'importe quoi.
    if (_serie.isNotEmpty &&
        PitchUtils.centsBetween(mesure, _serie.first).abs() > spreadCents) {
      _serie
        ..clear()
        ..add(mesure);
      return null;
    }
    _serie.add(mesure);
    if (_serie.length < confirmations) {
      return null;
    }
    _confirme = _mediane(_serie);
    return _confirme;
  }

  static double _mediane(List<double> valeurs) {
    final List<double> triees = List<double>.of(valeurs)..sort();
    final int milieu = triees.length ~/ 2;
    return triees.length.isOdd
        ? triees[milieu]
        : (triees[milieu - 1] + triees[milieu]) / 2;
  }

  /// Oublie tout : a appeler entre deux accordages.
  void reset() {
    _serie.clear();
    _confirme = null;
  }
}
