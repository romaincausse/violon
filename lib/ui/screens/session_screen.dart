import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/follow/score_cursor.dart';

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

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  bool _running = false;
  Duration _elapsed = Duration.zero;

  ScoreCursor get _cursor => ScoreCursor(
        passage: widget.passage,
        tempoBpm: widget.passage.writtenTempoBpm,
      );

  void _onTick(Duration elapsed) {
    // La lecture s'arrete d'elle-meme sur la derniere note : on termine sur
    // la fin du passage, pas sur un bouton qu'il faudrait penser a presser.
    if (_cursor.isFinishedAt(elapsed)) {
      _stop();
      return;
    }
    setState(() => _elapsed = elapsed);
  }

  void _start() {
    setState(() {
      _elapsed = Duration.zero;
      _running = true;
    });
    _ticker.start();
  }

  void _stop() {
    _ticker.stop();
    setState(() {
      _running = false;
      _elapsed = Duration.zero;
    });
  }

  @override
  void didUpdateWidget(SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changer de passage arrete la lecture : ni le tempo ni les notes ne sont
    // les memes, et laisser courir l'ancienne induirait en erreur.
    if (widget.passage != oldWidget.passage && _running) {
      _stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
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
                running: _running,
              ),
              Expanded(
                child: Center(
                  child: ScoreView(
                    passage: passage,
                    cursorTick: _running ? _cursor.tickAt(_elapsed) : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _running ? _stop : _start,
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? 'Arreter' : 'Jouer le passage'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
