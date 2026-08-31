/// Horloge de pulsation.
///
/// **Rien n'est accumule.** Le numero de temps et la phase se calculent
/// toujours a partir du temps absolu ecoule depuis le depart. Additionner une
/// duree de temps a chaque battement ferait deriver l'horloge, et sur un
/// metronome la derive s'entend -- ou se voit. C'est la raison d'etre de cette
/// classe : le widget ne fait que passer un `elapsed`, il ne compte rien.
///
/// Dart pur et sans etat : deux appels avec le meme `elapsed` rendent toujours
/// la meme chose, donc les tests n'ont besoin ni d'horloge ni d'attente.
class MetronomeClock {
  const MetronomeClock({required this.tempoBpm, this.beatsPerMeasure = 4})
      : assert(tempoBpm > 0, 'un tempo est strictement positif'),
        assert(beatsPerMeasure > 0, 'une mesure a au moins un temps');

  final int tempoBpm;
  final int beatsPerMeasure;

  static const int _minuteUs = 60 * Duration.microsecondsPerSecond;

  /// Duree d'un temps, **arrondie**, pour l'affichage seulement.
  ///
  /// A 92 bpm un temps vaut 652 173,913 us : aucun entier ne la represente.
  /// Passer par cette duree pour compter les temps ferait deriver l'horloge
  /// d'environ une milliseconde toutes les dix minutes. Les calculs
  /// ci-dessous ne l'utilisent donc pas.
  Duration get beatDuration => Duration(microseconds: _minuteUs ~/ tempoBpm);

  /// Numero du temps depuis le depart, base 0.
  ///
  /// Calcule sur le rationnel exact `elapsed x tempo / 60 s`, sans duree
  /// intermediaire arrondie : le compte reste juste quel que soit le tempo et
  /// quelle que soit la duree de la seance.
  int beatIndexAt(Duration elapsed) {
    if (elapsed <= Duration.zero) {
      return 0;
    }
    return (elapsed.inMicroseconds * tempoBpm) ~/ _minuteUs;
  }

  /// Avancement dans le temps courant, de 0 inclus a 1 exclu.
  double phaseAt(Duration elapsed) {
    if (elapsed <= Duration.zero) {
      return 0;
    }
    return ((elapsed.inMicroseconds * tempoBpm) % _minuteUs) / _minuteUs;
  }

  /// Numero du temps dans la mesure, base 1 : c'est ainsi qu'un musicien
  /// compte, "un, deux, trois, quatre".
  int beatInMeasureAt(Duration elapsed) =>
      beatIndexAt(elapsed) % beatsPerMeasure + 1;

  bool isDownbeatAt(Duration elapsed) => beatInMeasureAt(elapsed) == 1;

  /// Numero de mesure depuis le depart, base 0.
  int measureIndexAt(Duration elapsed) =>
      beatIndexAt(elapsed) ~/ beatsPerMeasure;
}
