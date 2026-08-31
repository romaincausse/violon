import 'package:flutter/material.dart';

import '../../core/music/passage.dart';
import '../widgets/metronome_bar.dart';
import '../widgets/score_view.dart';

/// Ecran de travail : le passage, et ce qu'on en fait.
///
/// C'est le squelette du jalon V1. La zone centrale accueillera la portee
/// gravee et son curseur ; elle affiche pour l'instant la suite des notes,
/// ce qui suffit a verifier qu'un passage saisi arrive bien jusqu'ici.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    required this.passage,
    required this.onChangePassage,
    super.key,
  });

  final Passage passage;

  /// Ouvre la saisie d'un autre passage.
  final VoidCallback onChangePassage;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool _metronomeRunning = false;

  @override
  void didUpdateWidget(SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changer de passage arrete la pulsation : le tempo n'est plus le meme,
    // et laisser battre l'ancien induirait en erreur.
    if (widget.passage != oldWidget.passage && _metronomeRunning) {
      setState(() => _metronomeRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Passage passage = widget.passage;

    return Scaffold(
      appBar: AppBar(
        title: Text(passage.title),
        actions: <Widget>[
          IconButton(
            onPressed: widget.onChangePassage,
            icon: const Icon(Icons.edit_note),
            tooltip: 'Changer de passage',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          // Cle explicite : le test de mise en page mesure ce contenu, pas
          // le SafeArea lui-meme, qui occupe toute la hauteur et dont seul
          // l'enfant est decale.
          key: const Key('session-content'),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    passage.measureCount == 1
                        ? 'Mesure ${passage.firstMeasure}'
                        : 'Mesures ${passage.firstMeasure} '
                            'a ${passage.lastMeasure}',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${passage.writtenTempoBpm} bpm',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 20),
              MetronomeBar(
                tempoBpm: passage.writtenTempoBpm,
                running: _metronomeRunning,
              ),
              Expanded(
                child: Center(
                  child: ScoreView(passage: passage),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => setState(
                  () => _metronomeRunning = !_metronomeRunning,
                ),
                icon: Icon(
                  _metronomeRunning ? Icons.stop : Icons.play_arrow,
                ),
                label: Text(
                  _metronomeRunning ? 'Arreter' : 'Lancer le metronome',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
