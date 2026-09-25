import 'metronome_clock.dart';

/// Le decompte avant une prise.
///
/// **Bete, et bloquant sans lui.** On ne peut pas commencer un passage note
/// sans savoir quand partir : sans decompte, la premiere note est toujours en
/// retard, et c'est l'application qui l'a fait rater.
///
/// **On compte en montant, comme un chef.** "Un, deux, trois, quatre" est ce
/// qu'il entend en cours et en orchestre. Un compte a rebours serait plus
/// clair pour une fusee, pas pour un musicien.
///
/// Dart pur et sans etat, comme [MetronomeClock] : deux appels avec le meme
/// `elapsed` rendent la meme chose.
class CountIn {
  const CountIn({required this.tempoBpm, this.beats = 4})
      : assert(tempoBpm > 0, 'un tempo est strictement positif'),
        assert(beats > 0, 'un decompte dure au moins un temps');

  final int tempoBpm;

  /// Temps comptes avant le depart. Une mesure entiere, par defaut.
  final int beats;

  MetronomeClock get _clock => MetronomeClock(tempoBpm: tempoBpm);

  static const int _minuteUs = 60 * Duration.microsecondsPerSecond;

  /// Duree totale du decompte.
  ///
  /// Arrondie au microseconde **superieure**, pour que [isFinishedAt] soit
  /// vrai a cet instant precis. Une division tronquee tomberait juste avant,
  /// et le decompte resterait coince sur son dernier temps.
  Duration get duration => Duration(
        microseconds: (_minuteUs * beats + tempoBpm - 1) ~/ tempoBpm,
      );

  bool isFinishedAt(Duration elapsed) => elapsed >= duration;

  /// Temps a afficher, de 1 a [beats], ou `null` une fois le decompte fini.
  int? beatAt(Duration elapsed) {
    if (isFinishedAt(elapsed)) {
      return null;
    }
    if (elapsed <= Duration.zero) {
      return 1;
    }
    return _clock.beatIndexAt(elapsed) + 1;
  }

  /// Avancement dans le temps courant, pour animer sans a-coups.
  double phaseAt(Duration elapsed) =>
      isFinishedAt(elapsed) ? 0 : _clock.phaseAt(elapsed);
}
