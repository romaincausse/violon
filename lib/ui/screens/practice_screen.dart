import 'package:flutter/material.dart';

import '../../core/music/passage.dart';
import '../../core/practice/practice_session.dart';
import '../widgets/round_dots.dart';

/// Ecran de travail en boucle.
///
/// Regle d'ergonomie : une seule chose a l'ecran a la fois. La variation en
/// cours, en grand. Le reste est secondaire.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({required this.passage, super.key});

  final Passage passage;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late PracticeSession _session = PracticeSession.forPassage(widget.passage);

  void _complete(RoundOutcome outcome) {
    setState(() => _session.completeRound(outcome));
  }

  void _restart() {
    setState(() => _session = PracticeSession.forPassage(widget.passage));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool finished = _session.isFinished;

    return Scaffold(
      appBar: AppBar(title: Text(widget.passage.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Tour ${_session.currentRoundNumber} / ${_session.totalRounds}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${_session.currentTempoBpm} bpm',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            RoundDots(outcomes: _session.outcomes),
            const Spacer(),
            if (finished) ...<Widget>[
              Text(
                'Termine.',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${_session.cleanRounds} tours propres sur ${_session.totalRounds}.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ] else ...<Widget>[
              Text(
                _session.currentVariation.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              Text(
                _session.currentVariation.instruction,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
            const Spacer(),
            if (finished)
              FilledButton(
                onPressed: _restart,
                child: const Text('Recommencer'),
              )
            else ...<Widget>[
              FilledButton(
                onPressed: () => _complete(RoundOutcome.clean),
                child: const Text('C\'etait propre'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _complete(RoundOutcome.shaky),
                child: const Text('Pas terrible'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(_session.skipVariation),
                child: const Text('Celle-la je n\'aime pas'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
