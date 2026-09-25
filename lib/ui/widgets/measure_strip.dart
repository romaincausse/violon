import 'package:flutter/material.dart';

import '../../core/scoring/measure_scores.dart';
import 'tuning_colors.dart';

/// Une case par mesure, qui se remplit a mesure qu'on joue.
///
/// **C'est le retour concu pour la vision peripherique.** Pendant qu'il joue,
/// ses yeux sont sur sa partition papier : il ne reste que le coin de l'oeil,
/// qui ne sait pas lire une tete de note mais voit tres bien un bloc changer.
///
/// **L'information est portee par la hauteur de remplissage**, pas seulement
/// par la couleur. La teinte est ce qui se degrade en premier en vision
/// peripherique, et elle ne dit rien a un daltonien ; une hauteur se voit dans
/// les deux cas.
///
/// **Ca monte, ca ne rougit pas.** Une mesure faible est peu remplie, pas
/// rouge : le projet montre des donnees qui montent, pas une liste d'echecs.
/// La case se remplit litteralement a mesure qu'on progresse.
///
/// **Un seul objet, deux moments.** Pendant le passage il montre ou on en est ;
/// apres, il est le bilan. Basculer vers un autre ecran couterait deux appuis
/// au moment precis ou il faut relancer.
class MeasureStrip extends StatelessWidget {
  const MeasureStrip({
    required this.measures,
    this.currentMeasure,
    super.key,
  });

  final List<MeasureScore> measures;

  /// Mesure en cours de lecture, mise en evidence.
  final int? currentMeasure;

  static const Key stripKey = Key('bandeau-mesures');

  /// Cle de la case d'une mesure, pour les tests.
  static Key keyFor(int measure) => Key('mesure-$measure');

  static const double hauteur = 28;

  @override
  Widget build(BuildContext context) {
    if (measures.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      key: stripKey,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final MeasureScore m in measures)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _Case(mesure: m, courante: m.measure == currentMeasure),
            ),
          ),
      ],
    );
  }
}

class _Case extends StatelessWidget {
  const _Case({required this.mesure, required this.courante});

  final MeasureScore mesure;
  final bool courante;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? score = mesure.score;
    // La part remplie est le score. Une mesure entendue a moitie ne remplit
    // que la moitie de ce qu'elle vaut : un score etabli sur une note sur six
    // ne doit pas s'afficher comme une mesure tenue de bout en bout.
    final double part =
        score == null ? 0 : (score / 100) * mesure.coverage.clamp(0.0, 1.0);

    // Un seul noeud d'accessibilite par case, qui dit la mesure et son score.
    // Sans `container` ni `ExcludeSemantics`, le numero sous la case forme un
    // noeud a part et la case s'annonce deux fois, en morceaux.
    return Semantics(
      container: true,
      label: 'Mesure ${mesure.measure}'
          '${score == null ? ', pas encore entendue' : ', $score sur 100'}',
      child: ExcludeSemantics(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            key: MeasureStrip.keyFor(mesure.measure),
            height: MeasureStrip.hauteur,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: courante
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: courante ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: part,
                  widthFactor: 1,
                  child: const ColoredBox(color: TuningColors.inTune),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${mesure.measure}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: courante
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: courante ? FontWeight.bold : null,
            ),
          ),
        ],
      )),
    );
  }
}
