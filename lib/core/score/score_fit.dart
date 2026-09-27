import 'score_layout.dart';
import '../music/passage.dart';

/// Est-ce qu'un passage tient dans une boite, a cet interligne ?
///
/// **En espaces de portee, comme tout le reste de `core/score`.** L'appelant
/// divise ses pixels par la taille d'un interligne ; aucune coordonnee d'ecran
/// n'entre ici.
///
/// Sert deux fois. Le graveur s'en sert pour choisir le plus grand interligne
/// qui passe. L'ecran s'en sert pour savoir qu'**aucun** ne passe : une
/// partition qui ne tient pas au plus petit interligne lisible ne doit pas
/// etre gravee a moitie hors du cadre, il faut proposer autre chose.
bool scoreFits(
  Passage passage, {
  required double widthSpaces,
  required double heightSpaces,
  int? maxSystems,
  bool checkWidth = true,
  Iterable<int> alsoCover = const <int>[],
}) {
  final ScoreLayout layout = ScoreLayout.of(
    passage,
    maxWidthSpaces: widthSpaces,
    maxSystems: maxSystems,
  );
  // La tolerance absorbe l'arrondi du passage pixels -> espaces : sans elle,
  // une ligne calculee juste a la largeur disponible serait declaree trop
  // large un coup sur deux.
  if (checkWidth && layout.widthSpaces > widthSpaces + 0.01) {
    return false;
  }
  final SystemMetrics metrics = SystemMetrics.of(layout, alsoCover: alsoCover);
  return metrics.stackHeightSpaces(layout.systemCount) <= heightSpaces + 0.01;
}
