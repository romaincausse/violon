import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/music/passage.dart';
import '../../core/music/score_note.dart';
import '../../core/score/staff_geometry.dart';
import '../../core/score/staff_layout.dart';
import '../../core/score/stems_and_beams.dart';

/// Couleur d'une note, pour le retour visuel en direct.
typedef NoteColorResolver = Color? Function(ScoreNote note);

/// La portee gravee.
///
/// Tout le placement vient de `lib/core/score/`, qui raisonne en espaces de
/// portee. Ce widget ne fait que convertir en pixels et peindre : il ne
/// decide d'aucune position.
///
/// **Sans police musicale pour l'instant.** Le lot G1 apportera Bravura, qui
/// remplacera les tetes dessinees a la main par de vrais glyphes et ajoutera
/// la cle de sol. En attendant, tout est trace en primitives : c'est lisible
/// et cela permet de voir la gravure marcher avant d'embarquer un asset.
class ScoreView extends StatelessWidget {
  const ScoreView({
    required this.passage,
    this.colorOf,
    this.spaceSize,
    super.key,
  });

  /// En dessous, la portee devient illisible a 70 cm sur un pupitre.
  static const double minSpaceSize = 7;

  /// Au-dela, un passage de deux notes s'etalerait sur tout l'ecran.
  static const double maxSpaceSize = 16;

  final Passage passage;

  /// Rend la couleur d'une note, ou `null` pour la couleur par defaut.
  /// C'est par la que le retour visuel de justesse arrivera (lot F2).
  final NoteColorResolver? colorOf;

  /// Hauteur d'un interligne, en pixels. La portee en fait quatre.
  ///
  /// `null` laisse le widget la deduire de la largeur disponible : un passage
  /// de deux mesures doit se voir en entier, sans defiler. Un passage trop
  /// long retombe sur [minSpaceSize] et defile horizontalement.
  final double? spaceSize;

  @override
  Widget build(BuildContext context) {
    if (spaceSize != null) {
      return _build(context, spaceSize!);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double largeurEspaces = StaffLayout.of(passage).widthSpaces;
        final double ajuste = constraints.maxWidth.isFinite
            ? constraints.maxWidth / largeurEspaces
            : maxSpaceSize;
        return _build(context, ajuste.clamp(minSpaceSize, maxSpaceSize));
      },
    );
  }

  Widget _build(BuildContext context, double spaceSize) {
    final StaffLayout layout = StaffLayout.of(passage);
    final StemsAndBeams stems = StemsAndBeams.of(layout);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // Marge d'un espace et demi au-dela de la note la plus extreme, pour ne
    // rogner ni les lignes supplementaires ni les hampes.
    final double topSpaces = math.min(
          StaffGeometry.yInSpaces(layout.highestStep),
          -2.0 - StemsAndBeams.standardLengthSpaces,
        ) -
        1.5;
    final double bottomSpaces = math.max(
          StaffGeometry.yInSpaces(layout.lowestStep),
          2.0 + StemsAndBeams.standardLengthSpaces,
        ) +
        1.5;

    final Size size = Size(
      layout.widthSpaces * spaceSize,
      (bottomSpaces - topSpaces) * spaceSize,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: CustomPaint(
        size: size,
        painter: _ScorePainter(
          layout: layout,
          stems: stems,
          topSpaces: topSpaces,
          spaceSize: spaceSize,
          inkColor: scheme.onSurface,
          colorOf: colorOf,
        ),
      ),
    );
  }
}

class _ScorePainter extends CustomPainter {
  _ScorePainter({
    required this.layout,
    required this.stems,
    required this.topSpaces,
    required this.spaceSize,
    required this.inkColor,
    required this.colorOf,
  });

  final StaffLayout layout;
  final StemsAndBeams stems;
  final double topSpaces;
  final double spaceSize;
  final Color inkColor;
  final NoteColorResolver? colorOf;

  double _x(double spaces) => spaces * spaceSize;
  double _y(double spaces) => (spaces - topSpaces) * spaceSize;
  double _yOfStep(int step) => _y(StaffGeometry.yInSpaces(step));

  @override
  void paint(Canvas canvas, Size size) {
    _paintStaff(canvas, size);
    _paintBarlines(canvas);

    final Map<int, Beam> beamOfNote = <int, Beam>{};
    for (final Beam beam in stems.beams) {
      for (final int i in beam.noteIndices) {
        beamOfNote[i] = beam;
      }
    }

    for (int i = 0; i < layout.notes.length; i++) {
      _paintLedgers(canvas, layout.notes[i]);
    }
    for (final Stem stem in stems.stems) {
      _paintStem(canvas, stem, beamOfNote[stem.noteIndex]);
    }
    for (final Beam beam in stems.beams) {
      _paintBeam(canvas, beam);
    }
    for (int i = 0; i < layout.notes.length; i++) {
      _paintNote(canvas, layout.notes[i]);
    }
  }

