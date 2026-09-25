import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/play/metronome_clock.dart';

/// Metronome visuel : une barre qui se remplit sur chaque temps.
///
/// Le seul metronome autorise en mode notation. L'ADR-008 interdit a
/// l'application d'emettre le moindre son pendant qu'elle ecoute : le
/// haut-parleur est a dix centimetres du micro.
///
/// La barre se remplit de gauche a droite puis retombe d'un coup. Le retour a
/// zero se percoit en vision peripherique, ce qui permet de garder les yeux
/// sur la partition -- ou sur son archet.
///
/// Le temps vient du `Ticker`, qui rend l'ecoule **depuis le depart** et non
/// un delta a cumuler. Combine a [MetronomeClock], qui ne cumule rien non
/// plus, la pulsation ne peut pas deriver.
class MetronomeBar extends StatefulWidget {
  /// Cle de la barre qui pulse, pour la viser sans ambiguite depuis un test.
  ///
  /// Sans elle, un test qui cherchait "le" `FractionallySizedBox` de l'ecran
  /// s'est casse des qu'un second widget en a utilise un. Un test doit viser
  /// ce qu'il mesure, pas le seul candidat du moment.
  static const Key pulseKey = Key('metronome-pulse');

  const MetronomeBar({
    required this.tempoBpm,
    required this.running,
    this.beatsPerMeasure,
    this.subdivision = 1,
    super.key,
  });

  final int tempoBpm;
  final bool running;

  /// Pulsations par temps : 1 la noire, 2 les croches, 3 le triolet, 4 les
  /// doubles.
  ///
  /// **Un metronome qui ne subdivise pas ne sert plus a rien des que le
  /// rythme se complique**, et en 4e annee il se complique. La barre bat
  /// alors la subdivision, et les temps restent reconnaissables a leur
  /// intensite : sans ca, on perdrait le metre en gagnant la precision.
  final int subdivision;

  /// Nombre de temps par mesure, s'il est connu. `null` signifie qu'on ne
  /// marque pas les temps forts : mieux vaut ne rien accentuer que d'accentuer
  /// au mauvais endroit en supposant du 4/4. `Passage` ne porte pas encore le
  /// chiffrage.
  final int? beatsPerMeasure;

  @override
  State<MetronomeBar> createState() => _MetronomeBarState();
}

class _MetronomeBarState extends State<MetronomeBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.running) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(MetronomeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running == oldWidget.running) {
      return;
    }
    if (widget.running) {
      _elapsed = Duration.zero;
      _ticker.start();
    } else {
      _ticker.stop();
      setState(() => _elapsed = Duration.zero);
    }
  }

  void _onTick(Duration elapsed) => setState(() => _elapsed = elapsed);

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MetronomeClock clock = MetronomeClock(
      tempoBpm: widget.tempoBpm,
      beatsPerMeasure: widget.beatsPerMeasure ?? 4,
      subdivision: widget.subdivision,
    );

    final double phase = widget.running ? clock.pulsePhaseAt(_elapsed) : 0;
    final PulseAccent accent = clock.accentAt(_elapsed);
    // Trois intensites pour trois roles : le premier temps porte la mesure,
    // les autres temps la scandent, les subdivisions remplissent. Les peindre
    // pareil reviendrait a ne rien dire du metre.
    final Color couleur = !widget.running
        ? scheme.primaryContainer
        : switch (accent) {
            PulseAccent.downbeat => widget.beatsPerMeasure == null
                ? scheme.primaryContainer
                : scheme.primary,
            PulseAccent.beat => scheme.primaryContainer,
            PulseAccent.subdivision =>
              scheme.primaryContainer.withValues(alpha: 0.45),
          };

    return Semantics(
      label: 'Metronome visuel, ${widget.tempoBpm} battements par minute'
          '${widget.subdivision > 1 ? ', divise en ${widget.subdivision}' : ''}',
      child: SizedBox(
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
          ),
          child: FractionallySizedBox(
            key: MetronomeBar.pulseKey,
            alignment: Alignment.centerLeft,
            widthFactor: phase.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: couleur,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
