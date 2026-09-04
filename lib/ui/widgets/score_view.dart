import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/music/passage.dart';
import '../../core/music/score_note.dart';
import '../../core/score/score_layout.dart';
import '../../core/score/smufl.dart';
import '../../core/score/staff_geometry.dart';
import '../../core/score/staff_layout.dart';
import '../../core/score/stems_and_beams.dart';

/// Couleur d'une note, pour le retour visuel en direct.
typedef NoteColorResolver = Color? Function(ScoreNote note);

/// Deux facons de lire un passage.
enum ScoreDisplayMode {
  /// La partition passe a la ligne, comme sur du papier. Tout est visible
  /// d'un coup d'oeil, les notes sont plus petites.
  systems,

  /// Une seule ligne qu'on pousse du doigt. Les notes restent grandes, mais
  /// on ne voit qu'un bout du passage.
  ///
  /// C'est [ScoreLayout] avec une largeur infinie : un seul systeme.
  scrolling,
}

/// La partition gravee, sur un ou plusieurs systemes.
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
    this.maxSystems,
    this.mode = ScoreDisplayMode.systems,
    this.zoom = 1,
    super.key,
  });

  /// Bornes du zoom. En dessous d'un demi la portee redevient illisible, et
  /// au-dela de trois une seule mesure remplit l'ecran.
  static const double minZoom = 0.5;
  static const double maxZoom = 3;

  /// Cle de la zone peinte. Sert aux tests a mesurer la partition elle-meme.
  static const Key canvasKey = Key('score-canvas');

  /// En dessous, la portee devient illisible a 70 cm sur un pupitre.
  static const double minSpaceSize = 7;

  /// Au-dela, une portee de deux mesures s'etalerait sur tout l'ecran.
  static const double maxSpaceSize = 16;

  final Passage passage;

  /// Rend la couleur d'une note, ou `null` pour la couleur par defaut.
  final NoteColorResolver? colorOf;

  /// Instant courant, en ticks, ou `null` a l'arret. Trace le curseur.
  final int? cursorTick;

  /// Hauteur d'un interligne, en pixels. La portee en fait quatre.
  ///
  /// `null` laisse le widget la deduire de la place disponible.
  final double? spaceSize;

  /// Nombre maximal de systemes. `null` laisse la geometrie decider.
  ///
  /// C'est par la que le mode paysage se distinguera du portrait : moins de
  /// hauteur, donc moins de lignes.
  final int? maxSystems;

  final ScoreDisplayMode mode;

  /// Grossissement demande par l'utilisateur, autour de la taille choisie
  /// automatiquement.
  ///
  /// **Le zoom refait la mise en page, il n'etire pas une image.** Agrandir
  /// veut dire moins de mesures par ligne et donc plus de lignes, exactement
  /// comme si on relisait la partition sur un plus petit format de papier.
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double base = spaceSize ?? _choisirEspace(constraints);
        final double espace = base * zoom.clamp(minZoom, maxZoom);
        return _build(context, espace, constraints);
      },
    );
  }

  /// Cherche le plus grand interligne qui laisse tout tenir dans la boite.
  ///
  /// On balaie du plus grand au plus petit et on garde le premier qui passe.
  /// Un interligne plus grand veut dire moins de mesures par ligne, donc plus
  /// de lignes, donc plus de hauteur : la premiere taille qui tient est bien
  /// la meilleure.
  double _choisirEspace(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) {
      return maxSpaceSize;
    }
    for (double taille = maxSpaceSize; taille > minSpaceSize; taille -= 0.5) {
      if (_tientDans(constraints, taille)) {
        return taille;
      }
    }
    return minSpaceSize;
  }

  bool _tientDans(BoxConstraints constraints, double taille) {
    final ScoreLayout layout = _layoutPour(constraints.maxWidth / taille);
    final SystemMetrics metrics = SystemMetrics.of(layout);
    // En defilement, deborder en largeur est le principe meme : seule la
    // hauteur contraint la taille des notes.
    if (mode == ScoreDisplayMode.systems &&
        layout.widthSpaces * taille > constraints.maxWidth + 0.01) {
      return false;
    }
    if (!constraints.hasBoundedHeight) {
      return true;
    }
    final double hauteur =
        metrics.stackHeightSpaces(layout.systemCount) * taille;
    return hauteur <= constraints.maxHeight;
  }

  ScoreLayout _layoutPour(double largeurEspaces) => ScoreLayout.of(
        passage,
        // En defilement, aucune largeur ne borne la ligne : tout tient sur un
        // seul systeme, et c'est le doigt qui parcourt la partition.
        maxWidthSpaces: mode == ScoreDisplayMode.scrolling
            ? double.infinity
            : largeurEspaces,
        maxSystems: mode == ScoreDisplayMode.scrolling ? 1 : maxSystems,
      );

  Widget _build(
    BuildContext context,
    double spaceSize,
    BoxConstraints constraints,
  ) {
    final double largeurDisponible = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : ScoreLayout.of(passage, maxWidthSpaces: double.infinity).widthSpaces *
            spaceSize;
    final ScoreLayout layout = _layoutPour(largeurDisponible / spaceSize);
    final SystemMetrics metrics = SystemMetrics.of(layout);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Size size = Size(
      layout.widthSpaces * spaceSize,
      metrics.stackHeightSpaces(layout.systemCount) * spaceSize,
    );

    // Une mesure trop dense peut deborder en largeur, et un passage trop long
    // en hauteur : dans les deux cas on defile plutot que de rogner.
    //
    // La contrainte de hauteur minimale centre la partition quand elle tient
    // dans la zone, sans empecher le defilement quand elle n'y tient pas : un
    // `Center` seul collerait le contenu en haut des qu'il deborde.
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: ConstrainedBox(
        // La hauteur minimale centre la partition quand elle tient dans la
        // zone, sans empecher le defilement quand elle n'y tient pas : un
        // `Center` seul collerait le contenu en haut des qu'il deborde.
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        ),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CustomPaint(
              // Cle explicite : les barres de defilement peignent elles aussi,
              // et un test qui prendrait "le dernier CustomPaint" mesurerait
              // l'une d'elles sans s'en apercevoir.
              key: canvasKey,
              size: size,
              painter: _ScorePainter(
                layout: layout,
                metrics: metrics,
                spaceSize: spaceSize,
                inkColor: scheme.onSurface,
                cursorColor: scheme.primary,
                cursorTick: cursorTick,
                colorOf: colorOf,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScorePainter extends CustomPainter {
  _ScorePainter({
    required this.layout,
    required this.metrics,
    required this.spaceSize,
    required this.inkColor,
    required this.cursorColor,
    required this.cursorTick,
    required this.colorOf,
  });

  final ScoreLayout layout;
  final SystemMetrics metrics;
  final double spaceSize;
  final Color inkColor;
  final Color cursorColor;
  final int? cursorTick;
  final NoteColorResolver? colorOf;

  /// Abscisse du bord gauche de la cle, en espaces.
  static const double _clefXSpaces = 1;

  static const double _accidentalGapSpaces = 0.25;
  static const double _dotGapSpaces = 0.3;

  double _x(double spaces) => spaces * spaceSize;

  /// Ordonnee **dans le systeme courant** : la ligne du milieu est a zero.
  double _y(double spaces) => spaces * spaceSize;
  double _yOfStep(int step) => _y(StaffGeometry.yInSpaces(step));

  @override
  void paint(Canvas canvas, Size size) {
    final (int systemeDuCurseur, double xCurseur) =
        cursorTick == null ? (-1, 0.0) : layout.positionOfTick(cursorTick!);

    for (final StaffSystem system in layout.systems) {
      canvas.save();
      // Chaque systeme est peint dans son propre repere, la ligne du milieu
      // a l'ordonnee zero. Tout le code de dessin ignore ainsi qu'il existe
      // plusieurs lignes.
      canvas.translate(0, metrics.originOfSystem(system.index) * spaceSize);
      _paintSystem(
        canvas,
        system,
        size.width,
        cursorX: system.index == systemeDuCurseur ? xCurseur : null,
      );
      canvas.restore();
    }
  }

  void _paintSystem(
    Canvas canvas,
    StaffSystem system,
    double largeur, {
    required double? cursorX,
  }) {
    final StaffLayout staff = system.layout;
    // Les ligatures ne franchissent jamais une barre de mesure, et on ne coupe
    // qu'aux barres : ligaturer systeme par systeme donne donc exactement le
    // meme resultat que sur une ligne unique.
    final StemsAndBeams stems = StemsAndBeams.of(staff);

    if (cursorX != null) {
      // Le curseur passe en premier : il glisse derriere les notes plutot que
      // de les barrer. On veut lire la note, pas le trait.
      _paintCursor(canvas, cursorX);
    }
    _paintStaff(canvas, system.widthSpaces);
    _paintBarlines(canvas, staff);
    _paintClef(canvas);

    final Map<int, Beam> beamOfNote = <int, Beam>{};
    for (final Beam beam in stems.beams) {
      for (final int i in beam.noteIndices) {
        beamOfNote[i] = beam;
      }
    }

    for (final PlacedNote note in staff.notes) {
      _paintLedgers(canvas, note);
    }
    for (final Stem stem in stems.stems) {
      _paintStem(canvas, staff, stem, beamOfNote[stem.noteIndex]);
    }
    for (final Beam beam in stems.beams) {
      _paintBeam(canvas, staff, beam);
    }
    for (final PlacedNote note in staff.notes) {
      _paintNote(canvas, staff, note);
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
  /// base a [baselineSpaces].
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
    // Chaque systeme reprend la cle : une portee sans cle ne se lit pas.
    final TextPainter tp = _glyph(Smufl.gClef, inkColor);
    _drawGlyph(
      canvas,
      tp,
      _clefXSpaces,
      StaffGeometry.yInSpaces(Smufl.gClefLineStep),
    );
  }

  // --- Traits --------------------------------------------------------------

  void _paintCursor(Canvas canvas, double xSpaces) {
    final Paint p = Paint()..color = cursorColor.withValues(alpha: 0.22);
    // Une bande, pas un trait : a 70 cm sur un pupitre, un trait d'un pixel
    // se perd, et une bande se suit du coin de l'oeil.
    final double x = _x(xSpaces);
    canvas.drawRect(
      Rect.fromLTRB(
        x - spaceSize * 0.6,
        _y(metrics.topSpaces),
        x + spaceSize * 0.6,
        _y(metrics.bottomSpaces),
      ),
      p,
    );
  }

  void _paintStaff(Canvas canvas, double largeurSpaces) {
    final Paint p = Paint()
      ..color = inkColor.withValues(alpha: 0.55)
      ..strokeWidth = math.max(1, spaceSize * 0.11);
    final double largeur = _x(largeurSpaces);
    for (int step = StaffGeometry.bottomLineStep;
        step <= StaffGeometry.topLineStep;
        step += 2) {
      final double y = _yOfStep(step);
      canvas.drawLine(Offset(0, y), Offset(largeur, y), p);
    }
  }

  void _paintBarlines(Canvas canvas, StaffLayout staff) {
    final Paint p = Paint()
      ..color = inkColor.withValues(alpha: 0.55)
      ..strokeWidth = math.max(1, spaceSize * 0.13);
    final double haut = _yOfStep(StaffGeometry.topLineStep);
    final double bas = _yOfStep(StaffGeometry.bottomLineStep);
    for (final double xSpaces in staff.barlineXSpaces) {
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

  void _paintStem(Canvas canvas, StaffLayout staff, Stem stem, Beam? beam) {
    final PlacedNote note = staff.notes[stem.noteIndex];
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
      _paintFlag(canvas, staff, stem);
    }
  }

  void _paintFlag(Canvas canvas, StaffLayout staff, Stem stem) {
    final String? glyph = Smufl.flagFor(stem.flagCount, stem.direction);
    if (glyph == null) {
      return;
    }
    // Un glyphe de crochet porte deja tous les crochets de sa figure : celui
    // de la double croche en dessine deux. On ne les empile pas, contrairement
    // aux ligatures. Son origine est le point ou il rejoint la hampe.
    _drawGlyph(
      canvas,
      _glyph(glyph, _colorFor(staff.notes[stem.noteIndex])),
      stem.xSpaces,
      stem.tipYSpaces,
    );
  }

  void _paintBeam(Canvas canvas, StaffLayout staff, Beam beam) {
    final Paint p = Paint()
      ..color = _colorFor(staff.notes[beam.noteIndices.first])
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

  void _paintNote(Canvas canvas, StaffLayout staff, PlacedNote note) {
    final NoteHead head = StemsAndBeams.headFor(
      note.note.durationTicks,
      staff.ticksPerBeat,
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
    if (StemsAndBeams.isDotted(note.note.durationTicks, staff.ticksPerBeat)) {
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
