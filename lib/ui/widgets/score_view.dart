import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/music/passage.dart';
import '../../core/music/score_note.dart';
import '../../core/score/smufl.dart';
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
/// **Les symboles viennent de Bravura, les traits sont dessines.** Cle, tetes,
/// alterations, crochets et points sont des glyphes SMuFL : les dessiner a la
/// main ne donnerait jamais le meme trace. Lignes de portee, lignes
/// supplementaires, hampes, barres de mesure et ligatures restent des
/// primitives, parce que ce sont des traits dont la longueur depend de la mise
/// en page : une police ne peut pas les fournir.
class ScoreView extends StatelessWidget {
  const ScoreView({
    required this.passage,
    this.colorOf,
    this.cursorTick,
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

  /// Instant courant, en ticks, ou `null` a l'arret. Trace le curseur.
  final int? cursorTick;

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
    // rogner ni les lignes supplementaires ni les hampes. La cle de sol
    // deborde elle aussi de la portee, mais moins qu'une hampe pleine
    // longueur : la reserve faite pour les hampes la contient deja.
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
          cursorColor: scheme.primary,
          cursorTick: cursorTick,
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
    required this.cursorColor,
    required this.cursorTick,
    required this.colorOf,
  });

  final StaffLayout layout;
  final StemsAndBeams stems;
  final double topSpaces;
  final double spaceSize;
  final Color inkColor;
  final Color cursorColor;
  final int? cursorTick;
  final NoteColorResolver? colorOf;

  /// Abscisse du bord gauche de la cle, en espaces.
  static const double _clefXSpaces = 1;

  double _x(double spaces) => spaces * spaceSize;
  double _y(double spaces) => (spaces - topSpaces) * spaceSize;
  double _yOfStep(int step) => _y(StaffGeometry.yInSpaces(step));

  @override
  void paint(Canvas canvas, Size size) {
    // Le curseur passe en premier : il glisse derriere les notes plutot que
    // de les barrer. On veut lire la note, pas le trait.
    _paintCursor(canvas, size);
    _paintStaff(canvas, size);
    _paintBarlines(canvas);
    _paintClef(canvas);

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

  // --- Glyphes SMuFL -------------------------------------------------------

  /// Compose un glyphe. La taille de police vaut quatre interlignes : c'est
  /// la convention SMuFL, et elle suffit a mettre toute la police a l'echelle.
  TextPainter _glyph(String glyph, Color color) => TextPainter(
        text: TextSpan(
          text: glyph,
          style: TextStyle(
            color: color,
            fontFamily: Smufl.fontFamily,
            fontSize: Smufl.fontSizeForSpace(spaceSize),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Pose un glyphe a son origine SMuFL : bord gauche a [xSpaces], ligne de
  /// base a [baselineSpaces]. Toute la table des glyphes se place ainsi, ce
  /// qui evite un cas particulier par symbole.
  void _drawGlyph(
    Canvas canvas,
    TextPainter tp,
    double xSpaces,
    double baselineSpaces,
  ) {
    final double baseline =
        tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(_x(xSpaces), _y(baselineSpaces) - baseline));
  }

  double _widthSpaces(TextPainter tp) => tp.width / spaceSize;

  void _paintClef(Canvas canvas) {
    final TextPainter tp = _glyph(Smufl.gClef, inkColor);
    // La boucle de la cle enroule la ligne du sol4 : c'est la ligne de base
    // du glyphe qui s'y pose, pas son centre.
    _drawGlyph(
      canvas,
      tp,
      _clefXSpaces,
      StaffGeometry.yInSpaces(Smufl.gClefLineStep),
    );
  }

  // --- Traits --------------------------------------------------------------

  void _paintCursor(Canvas canvas, Size size) {
    final int? tick = cursorTick;
    if (tick == null) {
      return;
    }
    final double x = _x(layout.xForTick(tick));
    final Paint p = Paint()..color = cursorColor.withValues(alpha: 0.22);
    // Une bande, pas un trait : a 70 cm sur un pupitre, un trait d'un pixel
    // se perd, et une bande se suit du coin de l'oeil.
    canvas.drawRect(
      Rect.fromLTRB(x - spaceSize * 0.6, 0, x + spaceSize * 0.6, size.height),
      p,
    );
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
      _paintFlag(canvas, stem);
    }
  }

  void _paintFlag(Canvas canvas, Stem stem) {
    final String? glyph = Smufl.flagFor(stem.flagCount, stem.direction);
    if (glyph == null) {
      return;
    }
    // Un glyphe de crochet porte deja tous les crochets de sa figure : celui
    // de la double croche en dessine deux. On ne les empile pas, contrairement
    // aux ligatures. Son origine est le point ou il rejoint la hampe.
    _drawGlyph(
      canvas,
      _glyph(glyph, _colorFor(layout.notes[stem.noteIndex])),
      stem.xSpaces,
      stem.tipYSpaces,
    );
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

  // --- Notes ---------------------------------------------------------------

  void _paintNote(Canvas canvas, PlacedNote note) {
    final NoteHead head = StemsAndBeams.headFor(
      note.note.durationTicks,
      layout.ticksPerBeat,
    );
    final Color color = _colorFor(note);
    final TextPainter tp = _glyph(Smufl.noteheadFor(head), color);
    final double largeur = _widthSpaces(tp);

    // La mise en page situe le *centre* de la tete ; le glyphe se pose par son
    // bord gauche. La hampe, elle, est calee a un demi-espace du centre : elle
    // mord donc tres legerement dans la tete, ce qui est ce qu'on veut.
    final double gauche = note.xSpaces - largeur / 2;
    _drawGlyph(canvas, tp, gauche, note.yInSpaces);

    if (note.accidental == Accidental.sharp) {
      _paintAccidental(canvas, note, gauche, color);
    }
    if (StemsAndBeams.isDotted(note.note.durationTicks, layout.ticksPerBeat)) {
      _paintDot(canvas, note, gauche + largeur, color);
    }
  }

  void _paintAccidental(
    Canvas canvas,
    PlacedNote note,
    double headLeftSpaces,
    Color color,
  ) {
    final TextPainter tp = _glyph(Smufl.accidentalSharp, color);
    // L'alteration se colle a gauche de la tete, a la meme hauteur.
    _drawGlyph(
      canvas,
      tp,
      headLeftSpaces - _accidentalGapSpaces - _widthSpaces(tp),
      note.yInSpaces,
    );
  }

  void _paintDot(
    Canvas canvas,
    PlacedNote note,
    double headRightSpaces,
    Color color,
  ) {
    // Un point ne se pose jamais sur une ligne : quand la note est sur une
    // ligne, il monte dans l'interligne au-dessus.
    final double y = note.isOnLine ? note.yInSpaces - 0.5 : note.yInSpaces;
    _drawGlyph(
      canvas,
      _glyph(Smufl.augmentationDot, color),
      headRightSpaces + _dotGapSpaces,
      y,
    );
  }

  static const double _accidentalGapSpaces = 0.25;
  static const double _dotGapSpaces = 0.3;

  Color _colorFor(PlacedNote note) => colorOf?.call(note.note) ?? inkColor;

  @override
  bool shouldRepaint(_ScorePainter old) =>
      old.layout != layout ||
      old.spaceSize != spaceSize ||
      old.inkColor != inkColor ||
      old.cursorTick != cursorTick ||
      old.cursorColor != cursorColor ||
      old.colorOf != colorOf;
}
