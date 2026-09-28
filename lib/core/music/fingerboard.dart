import 'dart:math' as math;

/// La geometrie d'un manche de violon, en fractions de corde vibrante.
///
/// **Un manche n'est pas une regle graduee.** La distance du sillet a un doigt
/// ne suit pas le nombre de demi-tons : elle suit la longueur de corde qu'il
/// faut raccourcir pour monter d'autant. Les doigts se resserrent donc en
/// montant, et c'est exactement ce qu'un violoniste voit sous sa main.
///
/// Dessiner des ecarts egaux donnerait un schema de guitare -- et un schema
/// faux est pire qu'une absence de schema.
abstract final class Fingerboard {
  /// Ou tombe un doigt qui monte de [semitones], en fraction de la corde.
  ///
  /// 0 au sillet, et la fraction tend vers 1 au chevalet. Un demi-ton vaut
  /// environ 5,6 % de la corde, une octave exactement la moitie.
  static double fraction(int semitones) {
    assert(semitones >= 0, 'un doigt ne se pose pas avant le sillet');
    return 1 - math.pow(2, -semitones / 12).toDouble();
  }

  /// Jusqu'ou on dessine le manche : la premiere position, plus un peu.
  ///
  /// Le quatrieme doigt tombe au septieme demi-ton ; deux de plus laissent
  /// voir que le manche continue sans que la position s'y perde. Le catalogue
  /// se tient sous le si de la corde de mi et ne demanche pas -- ce n'est pas
  /// le programme d'une quatrieme annee.
  ///
  /// **Ce nombre decide de la lisibilite du schema.** Dessiner plus haut
  /// tasse la premiere position vers le sillet, et le demi-ton de
  /// l'ecartement -- le seul ecart qui compte -- devient trop petit pour
  /// qu'une pastille y tienne.
  static const int drawnSemitones = 9;

  /// Les quatre cordes a vide, du grave a l'aigu.
  ///
  /// **Dans cet ordre a l'ecran, et c'est le bon.** Violon en main, l'oeil qui
  /// descend le long du manche voit le sol a gauche et le mi a droite.
  static const List<int> strings = <int>[55, 62, 69, 76];
}
