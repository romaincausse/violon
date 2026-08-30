import 'package:flutter/material.dart';

import '../../core/practice/practice_session.dart';

/// Pastilles de progression. Toutes visibles des le premier tour : la fin
/// doit etre atteignable a l'oeil des la premiere seconde.
class RoundDots extends StatelessWidget {
  const RoundDots({required this.outcomes, super.key});

  final List<RoundOutcome> outcomes;

  static Color _colorFor(RoundOutcome outcome, ColorScheme scheme) {
    switch (outcome) {
      case RoundOutcome.clean:
        return Colors.green;
      case RoundOutcome.shaky:
        return Colors.orange;
      case RoundOutcome.skipped:
        return scheme.outlineVariant;
      case RoundOutcome.pending:
        return scheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (final RoundOutcome outcome in outcomes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _colorFor(outcome, scheme),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
