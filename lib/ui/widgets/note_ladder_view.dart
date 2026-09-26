import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/music/pitch_utils.dart';
import '../../core/scoring/note_ladder.dart';
import '../../core/scoring/tuning_trace.dart';
import 'tuning_colors.dart';

/// L'echelle des notes de l'exercice, et ce qu'on vient de jouer dessus.
///
/// **Le ruban d'ecart dit de combien, jamais de quoi.** A vingt cents pres on
/// ne sait pas si l'on joue un do un peu haut ou un do diese tres bas : c'est
/// pourtant la seule chose qu'un enfant a besoin de savoir quand il se trompe
/// de doigt. Ici chaque note de l'exercice a son barreau, a sa hauteur
/// reelle, et le trait passe **dedans** quand c'est juste.
///
/// **Ce n'est pas une partition.** Un eleve de 4e annee lit son papier ; on ne
/// lui apprend pas a lire sur un piano-roll, on lui montre ce qu'il vient de
/// jouer.
///
/// **La ligne du present est fixe**, a droite : c'est le contenu qui vient a
/// elle. Le regard n'a pas a suivre un curseur.
class NoteLadderView extends StatelessWidget {
  const NoteLadderView({
    required this.ladder,
    required this.trace,
    this.expected,
    super.key,
  });

  final NoteLadder ladder;
  final TuningTrace trace;

  /// La note attendue en ce moment, si on le sait.
  final int? expected;

  static const Key ladderKey = Key('echelle-des-notes');

