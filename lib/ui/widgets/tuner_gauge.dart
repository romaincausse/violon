import 'package:flutter/material.dart';

import '../../core/scoring/tuner.dart';
import 'tuning_colors.dart';

/// L'aiguille de l'accordeur.
///
/// Une regle horizontale, pas un cadran rond : sur un telephone pose sur un
/// pupitre et regarde de biais, une aiguille qui tourne se lit mal, alors
/// qu'un curseur qui glisse vers le centre se lit du coin de l'oeil.
///
/// **Aucune recompense.** La barre passe au vert quand c'est juste, et c'est
/// tout : pas d'animation de felicitations, pas de son. L'enfant sait qu'il
/// vient d'accorder sa corde.
class TunerGauge extends StatelessWidget {
  const TunerGauge({required this.reading, this.toleranceCents = 4, super.key});

  /// La derniere lecture, ou `null` si rien n'est entendu.
  final TunerReading? reading;

  final double toleranceCents;

  /// Etendue affichee de part et d'autre du centre.
  static const double spanCents = 50;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TunerReading? r = reading;
    final Color couleur = r == null || !r.steady
        ? scheme.onSurface.withValues(alpha: 0.35)
        : r.inTune
            ? TuningColors.inTune
            : r.centsOffset < 0
                ? TuningColors.low
                : TuningColors.high;

    return SizedBox(
      height: height,
      child: CustomPaint(
        key: const Key('tuner-gauge'),
        size: Size.infinite,
        painter: _GaugePainter(
          // Au-dela de l'etendue affichee, l'aiguille se colle au bord plutot
          // que de sortir de l'ecran.
          position:
              r == null ? null : (r.centsOffset / spanCents).clamp(-1.0, 1.0),
          couleur: couleur,
          reperes: scheme.onSurface.withValues(alpha: 0.3),
          demiZoneJuste: toleranceCents / spanCents,
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.position,
    required this.couleur,
    required this.reperes,
    required this.demiZoneJuste,
  });

  /// Entre -1 et 1, ou `null` quand rien n'est entendu.
  final double? position;
  final Color couleur;
  final Color reperes;
  final double demiZoneJuste;

  @override
  void paint(Canvas canvas, Size size) {
    final double milieu = size.height / 2;
    final double demiLargeur = size.width / 2;

    // La zone juste, en clair : la cible a atteindre est une bande, pas un
    // point. Viser un point exact serait decourageant.
    canvas.drawRect(
      Rect.fromLTRB(
        demiLargeur * (1 - demiZoneJuste),
        milieu - 18,
        demiLargeur * (1 + demiZoneJuste),
        milieu + 18,
      ),
      Paint()..color = TuningColors.inTune.withValues(alpha: 0.14),
    );

    final Paint trait = Paint()
      ..color = reperes
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, milieu), Offset(size.width, milieu), trait);
    // Graduations tous les dix cents.
    for (int cents = -50; cents <= 50; cents += 10) {
      final double x = demiLargeur * (1 + cents / 50);
      final double demi = cents == 0 ? 20 : 8;
      canvas.drawLine(
          Offset(x, milieu - demi), Offset(x, milieu + demi), trait);
    }

    final double? p = position;
    if (p == null) {
      return;
    }
    final double x = demiLargeur * (1 + p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, milieu), width: 8, height: 44),
        const Radius.circular(4),
      ),
      Paint()..color = couleur,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.position != position ||
      old.couleur != couleur ||
      old.reperes != reperes ||
      old.demiZoneJuste != demiZoneJuste;
}

/// Les quatre cordes, celle qu'on entend etant mise en avant.
class StringRow extends StatelessWidget {
  const StringRow({required this.cordes, required this.active, super.key});

  final List<int> cordes;
  final int? active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (final int midi in cordes)
          _Corde(
            midi: midi,
            active: midi == active,
            style: theme.textTheme.titleMedium,
            scheme: theme.colorScheme,
          ),
      ],
    );
  }
}

class _Corde extends StatelessWidget {
  const _Corde({
    required this.midi,
    required this.active,
    required this.style,
    required this.scheme,
  });

  final int midi;
  final bool active;
  final TextStyle? style;
  final ColorScheme scheme;

  static const List<String> _noms = <String>['Sol', 'Re', 'La', 'Mi'];

  @override
  Widget build(BuildContext context) {
    final int index = <int>[55, 62, 69, 76].indexOf(midi);
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? scheme.primaryContainer : Colors.transparent,
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: active ? 0.6 : 0.2),
        ),
      ),
      child: Text(
        index < 0 ? '?' : _noms[index],
        style: style?.copyWith(
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
