import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/music/meter.dart';
import '../../core/music/passage.dart';
import '../../core/music/score_note.dart';
import '../../core/score/score_fit.dart';
import '../../core/score/score_layout.dart';
import '../../core/score/smufl.dart';
import '../../core/score/staff_geometry.dart';
import '../../core/score/staff_layout.dart';
import '../../core/score/stems_and_beams.dart';

/// Couleur d'une note, pour le retour visuel en direct.
typedef NoteColorResolver = Color? Function(ScoreNote note);

/// Hauteur a montrer **en clair derriere** une note, ou `null`.
///
/// Sert a la partition de ce qui a ete joue : la tete gravee est celle qu'on a
/// entendue, et celle qui etait ecrite reste visible a sa place. On lit alors
/// l'erreur comme un intervalle, ce qui est exactement ce qu'un professeur
/// montre du doigt.
typedef GhostMidiResolver = int? Function(ScoreNote note);

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
    this.ghostMidiOf,
    this.cursorTick,
    this.cursorUncertain = false,
    this.spaceSize,
    this.maxSystems,
    this.maxSpaceSize = defaultMaxSpaceSize,
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

  /// La taille en dessous de laquelle on ne descend **que s'il le faut**.
  ///
  /// C'est le confort vise : en dessous, la portee devient illisible a 70 cm
  /// sur un pupitre. Le balayage s'y arrete tant qu'une taille plus grande
  /// passe.
  static const double minSpaceSize = 7;

  /// Le plancher absolu : en dessous, ce n'est plus une portee.
  ///
  /// **Mieux vaut une portee serree qu'une portee coupee.** Un exercice de
  /// quatre mesures ne tient pas dans un S22 hors plein ecran : il demande 336
  /// sur 434 points la ou il en reste 313, et 623 sur 210 la ou il en reste
  /// 544 sur 188. S'arreter au confort laissait la partition sortir du cadre
  /// de 22 points en paysage et de 121 en portrait, sans que rien ne le dise
  /// -- l'enfant ne voyait qu'un bout de sa ligne et aurait du pousser du
  /// doigt en plein morceau.
  ///
  /// On resserre donc plutot que de couper. La partition devient petite, mais
  /// elle est **entiere** : on voit la forme de ce qu'on joue, et le plein
  /// ecran (lot D10) lui rend sa taille d'un appui.
  static const double crampedSpaceSize = 4;

  /// Au-dela, une portee de deux mesures s'etalerait sur tout l'ecran --
  /// ce qui est un defaut partout, sauf en plein ecran ou c'est le but.
  static const double defaultMaxSpaceSize = 16;

  /// Ce que le plein ecran s'autorise.
  ///
  /// **La hauteur recuperee doit se voir sur les notes**, pas se transformer
  /// en blanc. Un plafond seul ne grossit rien de force : `_choisirEspace`
  /// balaie toujours du plus grand au plus petit et retient le premier qui
  /// tient, donc relever le plafond ne fait que lui laisser le choix.
  static const double pleinEcranMaxSpaceSize = 32;

  final Passage passage;

  /// Rend la couleur d'une note, ou `null` pour la couleur par defaut.
  final NoteColorResolver? colorOf;

  /// Rend la hauteur a montrer en clair derriere une note, ou `null`.
  final GhostMidiResolver? ghostMidiOf;

  /// Instant courant, en ticks, ou `null` a l'arret. Trace le curseur.
  final int? cursorTick;

  /// Le suiveur doute de la position (lot S5) : le curseur passe en encre
  /// neutre. Il ne disparait pas -- l'eleve verrait l'application "partie" --
  /// mais il cesse d'affirmer.
  final bool cursorUncertain;

  /// Hauteur d'un interligne, en pixels. La portee en fait quatre.
  ///
  /// `null` laisse le widget la deduire de la place disponible.
  final double? spaceSize;

  /// Plafond de l'interligne choisi automatiquement.
  final double maxSpaceSize;

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
    // On vise le confort, et on ne descend en dessous que si rien n'y passe :
    // une portee serree vaut mieux qu'une portee coupee, mais elle ne se
    // resserre jamais pour le plaisir.
    for (double taille = maxSpaceSize;
        taille >= crampedSpaceSize;
        taille -= 0.5) {
      if (_tientDans(constraints, taille)) {
        return taille;
      }
    }
    return crampedSpaceSize;
  }

  /// Les pas des tetes en clair, a couvrir par la reserve verticale.
  ///
  /// Elles ne sont pas gravees -- la mise en page ne les connait pas -- mais
  /// elles sont dessinees : la reserve doit les contenir, sinon une note
  /// ecrite loin de celle qui a ete jouee se ferait rogner.
  List<int> _ghostSteps() {
    final GhostMidiResolver? resoudre = ghostMidiOf;
    if (resoudre == null) {
      return const <int>[];
    }
    final List<int> pas = <int>[];
    for (final ScoreNote note in passage.notes) {
      final int? midi = resoudre(note);
      if (midi != null) {
        pas.add(StaffGeometry.stepOf(midi));
      }
    }
    return pas;
  }

  bool _tientDans(BoxConstraints constraints, double taille) {
    // En defilement, aucune largeur ne borne la ligne : tout tient sur un
    // seul systeme, et deborder en largeur est le principe meme. Seule la
    // hauteur contraint alors la taille des notes.
    final bool defilement = mode == ScoreDisplayMode.scrolling;
    return scoreFits(
      passage,
      widthSpaces: defilement ? double.infinity : constraints.maxWidth / taille,
      checkWidth: !defilement,
      heightSpaces: constraints.hasBoundedHeight
          ? constraints.maxHeight / taille
          : double.infinity,
      maxSystems: defilement ? 1 : maxSystems,
      alsoCover: _ghostSteps(),
    );
  }

  ScoreLayout _layoutPour(double largeurEspaces, {bool justify = false}) =>
      ScoreLayout.of(
        passage,
        justify: justify,
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
    // **La justification n'intervient qu'au dessin.** Le choix de
    // l'interligne, lui, se fait sur les largeurs naturelles : sur des lignes
    // deja etirees, "est-ce que ca tient" serait vrai par construction, et la
    // boucle retiendrait toujours la plus grosse taille.
    final ScoreLayout layout = _layoutPour(
      largeurDisponible / spaceSize,
      justify: true,
    );
    final SystemMetrics metrics =
        SystemMetrics.of(layout, alsoCover: _ghostSteps());
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
                cursorColor: cursorUncertain ? scheme.outline : scheme.primary,
                cursorTick: cursorTick,
                colorOf: colorOf,
                ghostMidiOf: ghostMidiOf,
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
    required this.ghostMidiOf,
  });

  final ScoreLayout layout;
  final SystemMetrics metrics;
  final double spaceSize;
  final Color inkColor;
  final Color cursorColor;
  final int? cursorTick;
  final NoteColorResolver? colorOf;
  final GhostMidiResolver? ghostMidiOf;

  /// Ce qu'il reste de l'encre pour une tete qui n'a pas ete jouee.
  ///
  /// Assez pale pour qu'on ne la confonde pas avec une note gravee, assez
  /// visible pour qu'on lise l'intervalle qui l'en separe.
  static const double _ghostAlpha = 0.3;

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
    _paintKeySignature(canvas, staff);
    _paintTimeSignature(canvas, staff);
    for (final PlacedRest rest in staff.rests) {
      _paintRest(canvas, staff, rest);
    }

    final Map<int, Beam> beamOfNote = <int, Beam>{};
    for (final Beam beam in stems.beams) {
      for (final int i in beam.noteIndices) {
        beamOfNote[i] = beam;
      }
    }

    if (ghostMidiOf != null) {
      // En premier, donc derriere tout le reste : c'est un rappel, pas une
      // seconde voix.
      for (final PlacedNote note in staff.notes) {
        _paintGhost(canvas, staff, note);
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
    for (int i = 0; i < staff.notes.length; i++) {
      _paintTie(canvas, staff, i, stems);
    }
    for (final PlacedNote note in staff.notes) {
      _paintNote(canvas, staff, note);
    }
  }

  void _paintKeySignature(Canvas canvas, StaffLayout staff) {
    final int? quintes = staff.keyFifths;
    if (quintes == null || quintes == 0) {
      return;
    }
    final String glyph =
        quintes > 0 ? Smufl.accidentalSharp : Smufl.accidentalFlat;
    final List<int> pas = StaffGeometry.keySignatureSteps(quintes);
    for (int i = 0; i < pas.length; i++) {
      _drawGlyph(
        canvas,
        _glyph(glyph, inkColor),
        staff.keySignatureXSpaces + i * StaffLayout.keyAccidentalSpaces,
        StaffGeometry.yInSpaces(pas[i]),
      );
    }
  }

  void _paintTimeSignature(Canvas canvas, StaffLayout staff) {
    final Meter? chiffrage = staff.meter;
    if (chiffrage == null) {
      return;
    }
    final TextPainter haut =
        _glyph(Smufl.timeSigDigits(chiffrage.beats), inkColor);
    final TextPainter bas =
        _glyph(Smufl.timeSigDigits(chiffrage.beatType), inkColor);
    // Les deux chiffres se centrent l'un sur l'autre : 12/8 n'a pas la
    // largeur de 6/8.
    final double largeur = math.max(_widthSpaces(haut), _widthSpaces(bas));
    final double x = staff.timeSignatureXSpaces;
    _drawGlyph(
      canvas,
      haut,
      x + (largeur - _widthSpaces(haut)) / 2,
      StaffGeometry.yInSpaces(2),
    );
    _drawGlyph(
      canvas,
      bas,
      x + (largeur - _widthSpaces(bas)) / 2,
      StaffGeometry.yInSpaces(-2),
    );
  }

  void _paintRest(Canvas canvas, StaffLayout staff, PlacedRest rest) {
    final String glyph = rest.wholeBar
        ? Smufl.restWhole
        : Smufl.restFor(rest.durationTicks, staff.ticksPerBeat);
    final TextPainter tp = _glyph(glyph, inkColor);
    final double largeur = _widthSpaces(tp);
    final double gauche = rest.xSpaces - largeur / 2;
    _drawGlyph(
      canvas,
      tp,
      gauche,
      StaffGeometry.yInSpaces(Smufl.restBaselineStep(glyph)),
    );
    if (!rest.wholeBar &&
        StemsAndBeams.isDotted(rest.durationTicks, staff.ticksPerBeat)) {
      _drawGlyph(
        canvas,
        _glyph(Smufl.augmentationDot, inkColor),
        gauche + largeur + _dotGapSpaces,
        -0.5,
      );
    }
  }

  /// La liaison de tenue entre une tete et la suivante de la meme note.
  ///
  /// **Du cote oppose a la hampe**, comme sur toute partition : sous la note
  /// si la hampe monte, dessus si elle descend. Une tenue qui passe a la
  /// ligne s'arrete au bord de la portee.
  void _paintTie(
    Canvas canvas,
    StaffLayout staff,
    int index,
    StemsAndBeams stems,
  ) {
    final PlacedNote note = staff.notes[index];
    if (!note.tiedToNext) {
      return;
    }
    final PlacedNote? suivante = index + 1 < staff.notes.length &&
            identical(staff.notes[index + 1].note, note.note)
        ? staff.notes[index + 1]
        : null;
    StemDirection sens = note.step >= 0 ? StemDirection.down : StemDirection.up;
    for (final Stem s in stems.stems) {
      if (s.noteIndex == index) {
        sens = s.direction;
      }
    }
    final double dessous = sens == StemDirection.up ? 1 : -1;
    final double x1 = note.xSpaces + 0.7;
    final double x2 =
        suivante == null ? staff.widthSpaces - 0.5 : suivante.xSpaces - 0.7;
    final double y = note.yInSpaces + dessous * 0.7;
    final double creux = dessous * math.min(1.2, 0.3 + (x2 - x1) * 0.08);
    final Path arc = Path()
      ..moveTo(_x(x1), _y(y))
      ..quadraticBezierTo(
        _x((x1 + x2) / 2),
        _y(y + creux),
        _x(x2),
        _y(y),
      )
      ..quadraticBezierTo(
        _x((x1 + x2) / 2),
        // Une epaisseur fixe au milieu, qui s'affine aux extremites : c'est
        // l'allure d'une liaison gravee, et elle reste visible a 70 cm.
        _y(y + creux - dessous * 0.3),
        _x(x1),
        _y(y),
      )
      ..close();
    canvas.drawPath(
      arc,
      Paint()
        ..color = _colorFor(note)
        ..style = PaintingStyle.fill,
    );
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
      note.durationTicks,
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

    if (note.accidental != Accidental.none) {
      _paintAccidental(canvas, note, gauche, color);
    }
    if (StemsAndBeams.isDotted(note.durationTicks, staff.ticksPerBeat)) {
      _paintDot(canvas, note, gauche + largeur, color);
    }
  }

  /// La tete qui etait ecrite, en clair, derriere celle qui a ete jouee.
  ///
  /// **Une tete seule : ni hampe, ni crochet, ni point.** Une seconde figure
  /// complete se lirait comme une seconde voix, ce que ce graveur ne sait pas
  /// faire et n'a pas a savoir faire (ADR-007). Une tete pale au bout d'un
  /// intervalle se lit pour ce qu'elle est : la note qui etait ecrite la.
  void _paintGhost(Canvas canvas, StaffLayout staff, PlacedNote note) {
    if (note.isContinuation) {
      return;
    }
    final int? midi = ghostMidiOf?.call(note.note);
    if (midi == null) {
      return;
    }
    final Color pale = inkColor.withValues(alpha: _ghostAlpha);
    final int step = StaffGeometry.stepOf(midi);
    final double y = StaffGeometry.yInSpaces(step);
    final bool sharp = StaffGeometry.accidentalOf(midi) == Accidental.sharp;

    final TextPainter tp = _glyph(
      Smufl.noteheadFor(
        StemsAndBeams.headFor(note.durationTicks, staff.ticksPerBeat),
      ),
      pale,
    );
    final double largeur = _widthSpaces(tp);

    // **Une seconde se pose a cote, jamais dessus.** C'est la regle de gravure
    // pour deux tetes voisines, et c'est ici le cas le plus frequent : un
    // demi-ton ou un ton d'ecart est l'erreur ordinaire. Sans ce decalage, les
    // deux tetes se chevauchent et ne font plus qu'une bavure -- constate sur
    // l'appareil, invisible aux tests.
    //
    // **A droite, parce que la gauche appartient aux alterations.** Decalee a
    // gauche, la tete en clair passait sous le diese de la note jouee, ce qui
    // brouillait les deux. A droite elle chevauche la hampe, ce qui est
    // exactement l'allure d'une seconde gravee.
    final double x =
        (step - note.step).abs() == 1 ? note.xSpaces + largeur : note.xSpaces;
    final double gauche = x - largeur / 2;

    // Un do# joue en do occupe le MEME pas : rien a deplacer, et pourtant la
    // note n'est pas la meme. C'est le diese en clair qui le dit -- et c'est
    // la faute la plus courante a cet age.
    if (step != note.step) {
      _paintGhostLedgers(canvas, x, step, pale);
      _drawGlyph(canvas, tp, gauche, y);
    }
    if (sharp) {
      final TextPainter alteration = _glyph(Smufl.accidentalSharp, pale);
      _drawGlyph(
        canvas,
        alteration,
        gauche - _accidentalGapSpaces - _widthSpaces(alteration),
        y,
      );
    }
  }

  void _paintGhostLedgers(
    Canvas canvas,
    double xSpaces,
    int step,
    Color couleur,
  ) {
    final List<int> steps = StaffGeometry.ledgerSteps(step);
    if (steps.isEmpty) {
      return;
    }
    final Paint p = Paint()
      ..color = couleur
      ..strokeWidth = math.max(1, spaceSize * 0.12);
    final double demi = spaceSize * 0.85;
    final double x = _x(xSpaces);
    for (final int s in steps) {
      final double y = _yOfStep(s);
      canvas.drawLine(Offset(x - demi, y), Offset(x + demi, y), p);
    }
  }

  void _paintAccidental(
    Canvas canvas,
    PlacedNote note,
    double headLeftSpaces,
    Color color,
  ) {
    final String? glyph = Smufl.accidentalFor(note.accidental);
    if (glyph == null) {
      return;
    }
    final TextPainter tp = _glyph(glyph, color);
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
      old.colorOf != colorOf ||
      old.ghostMidiOf != ghostMidiOf;
}