  /// En dessous de cet ecart entre deux barreaux, les noms s'effacent.
  ///
  /// Une gamme sur deux octaves pose vingt-cinq barreaux : les nommer tous
  /// sur trois cents points de haut empilerait des etiquettes illisibles.
  /// Seuls restent alors le nom attendu et celui qu'on atteint -- les deux
  /// qui servent.
  static const double ecartLisible = 17;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox.expand(
      key: ladderKey,
      child: CustomPaint(
        painter: _LadderPainter(
          ladder: ladder,
          points: trace.points,
          windowMs: trace.windowMs,
          expected: expected,
          fond: Color.alphaBlend(
            theme.colorScheme.onSurface.withValues(alpha: 0.05),
            theme.colorScheme.surface,
          ),
          barreau: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          encre: theme.colorScheme.onSurface,
          nom: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 12),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _LadderPainter extends CustomPainter {
  _LadderPainter({
    required this.ladder,
    required this.points,
    required this.windowMs,
    required this.expected,
    required this.fond,
    required this.barreau,
    required this.encre,
    required this.nom,
  });

  final NoteLadder ladder;
  final List<TracePoint> points;
  final int windowMs;
  final int? expected;
  final Color fond;
  final Color barreau;
  final Color encre;
  final TextStyle nom;

  /// Largeur de la colonne des noms.
  static const double _gouttiere = 46;

  /// Air garde a droite du present, pour que le halo de la tete ne soit pas
  /// coupe par le bord.
  static const double _margeDroite = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect cadre = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas.drawRRect(cadre, Paint()..color = fond);
    canvas.save();
    canvas.clipRRect(cadre);

    final double? joue = points.isEmpty ? null : points.last.midi;
    final int? atteint = joue == null ? null : ladder.reachedBy(joue);

    _barreaux(canvas, size, atteint);
    _ligneDuPresent(canvas, size);
    if (points.length >= 2) {
      _tracer(canvas, size);
    }
    _tete(canvas, size, joue, atteint);

    canvas.restore();
  }

  /// La ligne du present, fixe a droite.
  ///
  /// **C'est le contenu qui vient a elle**, et non elle qui parcourt le
  /// contenu : le regard n'a pas a suivre un curseur. Sans ce repere, la
  /// tete aurait l'air de flotter au bord.
  void _ligneDuPresent(Canvas canvas, Size size) {
    final double x = size.width - _margeDroite;
    canvas.drawLine(
      Offset(x, 6),
      Offset(x, size.height - 6),
      Paint()
        ..strokeWidth = 1
        ..color = encre.withValues(alpha: 0.18),
    );
  }

  /// Les barreaux, et les noms quand la place le permet.
  void _barreaux(Canvas canvas, Size size, int? atteint) {
    // **Le plus petit ecart, pas l'ecart moyen.** Une gamme melange tons et
    // demi-tons : une moyenne confortable cacherait que deux barreaux voisins
    // se touchent, et c'est la que les etiquettes se chevauchent.
    double plusPetit = size.height;
    for (int i = 1; i < ladder.steps.length; i++) {
      final double ecart = (_yDe(ladder.steps[i - 1].toDouble(), size) -
              _yDe(ladder.steps[i].toDouble(), size))
          .abs();
      if (ecart < plusPetit) {
        plusPetit = ecart;
      }
    }
    final bool tousLesNoms = plusPetit >= NoteLadderView.ecartLisible;

    for (final int pasMidi in ladder.steps) {
      final double y = _yDe(pasMidi.toDouble(), size);
      final double demi = _demiBarreau(size);
      final bool attendu = pasMidi == expected;
      final Color teinte = _couleurDuBarreau(pasMidi, atteint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(_gouttiere, y - demi, size.width, y + demi),
          Radius.circular(demi.clamp(2, 8)),
        ),
        Paint()..color = teinte,
      );
      // Le barreau attendu garde un lisere meme quand on est loin : sans lui,
      // on ne verrait pas la cible qu'on manque.
      if (attendu) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(_gouttiere, y - demi, size.width, y + demi),
            Radius.circular(demi.clamp(2, 8)),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = encre.withValues(alpha: 0.45),
        );
      }
      if (tousLesNoms || attendu || pasMidi == atteint) {
        _nommer(canvas, pasMidi, y, attendu || pasMidi == atteint);
      }
    }
  }

  /// Demi-hauteur d'un barreau, en pixels.
  ///
  /// **C'est la tolerance elle-meme**, convertie a l'echelle : un contenant
  /// qui ne vaudrait pas le bareme mentirait a l'oeil. Un plancher garde le
  /// barreau visible quand l'exercice couvre deux octaves.
  double _demiBarreau(Size size) {
    final double parDemiTon = size.height / (ladder.highMidi - ladder.lowMidi);
    final double demi = parDemiTon * ladder.toleranceCents / 100;
    return demi < 3 ? 3 : demi;
  }

  Color _couleurDuBarreau(int pasMidi, int? atteint) {
    if (pasMidi != atteint) {
      return barreau;
    }
    final int? vise = expected;
    if (vise == null || pasMidi == vise) {
      // Sans note attendue -- hors prise -- atteindre un barreau ne veut dire
      // que "je suis sur une note de l'exercice", pas "c'est la bonne".
      return (vise == null ? encre : TuningColors.inTune).withValues(
        alpha: 0.30,
      );
    }
    return (pasMidi < vise ? TuningColors.low : TuningColors.high).withValues(
      alpha: 0.30,
    );
  }

  void _nommer(Canvas canvas, int midi, double y, bool appuye) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: PitchUtils.noteName(midi),
        style: nom.copyWith(
          color: encre.withValues(alpha: appuye ? 0.95 : 0.55),
          fontWeight: appuye ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _gouttiere - 8);
    tp.paint(canvas, Offset(_gouttiere - 8 - tp.width, y - tp.height / 2));
  }

  /// Le trait de hauteur, continu et absolu.
  ///
  /// **En encre, pas en couleur.** Ici la couleur ne peut pas se deduire de la
  /// hauteur seule -- juste depend de la note attendue, qui change en cours de
  /// route. Un degrade vertical, comme sur le ruban d'ecart, dirait donc faux.
  /// C'est le barreau qui porte le verdict ; le trait ne porte que la hauteur.
  void _tracer(Canvas canvas, Size size) {
    final int fin = points.last.timestampMs;
    final int debut = fin - windowMs;
    final List<Offset> sommets = <Offset>[
      for (final TracePoint p in points)
        if (p.midi != null)
          Offset(_xDe(p.timestampMs, size, debut), _yDe(p.midi!, size)),
    ];
    if (sommets.length < 2) {
      return;
    }

    final Paint trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = encre.withValues(alpha: 0.85);

    // Le passe s'attenue vers la gauche, comme sur le ruban d'ecart : sans ca,
    // une note jouee il y a quatre secondes pese autant que celle qu'on tient.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(_lisser(sommets), trait);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          const Offset(_gouttiere, 0),
          Offset(size.width, 0),
          const <Color>[Color(0x33000000), Color(0xFF000000)],
          const <double>[0, 0.5],
        ),
    );
    canvas.restore();
  }

  /// Relie les points par des quadratiques passant par leurs milieux.
  Path _lisser(List<Offset> sommets) {
    final Path chemin = Path()..moveTo(sommets.first.dx, sommets.first.dy);
    if (sommets.length == 2) {
      chemin.lineTo(sommets[1].dx, sommets[1].dy);
      return chemin;
    }
    for (int i = 1; i < sommets.length - 1; i++) {
      chemin.quadraticBezierTo(
        sommets[i].dx,
        sommets[i].dy,
        (sommets[i].dx + sommets[i + 1].dx) / 2,
        (sommets[i].dy + sommets[i + 1].dy) / 2,
      );
    }
    chemin.lineTo(sommets.last.dx, sommets.last.dy);
    return chemin;
  }

  /// Le point courant, sur la ligne du present.
  void _tete(Canvas canvas, Size size, double? joue, int? atteint) {
    final double y = joue == null ? size.height / 2 : _yDe(joue, size);
    final double x = joue == null
        ? (_gouttiere + size.width) / 2
        : size.width - _margeDroite;
    final Color couleur = _couleurDeLaTete(joue, atteint);

    canvas.drawCircle(
      Offset(x, y),
      10.4,
      Paint()..color = couleur.withValues(alpha: 0.18),
    );
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = couleur);
  }

  Color _couleurDeLaTete(double? joue, int? atteint) {
    final int? vise = expected;
    if (joue == null) {
      return encre.withValues(alpha: 0.35);
    }
    if (vise == null) {
      return atteint == null ? encre.withValues(alpha: 0.5) : encre;
    }
    if (atteint == vise) {
      return TuningColors.inTune;
    }
    return joue < vise ? TuningColors.low : TuningColors.high;
  }

  double _yDe(double midi, Size size) =>
      size.height * (1 - ladder.fractionOf(midi));

  double _xDe(int timestampMs, Size size, int debut) {
    final double large = size.width - _gouttiere - _margeDroite;
    final double part = (timestampMs - debut) / windowMs;
    return _gouttiere + large * part.clamp(0, 1);
  }

  @override
  bool shouldRepaint(_LadderPainter old) =>
      old.expected != expected ||
      !listEquals(old.ladder.steps, ladder.steps) ||
      old.points.length != points.length ||
      (points.isNotEmpty &&
          old.points.isNotEmpty &&
          old.points.last.timestampMs != points.last.timestampMs);
}
