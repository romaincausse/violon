import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/music/finger_pattern.dart';
import '../../core/music/fingerboard.dart';
import '../../core/music/pitch_utils.dart';

/// Quelle corde, quel doigt.
///
/// **Le seul endroit du projet ou un schema de manche a un sens.** Ailleurs,
/// l'eleve lit sa partition papier et l'application l'ecoute (ADR-009) : lui
/// dessiner un manche reviendrait a lui apprendre a lire autre chose que de la
/// musique. Ici il ne lit rien -- il cherche un doigt, et c'est un doigt qu'on
/// lui montre.
///
/// **Et a cote de la musique, jamais dessus.** Un manche en surimpression
/// couvrirait ce qu'il doit lire au moment precis ou il en a besoin.
class FingerboardView extends StatelessWidget {
  const FingerboardView({
    required this.pattern,
    required this.target,
    this.height = 180,
    super.key,
  });

  /// L'ecartement de doigts en cours : il dit ou tombent les quatre doigts.
  final FingerPattern pattern;

  /// La pose a montrer, ou `null` pour n'en montrer aucune.
  final FingerPlacement? target;

  final double height;

  static const Key fingerboardKey = Key('schema-de-manche');

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: fingerboardKey,
      height: height,
      child: CustomPaint(
        painter: _FingerboardPainter(
          pattern: pattern,
          target: target,
          ink: scheme.onSurface,
          accent: scheme.primary,
          onAccent: scheme.onPrimary,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FingerboardPainter extends CustomPainter {
  _FingerboardPainter({
    required this.pattern,
    required this.target,
    required this.ink,
    required this.accent,
    required this.onAccent,
  });

  final FingerPattern pattern;
  final FingerPlacement? target;
  final Color ink;
  final Color accent;
  final Color onAccent;

  /// Place laissee en haut pour le nom des cordes et le rond de corde a vide.
  static const double _enTete = 44;

  /// Marge laterale, pour que la corde de sol ne colle pas au bord.
  static const double _marge = 24;

  @override
  void paint(Canvas canvas, Size size) {
    const double hautDuManche = _enTete;
    final double basDuManche = size.height - 6;
    final double longueur = basDuManche - hautDuManche;
    const List<int> cordes = Fingerboard.strings;
    final double pas =
        (size.width - 2 * _marge) / math.max(1, cordes.length - 1);

    _peindreLeSillet(canvas, size, hautDuManche);
    for (int i = 0; i < cordes.length; i++) {
      final double x = _marge + i * pas;
      final bool visee = target?.stringMidi == cordes[i];
      _peindreLaCorde(canvas, x, hautDuManche, basDuManche, visee);
      _nommerLaCorde(canvas, x, cordes[i], visee);
      if (visee) {
        _peindreLesDoigts(canvas, x, hautDuManche, longueur);
      }
    }
  }

  /// Le sillet : le trait d'ou partent les cordes, et l'origine des distances.
  void _peindreLeSillet(Canvas canvas, Size size, double y) {
    canvas.drawRect(
      Rect.fromLTRB(_marge - 10, y - 3, size.width - _marge + 10, y),
      Paint()..color = ink,
    );
  }

  void _peindreLaCorde(
    Canvas canvas,
    double x,
    double haut,
    double bas,
    bool visee,
  ) {
    canvas.drawLine(
      Offset(x, haut),
      Offset(x, bas),
      Paint()
        // La corde visee est appuyee, les trois autres restent presentes :
        // on montre une corde **parmi quatre**, pas une corde seule.
        ..color = visee ? ink : ink.withValues(alpha: 0.25)
        ..strokeWidth = visee ? 3 : 1.5,
    );
  }

  void _nommerLaCorde(Canvas canvas, double x, int midi, bool visee) {
    final String nom = PitchUtils.noteName(midi).replaceAll(RegExp(r'\d'), '');
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: nom,
        style: TextStyle(
          color: visee ? ink : ink.withValues(alpha: 0.45),
          fontSize: 13,
          fontWeight: visee ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, 0));
  }

  /// Les quatre doigts de l'ecartement, et celui qu'on demande.
  ///
  /// **Les trois autres sont la, en clair.** Un doigt seul ne dit pas ou est
  /// le demi-ton, et c'est precisement ce que l'ecartement fait travailler :
  /// on doit voir que le 2 et le 3 se touchent.
  void _peindreLesDoigts(
    Canvas canvas,
    double x,
    double haut,
    double longueur,
  ) {
    final FingerPlacement? vise = target;
    // **Rapporte a ce qu'on dessine, pas a la corde entiere.** La premiere
    // position n'occupe que le premier tiers d'une corde : mesuree sur la
    // corde entiere, elle s'ecrase en haut du schema et les quatre doigts se
    // chevauchent -- constate sur l'appareil.
    final double echelle = Fingerboard.fraction(Fingerboard.drawnSemitones);
    final List<double> ordonnees = <double>[
      for (int doigt = 1; doigt <= 4; doigt++)
        haut +
            Fingerboard.fraction(pattern.semitones[doigt]) / echelle * longueur,
    ];
    final double rayon = _rayonPour(ordonnees);
    for (int doigt = 1; doigt <= 4; doigt++) {
      final bool cest = vise != null && vise.finger == doigt;
      _peindreUnDoigt(
          canvas, Offset(x, ordonnees[doigt - 1]), doigt, cest, rayon);
    }
    if (vise != null && vise.isOpenString) {
      // La corde a vide se marque au sillet, comme dans toute notation de
      // doigte : un rond vide, et pas un doigt pose.
      canvas.drawCircle(
        Offset(x, haut - 17),
        8,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  /// Le rayon d'une pastille, deduit de l'ecart le plus serre.
  ///
  /// **Une taille fixe ne peut pas marcher.** Deux doigts serres sont separes
  /// d'un demi-ton : dix-sept points de haut en portrait, onze en paysage.
  /// Une pastille reglee a la main mord sur sa voisine des que la place se
  /// reduit -- constate sur l'appareil, puis sur les chiffres. Le rayon suit
  /// donc l'ecart, et le chevauchement devient impossible par construction.
  ///
  /// **Et la meme pour les quatre**, donc : grossir celui qu'on demande
  /// reviendrait a le faire mordre sur ses voisins. Il se distingue par la
  /// couleur, qui ne prend pas de place.
  static double _rayonPour(List<double> ordonnees) {
    double plusSerre = double.infinity;
    for (int i = 1; i < ordonnees.length; i++) {
      plusSerre = math.min(plusSerre, ordonnees[i] - ordonnees[i - 1]);
    }
    return (plusSerre * 0.45).clamp(3, 11);
  }

  void _peindreUnDoigt(
    Canvas canvas,
    Offset centre,
    int doigt,
    bool vise,
    double rayon,
  ) {
    canvas.drawCircle(
      centre,
      rayon,
      Paint()..color = vise ? accent : ink.withValues(alpha: 0.13),
    );
    // En dessous, le chiffre ne se lit plus et devient une tache : la
    // pastille se suffit alors, et c'est la couleur qui dit lequel.
    if (rayon < 6) {
      return;
    }
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '$doigt',
        style: TextStyle(
          color: vise ? onAccent : ink.withValues(alpha: 0.5),
          fontSize: rayon * 1.35,
          fontWeight: vise ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_FingerboardPainter old) =>
      old.target?.midi != target?.midi ||
      old.target?.stringMidi != target?.stringMidi ||
      old.pattern != pattern ||
      old.ink != ink ||
      old.accent != accent;
}
