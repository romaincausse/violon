/// Ce que vaut une pulsation dans la mesure.
///
/// Un musicien n'entend pas trois pulsations identiques : le premier temps
/// porte la mesure, les autres temps la scandent, les subdivisions ne font que
/// remplir. Les afficher -- ou les jouer -- pareil reviendrait a ne rien dire
/// du metre.
enum PulseAccent {
  /// Premier temps de la mesure.
  downbeat,

  /// Un temps, mais pas le premier.
  beat,

  /// Une subdivision a l'interieur d'un temps.
  subdivision,
}

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
  const MetronomeClock({
    required this.tempoBpm,
    this.beatsPerMeasure = 4,
    this.subdivision = 1,
  })  : assert(tempoBpm > 0, 'un tempo est strictement positif'),
        assert(beatsPerMeasure > 0, 'une mesure a au moins un temps'),
        assert(subdivision > 0, 'un temps se divise au moins en un');

  final int tempoBpm;
  final int beatsPerMeasure;

  /// Pulsations par temps : 1 la noire, 2 les croches, 3 le triolet, 4 les
  /// doubles.
  ///
  /// **En 4e annee, un metronome qui ne subdivise pas ne sert plus a rien des
  /// que le rythme se complique.** On travaille en croches, en triolets, en
  /// doubles -- et c'est justement la que la pulsation aide.
  final int subdivision;

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

  /// Numero de pulsation depuis le depart, base 0, subdivisions comprises.
  ///
  /// Calcule comme le reste sur le rationnel exact, sans duree intermediaire
  /// arrondie : une subdivision de triolet a 92 bpm ne tombe sur aucun entier
  /// de microseconde, et cumuler la ferait deriver.
  int pulseIndexAt(Duration elapsed) {
    if (elapsed <= Duration.zero) {
      return 0;
    }
    return (elapsed.inMicroseconds * tempoBpm * subdivision) ~/ _minuteUs;
  }

  /// Avancement dans la pulsation courante, de 0 inclus a 1 exclu.
  double pulsePhaseAt(Duration elapsed) {
    if (elapsed <= Duration.zero) {
      return 0;
    }
    return ((elapsed.inMicroseconds * tempoBpm * subdivision) % _minuteUs) /
        _minuteUs;
  }

  /// Ce que vaut la pulsation courante dans la mesure.
  PulseAccent accentAt(Duration elapsed) => accentOf(pulseIndexAt(elapsed));

  /// Instant exact de la pulsation [index], comptee depuis le depart.
  ///
  /// C'est la reciproque de [pulseIndexAt], et elle est necessaire des que le
  /// metronome **sonne** : un clic ne se declenche pas quand un minuteur se
  /// reveille, il se planifie a un instant qu'il faut donc savoir nommer.
  ///
  /// Meme arithmetique que partout ici : on multiplie d'abord, on divise
  /// ensuite, et on ne cumule rien. La millieme pulsation est aussi juste que
  /// la premiere.
  Duration pulseTime(int index) => Duration(
        microseconds: index * _minuteUs ~/ (tempoBpm * subdivision),
      );

  /// Ce que vaut la pulsation [index] dans la mesure.
  PulseAccent accentOf(int index) {
    if (index % subdivision != 0) {
      return PulseAccent.subdivision;
    }
    return (index ~/ subdivision) % beatsPerMeasure == 0
        ? PulseAccent.downbeat
        : PulseAccent.beat;
  }
}
