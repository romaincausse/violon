import 'package:flutter/material.dart';

import '../../core/scoring/live_tuning.dart';
import '../../core/scoring/tuning_trace.dart';
import 'tuning_colors.dart';

/// Le trace de justesse des dernieres secondes.
///
/// **Ce que le score ne raconte pas.** Une note vaut quatre-vingt-dix ; on ne
/// sait pas si elle a ete posee juste et tenue, ou attaquee basse puis
/// rattrapee. Ce sont deux gestes differents, et le second est celui qu'un
/// professeur corrige.
///
/// **Le sens est vertical, et ce n'est pas un detail.** Un violoniste pense en
/// position de doigt : plus haut, c'est plus aigu. Coder l'ecart en gauche /
/// droite obligerait a traduire, en pleine mesure, ce que la main sait deja.
///
/// **Lisible sans la couleur.** L'ecart est porte par la hauteur du trait ;
/// la teinte ne fait que redire la meme chose, pour ceux qui la voient. C'est
/// ce qu'exige la vision peripherique, la seule disponible quand les yeux sont
/// sur la partition papier.
class TuningRibbon extends StatelessWidget {
  const TuningRibbon({required this.trace, this.height = 44, super.key});

  final TuningTrace trace;
  final double height;

  static const Key ribbonKey = Key('ruban-justesse');

  /// Ecart affiche en haut et en bas du ruban.
  ///
  /// Un demi-ton : au-dela ce n'est plus la meme note, et l'echelle n'a plus
  /// rien a dire. Le trait sature plutot que de sortir du cadre.
  static const double rangeCents = LiveTuning.worstCents;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      key: ribbonKey,
      height: height,
      child: CustomPaint(
        painter: _RibbonPainter(
          points: trace.points,
          windowMs: trace.windowMs,
          fond: theme.colorScheme.surfaceContainerHighest,
          axe: theme.colorScheme.outlineVariant,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter({
    required this.points,
    required this.windowMs,
    required this.fond,
    required this.axe,
  });

  final List<TracePoint> points;
  final int windowMs;
  final Color fond;
  final Color axe;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect cadre = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(cadre, Paint()..color = fond);
    canvas.save();
    canvas.clipRRect(cadre);

    // La zone qui vaut cent sur cent. La montrer evite de faire croire qu'il
    // existe une cible ponctuelle : sur un violon, juste est une bande.
    final double demiBande =
        size.height / 2 * (LiveTuning.perfectCents / TuningRibbon.rangeCents);
    canvas.drawRect(
      Rect.fromLTRB(
        0,
        size.height / 2 - demiBande,
        size.width,
        size.height / 2 + demiBande,
      ),
      Paint()..color = TuningColors.inTune.withValues(alpha: 0.12),
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..color = axe
        ..strokeWidth = 1,
    );

    if (points.length >= 2) {
      _tracer(canvas, size);
    }
    canvas.restore();
  }

  void _tracer(Canvas canvas, Size size) {
    final int fin = points.last.timestampMs;
    final int debut = fin - windowMs;

    Offset positionDe(TracePoint p) {
      final double x =
          ((p.timestampMs - debut) / windowMs).clamp(0.0, 1.0) * size.width;
      final double part = (p.cents / TuningRibbon.rangeCents).clamp(-1.0, 1.0);
      // Plus aigu, plus haut : l'axe des ordonnees descend a l'ecran, d'ou
      // le signe.
      return Offset(x, size.height / 2 - part * size.height / 2);
    }

    // Une couleur par segment : le trace dit ou on etait, pas seulement ou on
    // est. Un segment prend la couleur de son point d'arrivee.
    final Paint trait = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 1; i < points.length; i++) {
      trait.color = _couleurDe(points[i].cents);
      canvas.drawLine(positionDe(points[i - 1]), positionDe(points[i]), trait);
    }

    // Le point courant, plus gros : c'est lui qu'on suit du coin de l'oeil.
    canvas.drawCircle(
      positionDe(points.last),
      4,
      Paint()..color = _couleurDe(points.last.cents),
    );
  }

  Color _couleurDe(double cents) {
    if (cents.abs() <= LiveTuning.perfectCents) {
      return TuningColors.inTune;
    }
    return cents < 0 ? TuningColors.low : TuningColors.high;
  }

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.points.length != points.length ||
      (points.isNotEmpty &&
          old.points.isNotEmpty &&
          old.points.last.timestampMs != points.last.timestampMs);
}
