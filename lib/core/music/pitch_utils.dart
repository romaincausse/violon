import 'dart:math' as math;

/// Conversions hauteur <-> frequence, et mesure d'ecart en cents.
///
/// Toute la justesse de l'application repose sur ces quelques fonctions :
/// elles sont donc pures, sans dependance, et couvertes par des tests.
class PitchUtils {
  const PitchUtils._();

  /// Diapason par defaut, en Hz.
  ///
  /// 440 est la reference internationale, mais beaucoup de conservatoires et
  /// d'orchestres francais accordent a 442 : l'ecart vaut environ 8 cents,
  /// soit largement de quoi declarer faux un enfant parfaitement juste.
  ///
  /// D'ou le parametre nomme `a4` sur toutes les fonctions de ce fichier :
  /// cette constante n'est qu'un repli, la valeur qui compte est celle de
  /// l'accord reel de l'instrument (voir la regle de justesse relative dans
  /// CLAUDE.md).
  static const double defaultA4 = 440.0;

  static const List<String> _noteNames = <String>[
    'Do',
    'Do#',
    'Re',
    'Re#',
    'Mi',
    'Fa',
    'Fa#',
    'Sol',
    'Sol#',
    'La',
    'La#',
    'Si',
  ];

  /// Les quatre cordes a vide du violon, du grave a l'aigu : sol3, re4, la4, mi5.
  static const List<int> violinOpenStrings = <int>[55, 62, 69, 76];

  static double midiToFrequency(num midi, {double a4 = defaultA4}) {
    return a4 * math.pow(2, (midi - 69) / 12).toDouble();
  }

  /// Numero MIDI fractionnaire : 69.5 signifie un demi-demi-ton au-dessus du la4.
  static double frequencyToMidi(double frequencyHz, {double a4 = defaultA4}) {
    if (frequencyHz <= 0) {
      throw ArgumentError.value(frequencyHz, 'frequencyHz', 'doit etre > 0');
    }
    return 69 + 12 * (math.log(frequencyHz / a4) / math.ln2);
  }

  /// Ecart en cents entre deux frequences. Positif si [frequencyHz] est plus aigu.
  static double centsBetween(double frequencyHz, double referenceHz) {
    if (frequencyHz <= 0 || referenceHz <= 0) {
      throw ArgumentError('les frequences doivent etre > 0');
    }
    return 1200 * (math.log(frequencyHz / referenceHz) / math.ln2);
  }

  /// Note temperee la plus proche.
  static int nearestMidiNote(double frequencyHz, {double a4 = defaultA4}) {
    return frequencyToMidi(frequencyHz, a4: a4).round();
  }

  /// Ecart en cents par rapport a la note temperee la plus proche.
  ///
  /// Toujours dans l'intervalle [-50, 50[ : `round()` arrondit la moitie a
  /// l'oppose de zero, donc le point pile entre deux notes bascule sur la
  /// note du dessus et rend -50, jamais +50.
  static double centsOffset(double frequencyHz, {double a4 = defaultA4}) {
    final double exact = frequencyToMidi(frequencyHz, a4: a4);
    return (exact - exact.round()) * 100;
  }

  static String noteName(int midi) {
    final int octave = (midi ~/ 12) - 1;
    return '${_noteNames[midi % 12]}$octave';
  }

  /// Corde a vide la plus proche : utile pour l'accordeur.
  static int nearestOpenString(double frequencyHz, {double a4 = defaultA4}) {
    final double exact = frequencyToMidi(frequencyHz, a4: a4);
    int best = violinOpenStrings.first;
    double bestDistance = (exact - best).abs();
    for (final int string in violinOpenStrings) {
      final double distance = (exact - string).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = string;
      }
    }
    return best;
  }
}
