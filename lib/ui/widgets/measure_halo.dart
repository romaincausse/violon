import 'package:flutter/material.dart';

import 'tuning_colors.dart';

/// Une mesure passee proprement fait respirer le bord de l'ecran.
///
/// **La seule recompense que le projet autorise : de la lumiere.** Pas de
/// badge, pas de confetti, pas de mascotte -- l'enfant a onze ans et sait
/// qu'il fait de la musique. Une lueur breve dit "c'etait propre" sans
/// interrompre, sans texte a lire, et sans rien ajouter a compter.
///
/// **Calee sur la mesure, jamais sur la note.** A la note, ca clignoterait en
/// permanence et deviendrait du bruit ; a la mesure, ca marque une etape que
/// l'enfant reconnait sur son papier.
///
/// Elle se voit du coin de l'oeil -- c'est tout l'interet, puisque ses yeux
/// sont sur la partition -- et elle ne prend aucune place : elle se superpose
/// au bord, sans deplacer quoi que ce soit.
class MeasureHalo extends StatefulWidget {
  const MeasureHalo({
    required this.child,
    required this.trigger,
    this.duration = const Duration(milliseconds: 600),
    super.key,
  });

  final Widget child;

  /// Change de valeur a chaque mesure reussie. Le contenu n'importe pas, seul
  /// le changement compte.
  final int trigger;

  final Duration duration;

  static const Key haloKey = Key('halo-mesure');

  @override
  State<MeasureHalo> createState() => _MeasureHaloState();
}

class _MeasureHaloState extends State<MeasureHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(MeasureHalo old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger) {
      _controleur.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        // `IgnorePointer` parce qu'une recompense ne doit jamais avaler un
        // appui : le bouton passe dessous reste atteignable pendant la lueur.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controleur,
              builder: (BuildContext context, Widget? _) {
                // Monte vite, redescend doucement : une lueur qui s'allume
                // progressivement se remarque moins qu'elle ne distrait.
                final double t = _controleur.value;
                final double force =
                    t == 0 ? 0 : (t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8);
                return CustomPaint(
                  key: MeasureHalo.haloKey,
                  painter: _HaloPainter(force.clamp(0.0, 1.0)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.force);

  /// Entre 0 et 1.
  final double force;

  @override
  void paint(Canvas canvas, Size size) {
    if (force <= 0) {
      return;
    }
    final double epaisseur = 10 * force;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur * 2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, epaisseur)
        ..color = TuningColors.inTune.withValues(alpha: 0.55 * force),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.force != force;
}