  void _paintStaff(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = inkColor.withValues(alpha: 0.55)
      ..strokeWidth = math.max(1, spaceSize * 0.11);
    for (int step = StaffGeometry.bottomLineStep;
        step <= StaffGeometry.topLineStep;
        step += 2) {
      final double y = _yOfStep(step);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _paintBarlines(Canvas canvas) {
    final Paint p = Paint()
      ..color = inkColor.withValues(alpha: 0.55)
      ..strokeWidth = math.max(1, spaceSize * 0.13);
    final double haut = _yOfStep(StaffGeometry.topLineStep);
    final double bas = _yOfStep(StaffGeometry.bottomLineStep);
    for (final double xSpaces in layout.barlineXSpaces) {
      final double x = _x(xSpaces);
      canvas.drawLine(Offset(x, haut), Offset(x, bas), p);
    }
  }

  void _paintLedgers(Canvas canvas, PlacedNote note) {
    if (note.ledgerSteps.isEmpty) {
      return;
    }
    final Paint p = Paint()
      ..color = inkColor
      ..strokeWidth = math.max(1, spaceSize * 0.12);
    // Une ligne supplementaire deborde legerement de part et d'autre de la
    // tete, comme sur une partition gravee.
    final double demi = spaceSize * 0.85;
    final double x = _x(note.xSpaces);
    for (final int step in note.ledgerSteps) {
      final double y = _yOfStep(step);
      canvas.drawLine(Offset(x - demi, y), Offset(x + demi, y), p);
    }
  }

  void _paintStem(Canvas canvas, Stem stem, Beam? beam) {
    final PlacedNote note = layout.notes[stem.noteIndex];
    final Paint p = Paint()
      ..color = _colorFor(note)
      ..strokeWidth = math.max(1, spaceSize * 0.12);
    // Une hampe ligaturee s'arrete sur la ligature, pas a sa longueur propre :
    // sinon les hampes d'un meme groupe ne se rejoindraient pas.
    final double tip = beam == null ? stem.tipYSpaces : beam.ySpaces;
    canvas.drawLine(
      Offset(_x(stem.xSpaces), _y(stem.headYSpaces)),
      Offset(_x(stem.xSpaces), _y(tip)),
      p,
    );
    if (beam == null && stem.flagCount > 0) {
      _paintFlags(canvas, stem);
    }
  }

  void _paintFlags(Canvas canvas, Stem stem) {
    final Paint p = Paint()
      ..color = _colorFor(layout.notes[stem.noteIndex])
      ..style = PaintingStyle.fill;
    final double x = _x(stem.xSpaces);
    final double sens = stem.direction == StemDirection.up ? 1 : -1;
    for (int i = 0; i < stem.flagCount; i++) {
      final double y = _y(stem.tipYSpaces) +
          sens * i * spaceSize * StemsAndBeams.beamSpacingSpaces;
      final Path path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x + spaceSize * 1.1,
          y + sens * spaceSize * 0.6,
          x + spaceSize * 0.9,
          y + sens * spaceSize * 1.7,
        )
        ..quadraticBezierTo(
          x + spaceSize * 0.9,
          y + sens * spaceSize * 0.8,
          x,
          y + sens * spaceSize * 0.55,
        )
        ..close();
      canvas.drawPath(path, p);
    }
  }

  void _paintBeam(Canvas canvas, Beam beam) {
    final Paint p = Paint()
      ..color = _colorFor(layout.notes[beam.noteIndices.first])
      ..style = PaintingStyle.fill;
    final double epaisseur = spaceSize * 0.5;
    // Les ligatures supplementaires s'empilent vers les tetes, jamais vers
    // l'exterieur : c'est du cote des notes qu'il y a de la place.
    final double sens = beam.direction == StemDirection.up ? 1 : -1;
    for (int i = 0; i < beam.beamCount; i++) {
      final double y = _y(beam.ySpaces) +
          sens * i * spaceSize * StemsAndBeams.beamSpacingSpaces;
      canvas.drawRect(
        Rect.fromLTRB(
          _x(beam.startXSpaces),
          y - (beam.direction == StemDirection.up ? 0 : epaisseur),
          _x(beam.endXSpaces),
          y + (beam.direction == StemDirection.up ? epaisseur : 0),
        ),
        p,
      );
    }
  }

  void _paintNote(Canvas canvas, PlacedNote note) {
    final NoteHead head = StemsAndBeams.headFor(
      note.note.durationTicks,
      layout.ticksPerBeat,
    );
    final Color color = _colorFor(note);
    final double x = _x(note.xSpaces);
    final double y = _y(note.yInSpaces);

    final Paint p = Paint()
      ..color = color
      ..style =
          head == NoteHead.filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, spaceSize * 0.16);

    // Une tete de note est un ovale incline : c'est ce qui la distingue d'un
    // point, et ce qui la fait tenir dans un interligne.
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-0.34); // environ 20 degres
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: spaceSize * (head == NoteHead.whole ? 1.7 : 1.35),
        height: spaceSize * 0.95,
      ),
      p,
    );
    canvas.restore();

    if (note.accidental == Accidental.sharp) {
      _paintSharp(canvas, x, y, color);
    }
  }

  /// Diese provisoire, tire de la police systeme. Bravura fournira le vrai
  /// glyphe au lot G1.
  void _paintSharp(Canvas canvas, double x, double y, Color color) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '♯',
        style: TextStyle(color: color, fontSize: spaceSize * 2.6),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - spaceSize * 1.1 - tp.width, y - tp.height / 2));
  }

  Color _colorFor(PlacedNote note) => colorOf?.call(note.note) ?? inkColor;

  @override
  bool shouldRepaint(_ScorePainter old) =>
      old.layout != layout ||
      old.spaceSize != spaceSize ||
      old.inkColor != inkColor ||
      old.colorOf != colorOf;
}
