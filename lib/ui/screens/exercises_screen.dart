import 'package:flutter/material.dart';

import '../../core/exercises/exercise.dart';
import '../../core/exercises/exercise_catalog.dart';
import '../../core/exercises/exercise_progress.dart';

/// Les deux facons d'aborder un exercice.
///
/// La distinction vient de l'ADR-008 -- l'application emet **ou** elle ecoute
/// -- mais elle se trouve etre celle d'un cours de violon. On travaille la
/// gamme au bourdon, on la passe ensuite.
enum ExerciseMode {
  /// Bourdon et metronome, l'application emet. Rien n'est note.
  travailler,

  /// Silence. Elle ecoute, elle note, elle designe quoi rejouer.
  passer,
}

/// Ce que l'ecran rend quand un exercice est choisi.
class ExerciseChoice {
  const ExerciseChoice({
    required this.exercise,
    required this.tempoBpm,
    required this.mode,
  });

  final Exercise exercise;

  /// Tempo de travail choisi, qui peut etre plus lent que le tempo vise.
  final int tempoBpm;

  final ExerciseMode mode;
}

/// Le catalogue de gammes et d'exercices.
///
/// **L'ecran ou l'application est utile un soir ou l'on n'a rien prepare.**
/// Un exercice ne se saisit pas et ne s'importe pas : il se genere. Deux
/// appuis separent l'ouverture de l'application du premier coup d'archet.
///
/// **Une tache mise en avant, pas une liste de manques.** La carte du haut
/// dit quoi travailler ce soir ; le reste du catalogue est en dessous, pour
/// qui veut choisir. Montrer d'abord les dix-huit exercices non acquis
/// reviendrait a ouvrir sur un bilan d'echec.
///
/// **La progression guide, elle ne verrouille pas** (ADR-011). Un palier non
/// ouvert porte un cadenas, et reste jouable : si le professeur a donne la
/// gamme de si bemol cette semaine, l'application n'a pas a la refuser.
class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({required this.progress, super.key});

  final ExerciseProgress progress;

  /// La carte de la prochaine tache, pour les tests.
  static const Key prochaineTacheKey = Key('prochaine-tache');

  /// Boutons de lancement dans la feuille de choix du tempo.
  static const Key travaillerKey = Key('travailler');
  static const Key passerKey = Key('passer');

  /// Reglage du tempo de travail, dans la feuille.
  static const Key tempoKey = Key('tempo-de-travail');

  static Key tileKey(String exerciseId) => Key('exercice-$exerciseId');

  static Key palierKey(int numero) => Key('palier-$numero');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Exercise? tache = progress.prochaineTache;

    return Scaffold(
      appBar: AppBar(title: const Text('Gammes et exercices')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            if (tache != null)
              _ProchaineTache(
                key: prochaineTacheKey,
                exercise: tache,
                progress: progress,
                onChoisir: () => _choisir(context, tache),
              )
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Tout le catalogue est acquis'),
                  subtitle: Text('Reprends celui que tu veux, plus vite.'),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${progress.acquis} exercice${progress.acquis > 1 ? "s" : ""} '
              'acquis sur ${ExerciseCatalog.all.length}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final Palier palier in ExerciseCatalog.paliers) ...<Widget>[
              _EnTetePalier(
                key: palierKey(palier.numero),
                palier: palier,
                progress: progress,
              ),
              for (final Exercise exercise
                  in ExerciseCatalog.ofPalier(palier.numero))
                _TuileExercice(
                  key: tileKey(exercise.id),
                  exercise: exercise,
                  best: progress.bestFor(exercise.id),
                  acquis: progress.estAcquis(exercise),
                  onTap: () => _choisir(context, exercise),
                ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  /// Demande le tempo et la facon d'aborder l'exercice, puis rend le choix.
  Future<void> _choisir(BuildContext context, Exercise exercise) async {
    final NavigatorState navigator = Navigator.of(context);
    final ExerciseChoice? choix = await showModalBottomSheet<ExerciseChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => _FeuilleTempo(
        exercise: exercise,
        best: progress.bestFor(exercise.id),
        tempoPropose: progress.tempoPropose(exercise),
      ),
    );
    if (choix == null) {
      return;
    }
    navigator.pop(choix);
  }
}

/// Ce qu'il y a a travailler ce soir.
class _ProchaineTache extends StatelessWidget {
  const _ProchaineTache({
    required this.exercise,
    required this.progress,
    required this.onChoisir,
    super.key,
  });

  final Exercise exercise;
  final ExerciseProgress progress;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ExerciseBest? best = progress.bestFor(exercise.id);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Ta prochaine tache', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(exercise.titre, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${exercise.detail} - ${exercise.source.court}',
              style: theme.textTheme.bodyMedium,
            ),
            if (best != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Deja ${best.essais} passage${best.essais > 1 ? 's' : ''}, '
                'meilleur score ${best.meilleurScore}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onChoisir,
              icon: const Icon(Icons.play_arrow),
              label: Text('Travailler a ${progress.tempoPropose(exercise)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnTetePalier extends StatelessWidget {
  const _EnTetePalier({
    required this.palier,
    required this.progress,
    super.key,
  });

  final Palier palier;
  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool ouvert = progress.palierEstOuvert(palier.numero);
    final int reste = progress.resteAuPalier(palier.numero);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Palier ${palier.numero} - ${palier.titre}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  ouvert && reste > 0
                      ? '${palier.intention} - il en reste $reste'
                      : palier.intention,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!ouvert)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              // Un cadenas qui n'interdit rien : il dit ou en est la
              // progression, il ne ferme pas la porte (ADR-011).
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            )
          else if (reste == 0)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Icon(
                Icons.check_circle,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _TuileExercice extends StatelessWidget {
  const _TuileExercice({
    required this.exercise,
    required this.best,
    required this.acquis,
    required this.onTap,
    super.key,
  });

  final Exercise exercise;
  final ExerciseBest? best;
  final bool acquis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ExerciseBest? best = this.best;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        acquis ? Icons.check_circle_outline : Icons.circle_outlined,
        color: acquis ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      title: Text(exercise.titre),
      subtitle: Text('${exercise.detail} - ${exercise.source.court}'),
      trailing: Text(
        // Des donnees qui montent : le meilleur score, et le tempo ou il a
        // tenu. Rien d'autre -- pas d'etoiles, pas de badge.
        //
        // Tant que rien n'est joue, c'est l'objectif qui s'affiche, et il dit
        // qu'il est un objectif : un nombre seul, a cette place, se lit comme
        // un score deja obtenu.
        best == null
            ? 'vise\n${exercise.tempoVise}'
            : '${best.meilleurScore}\n'
                '${best.meilleurTempoPropre > 0 ? "a ${best.meilleurTempoPropre}" : "-"}',
        textAlign: TextAlign.right,
        style: theme.textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}

/// Choix du tempo de travail.
///
/// **On s'installe plus lentement que le tempo vise, et c'est prevu.** Un
/// exercice ne compte comme acquis qu'au tempo vise, mais rien n'oblige a y
/// aller tout de suite : le tempo est le seul reglage de cette feuille.
class _FeuilleTempo extends StatefulWidget {
  const _FeuilleTempo({
    required this.exercise,
    required this.best,
    required this.tempoPropose,
  });

  final Exercise exercise;
  final ExerciseBest? best;

  /// Le tempo que la progression propose : le tempo vise tant que l'exercice
  /// n'est pas acquis, le cran au-dessus une fois qu'il l'est.
  final int tempoPropose;

  @override
  State<_FeuilleTempo> createState() => _FeuilleTempoState();
}

class _FeuilleTempoState extends State<_FeuilleTempo> {
  late int _tempo = widget.tempoPropose;

  /// En dessous de 40 un metronome ne sert plus a rien, et au-dessus du tempo
  /// propose il reste de la marge pour celui qui veut pousser.
  int get _min => 40;
  int get _max {
    final int vise = widget.exercise.tempoVise + 20;
    final int propose = widget.tempoPropose + 12;
    return vise > propose ? vise : propose;
  }

  void _partir(ExerciseMode mode) => Navigator.of(context).pop(
        ExerciseChoice(
          exercise: widget.exercise,
          tempoBpm: _tempo,
          mode: mode,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Exercise exercise = widget.exercise;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(exercise.titre, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${exercise.detail} - ${exercise.source.court}',
              style: theme.textTheme.bodyMedium,
            ),
            if (exercise.conseil != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.conseil!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Tempo de travail : $_tempo'
              '${_tempo < exercise.tempoVise ? " (vise : ${exercise.tempoVise})" : ""}',
              style: theme.textTheme.titleMedium,
            ),
            if (widget.tempoPropose > exercise.tempoVise)
              Text(
                'Deja tenu a ${widget.best?.meilleurTempoPropre}. '
                'On monte d un cran ?',
                style: theme.textTheme.bodySmall,
              ),
            Slider(
              key: ExercisesScreen.tempoKey,
              value: _tempo.toDouble(),
              min: _min.toDouble(),
              max: _max.toDouble(),
              divisions: (_max - _min) ~/ 2,
              label: '$_tempo',
              onChanged: (double v) => setState(() => _tempo = v.round()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ExercisesScreen.travaillerKey,
                onPressed: () => _partir(ExerciseMode.travailler),
                icon: const Icon(Icons.blur_on),
                label: Text('Travailler a $_tempo'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ExercisesScreen.passerKey,
                onPressed: () => _partir(ExerciseMode.passer),
                icon: const Icon(Icons.mic),
                label: Text('Le passer a $_tempo'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Travailler : bourdon et metronome, rien n est note. '
              'Le passer : silence, elle ecoute et elle note.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
