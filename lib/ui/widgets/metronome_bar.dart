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
  const MetronomeBar({
    required this.tempoBpm,
    required this.running,
    this.beatsPerMeasure,
    super.key,
  });

  final int tempoBpm;
  final bool running;

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
    );

    final double phase = widget.running ? clock.phaseAt(_elapsed) : 0;
    final bool accentue = widget.running &&
        widget.beatsPerMeasure != null &&
        clock.isDownbeatAt(_elapsed);

    return Semantics(
      label: 'Metronome visuel, ${widget.tempoBpm} battements par minute',
      child: SizedBox(
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: phase.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accentue ? scheme.primary : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
