import 'metronome_clock.dart';

/// Une pulsation a poser dans le moteur de son.
class ScheduledPulse {
  const ScheduledPulse({
    required this.index,
    required this.at,
    required this.accent,
  });

  /// Numero de pulsation depuis le depart, base 0.
  final int index;

  /// Instant exact ou elle doit sonner, depuis le depart.
  final Duration at;

  final PulseAccent accent;

  @override
  String toString() =>
      'ScheduledPulse($index, ${at.inMilliseconds} ms, ${accent.name})';
}

/// Decide quelles pulsations poser dans le moteur, et quand.
///
/// **Le clic n'est jamais declenche, il est toujours planifie d'avance.** Le
/// projet interdit un `Timer` Dart pour le metronome parce que sa derive
/// s'entend : un minuteur se reveille en retard des que l'interface travaille,
/// et un metronome qui hesite est pire qu'un metronome absent.
///
/// **Ce qui reste permis, et c'est toute l'astuce : un minuteur qui ne fait que
/// remplir la file a l'avance.** S'il se reveille cinquante millisecondes trop
/// tard, il pose les memes clics aux memes instants -- sa gigue ne deplace
/// rien, parce que l'instant de chaque clic est calcule depuis le depart et
/// fige dans le moteur des la planification. La derive est donc structurellement
/// impossible, et pas seulement improbable.
///
/// Pur, sans horloge interne : on lui passe l'instant courant, il rend ce qui
/// reste a poser. Les tests n'attendent jamais.
class MetronomeScheduler {
  MetronomeScheduler({
    required this.clock,
    this.lookahead = const Duration(milliseconds: 1500),
  }) : assert(lookahead > Duration.zero, 'on planifie vers l avant');

  final MetronomeClock clock;

  /// Jusqu'ou on planifie a l'avance.
  ///
  /// Une seconde et demie tient largement entre deux reveils de minuteur, meme
  /// quand l'interface peine, et reste assez court pour qu'un changement de
  /// tempo se fasse entendre tout de suite.
  final Duration lookahead;

  /// Derniere pulsation deja posee, ou -1 si aucune.
  int _posee = -1;

  int get lastScheduledIndex => _posee;

  /// Les pulsations a poser maintenant, si l'on en est a [now].
  ///
  /// Rend celles dont l'instant tombe dans `]deja pose, now + lookahead]`.
  /// Appeler deux fois de suite sans avancer ne repose donc rien : un clic
  /// double s'entend autant qu'un clic manquant.
  List<ScheduledPulse> due(Duration now) {
    final Duration horizon = now + lookahead;
    final int dernier = clock.pulseIndexAt(horizon);
    if (dernier <= _posee) {
      return const <ScheduledPulse>[];
    }
    final List<ScheduledPulse> aPoser = <ScheduledPulse>[
      for (int i = _posee + 1; i <= dernier; i++)
        ScheduledPulse(
          index: i,
          at: clock.pulseTime(i),
          accent: clock.accentOf(i),
        ),
    ];
    _posee = dernier;
    return aPoser;
  }

  /// Delai a donner au moteur pour [pulse], si l'on en est a [now].
  ///
  /// Jamais negatif : une pulsation deja passee -- parce que le remplissage a
  /// pris du retard -- sonne tout de suite plutot que d'etre perdue. C'est le
  /// seul endroit ou la charge de l'interface peut s'entendre, et elle
  /// s'entend alors comme un clic en avance, jamais comme une derive
  /// cumulative.
  static Duration delayFor(ScheduledPulse pulse, Duration now) {
    final Duration delai = pulse.at - now;
    return delai.isNegative ? Duration.zero : delai;
  }

  /// Oublie ce qui a ete pose : a appeler a chaque depart.
  void reset() => _posee = -1;
}
