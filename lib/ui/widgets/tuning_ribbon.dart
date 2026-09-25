import 'dart:ui' as ui;

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

  /// En dessous, on renonce aux graduations intermediaires.
  ///
  /// Le ruban du profil paysage fait vingt-quatre points de haut : y empiler
  /// quatre traits horizontaux ne donnerait pas une echelle, seulement du
  /// bruit. La bande et l'axe suffisent, et restent lisibles.
  static const double _hauteurDesGraduations = 56;

  @override
  Widget build(BuildContext context) {
    final ColorScheme couleurs = Theme.of(context).colorScheme;
    return SizedBox(
      key: ribbonKey,
      height: height,
      child: CustomPaint(
        painter: _RibbonPainter(
          points: trace.points,
          windowMs: trace.windowMs,
          // Le fond est **plus sombre que la bande**, et non l'inverse : ce
          // qu'on veut voir au coin de l'oeil, c'est la zone ou l'on est
          // juste. Une bande a peine teintee sur un fond clair -- le premier
          // dessin -- rendait invisible la seule information qui compte.
          fond: Color.alphaBlend(
            couleurs.onSurface.withValues(alpha: 0.07),
            couleurs.surface,
          ),
          bande: Color.alphaBlend(
            TuningColors.inTune.withValues(alpha: 0.22),
            couleurs.surface,
          ),
          axe: TuningColors.inTune.withValues(alpha: 0.7),
          graduation: couleurs.onSurface.withValues(alpha: 0.18),
          lisere: couleurs.outlineVariant.withValues(alpha: 0.6),
          graduations: height >= _hauteurDesGraduations,
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
    required this.bande,
    required this.axe,
    required this.graduation,
    required this.lisere,
    required this.graduations,
  });

  final List<TracePoint> points;
  final int windowMs;
  final Color fond;
  final Color bande;
  final Color axe;
  final Color graduation;
  final Color lisere;
  final bool graduations;

  /// Graduation intermediaire : la moitie du chemin vers le demi-ton.
  ///
  /// Sans repere entre la bande et le bord, un ecart n'a pas d'echelle : on
  /// voit que le trait monte, pas de combien. Deux traits pointilles suffisent
  /// a donner la mesure sans encombrer.
  static const double _demiChemin = 50;

  @override
  void paint(Canvas canvas, Size size) {
    final double milieu = size.height / 2;
    final RRect cadre = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height < 32 ? 6 : 10),
    );
    canvas.drawRRect(cadre, Paint()..color = fond);
    canvas.save();
    canvas.clipRRect(cadre);

    // La zone qui vaut cent sur cent. La montrer evite de faire croire qu'il
    // existe une cible ponctuelle : sur un violon, juste est une bande.
    final double demiBande =
        milieu * (LiveTuning.perfectCents / TuningRibbon.rangeCents);
    canvas.drawRect(
      Rect.fromLTRB(0, milieu - demiBande, size.width, milieu + demiBande),
      Paint()..color = bande,
    );
    // **Pas de trait sur les bords de la bande.** Avec l'axe, ca faisait trois
    // lignes paralleles -- une portee miniature, illisible, et qui remplissait
    // a elle seule les cinq points de bande dont on dispose sur le ruban de
    // vingt-quatre. L'aplat suffit a dire ou elle s'arrete.

    if (graduations) {
      final double ecart = milieu * (_demiChemin / TuningRibbon.rangeCents);
      _pointilles(canvas, size, milieu - ecart);
      _pointilles(canvas, size, milieu + ecart);
    }

    canvas.drawLine(
      Offset(0, milieu),
      Offset(size.width, milieu),
      Paint()
        ..color = axe
        ..strokeWidth = 1.5,
    );

    if (points.length >= 2) {
      _tracer(canvas, size);
    }
    _tete(canvas, size);

    canvas.restore();
    // Un lisere, pour que le ruban soit un objet pose sur l'ecran et non une
    // zone de couleur qui bave dans le fond.
    canvas.drawRRect(
      cadre.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = lisere,
    );
  }

  void _pointilles(Canvas canvas, Size size, double y) {
    const double trait = 3;
    const double vide = 5;
    final Paint p = Paint()
      ..color = graduation
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += trait + vide) {
      canvas.drawLine(Offset(x, y), Offset(x + trait, y), p);
    }
  }

  /// Ordonnee d'un ecart, saturee au bord du ruban.
  double _yDe(double cents, Size size) {
    final double part = (cents / TuningRibbon.rangeCents).clamp(-1.0, 1.0);
    // Plus aigu, plus haut : l'axe des ordonnees descend a l'ecran, d'ou le
    // signe.
    return size.height / 2 - part * size.height / 2;
  }

  /// Place laissee a droite pour la tete et son halo.
  ///
  /// Sans elle, le trace allait jusqu'au bord et le halo du point courant --
  /// celui qu'on suit du coin de l'oeil -- etait coupe par le coin arrondi.
  double _margeDroite(Size size) => size.height < 32 ? 8 : 12;

  double _xDe(TracePoint p, Size size, int debut) =>
      ((p.timestampMs - debut) / windowMs).clamp(0.0, 1.0) *
      (size.width - _margeDroite(size));

  void _tracer(Canvas canvas, Size size) {
    final int fin = points.last.timestampMs;
    final int debut = fin - windowMs;
    final List<Offset> sommets = <Offset>[
      for (final TracePoint p in points)
        Offset(_xDe(p, size, debut), _yDe(p.cents, size)),
    ];

    final double epaisseur = size.height < 32 ? 2 : 2.6;
    final Paint trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      // **Un degrade vertical, et non une couleur par segment.** Le premier
      // dessin changeait de teinte d'un point au suivant, ce qui posait une
      // couture franche au milieu d'un trait continu : ca se lit comme un
      // defaut d'affichage, pas comme une information. Ici la teinte suit la
      // hauteur, donc elle dit exactement ce que dit la position.
      ..shader = _degradeVertical(size);

    // Le passe s'attenue vers la gauche. Sans ca, une note jouee il y a quatre
    // secondes a exactement le meme poids visuel que celle qu'on tient : le
    // regard ne sait pas ou se poser.
    //
    // **Attenue, pas efface.** Le ruban existe pour montrer le contour de ce
    // qui vient d'etre joue -- une attaque basse rattrapee trois secondes plus
    // tot doit rester lisible. Le plus ancien garde un quart de son encre.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(_lisser(sommets), trait);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          const <Color>[Color(0x40000000), Color(0xFF000000)],
          const <double>[0, 0.45],
        ),
    );
    canvas.restore();
  }

  ui.Gradient _degradeVertical(Size size) {
    // La bande occupe la moitie de perfectCents / rangeCents de la hauteur ;
    // la transition de teinte se fait juste au-dehors, pour que l'oeil voie
    // la couleur changer au moment ou l'on sort de la bande.
    const double part = LiveTuning.perfectCents / TuningRibbon.rangeCents / 2;
    return ui.Gradient.linear(
      Offset.zero,
      Offset(0, size.height),
      <Color>[
        TuningColors.high,
        TuningColors.high,
        TuningColors.inTune,
        TuningColors.inTune,
        TuningColors.low,
        TuningColors.low,
      ],
      <double>[
        0,
        0.5 - part - 0.09,
        0.5 - part,
        0.5 + part,
        0.5 + part + 0.09,
        1
      ],
    );
  }

  /// Relie les points par des quadratiques passant par leurs milieux.
  ///
  /// **Un lissage de l'epaisseur d'un echantillon, pas un filtre.** Les
  /// trames arrivent toutes les quarante millisecondes : reliees a la regle,
  /// elles dessinent un sismographe qu'on ne lit pas. La courbe garde les
  /// creux -- une attaque basse rattrapee doit rester visible, c'est
  /// justement ce que le ruban est la pour montrer.
  Path _lisser(List<Offset> sommets) {
    final Path chemin = Path()..moveTo(sommets.first.dx, sommets.first.dy);
    if (sommets.length == 2) {
      chemin.lineTo(sommets[1].dx, sommets[1].dy);
      return chemin;
    }
    for (int i = 1; i < sommets.length - 1; i++) {
      final Offset milieu = Offset(
        (sommets[i].dx + sommets[i + 1].dx) / 2,
        (sommets[i].dy + sommets[i + 1].dy) / 2,
      );
      chemin.quadraticBezierTo(
        sommets[i].dx,
        sommets[i].dy,
        milieu.dx,
        milieu.dy,
      );
    }
    chemin.lineTo(sommets.last.dx, sommets.last.dy);
    return chemin;
  }

  /// Le point courant.
  ///
  /// C'est lui qu'on suit du coin de l'oeil pendant qu'on lit sa partition
  /// papier : il a droit a un halo, et il reste opaque la ou le trace
  /// s'efface. Au repos il se pose au milieu, pale -- un ruban vide doit avoir
  /// l'air d'attendre, pas d'etre eteint.
  void _tete(Canvas canvas, Size size) {
    final bool aujeu = points.isNotEmpty;
    final double y = aujeu ? _yDe(points.last.cents, size) : size.height / 2;
    final double x = aujeu ? size.width - _margeDroite(size) : size.width / 2;
    final Color couleur = aujeu ? _couleurDe(points.last.cents) : axe;
    final double rayon = size.height < 32 ? 3 : 4;

    canvas.drawCircle(
      Offset(x, y),
      rayon * 2.6,
      Paint()..color = couleur.withValues(alpha: 0.18),
    );
    canvas.drawCircle(Offset(x, y), rayon, Paint()..color = couleur);
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
