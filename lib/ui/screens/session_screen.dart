import 'package:flutter/material.dart';

import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/music/score_note.dart';

/// Ecran de travail : le passage, et ce qu'on en fait.
///
/// C'est le squelette du jalon V1. La zone centrale accueillera la portee
/// gravee et son curseur ; elle affiche pour l'instant la suite des notes,
/// ce qui suffit a verifier qu'un passage saisi arrive bien jusqu'ici.
class SessionScreen extends StatelessWidget {
  const SessionScreen({
    required this.passage,
    required this.onChangePassage,
    super.key,
  });

  final Passage passage;

  /// Ouvre la saisie d'un autre passage.
  final VoidCallback onChangePassage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(passage.title),
        actions: <Widget>[
          IconButton(
            onPressed: onChangePassage,
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
              Expanded(
                child: Center(
                  // Emplacement de la portee gravee (lot G4). En attendant,
                  // la suite des notes, pour verifier qu'un passage saisi
                  // arrive bien jusqu'a l'ecran de travail.
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        for (final ScoreNote note in passage.notes)
                          Text(
                            PitchUtils.noteName(note.midi),
                            style: theme.textTheme.headlineSmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
