/// Ce que la calibration a mesure (lot J2).
class LatencyEstimate {
  const LatencyEstimate({
    required this.latencyMs,
    required this.matched,
    required this.spreadMs,
  });

  /// Du moment ou le moteur joue un son au moment ou le micro le date :
  /// sortie, air, entree. C'est l'ecart a retrancher pour caler un son emis
  /// sur ce qu'on entend.
  ///
  /// **Le biais du detecteur d'attaques y est inclus, et c'est voulu** : il
  /// date une attaque au debut de la fenetre ou il la voit, donc un peu tot,
  /// toujours du meme montant. Les attaques de l'eleve seront datees par le
  /// meme detecteur : la latence mesuree ainsi est exactement celle qu'il
  /// faut pour les rapporter a l'horloge du moteur.
  final int latencyMs;

  /// Clics entendus, sur ceux qui ont ete joues.
  final int matched;

  /// Ecart entre le clic entendu le plus tot et le plus tard, apres
  /// correction : une mesure fiable les donne tous au meme ecart.
  final int spreadMs;
}

/// La calibration de latence (lot J2) : l'application joue des clics a des
/// instants connus de son horloge, le micro les entend, et l'ecart dit la
/// latence aller-retour.
///
/// **Elle ne sert pas au rythme** (ADR-010) : le juge compare les attaques
/// entre elles, et une latence constante disparait de la soustraction. Elle
/// sert a ce qui **emet** en meme temps que l'eleve joue -- un accompagnement
/// qui doit tomber avec lui (J5).
///
/// **Deux horloges, un pont.** Le moteur a la sienne ; le micro date ses
/// echantillons depuis son ouverture. A l'arrivee d'un paquet du micro, on lit
/// l'horloge du moteur : ce couple ([micToEngineMs]) relie les deux. Le delai
/// de livraison du paquet fait partie de ce qu'on mesure, et c'est voulu --
/// c'est lui que l'accompagnement devra rattraper.
class LatencyCalibration {
  const LatencyCalibration._();

  /// Combien de clics : assez pour qu'une mediane ait un sens et qu'un clic
  /// rate ne fausse rien.
  static const int clicks = 6;

  /// Ecart entre deux clics : assez pour que l'echo du premier se soit eteint.
  static const int intervalMs = 500;

  /// Au-dela, un son entendu n'est pas ce clic-la.
  static const int maxLatencyMs = 400;

  /// Il faut au moins ces clics entendus.
  static const int minMatched = 4;

  /// Et pas plus d'ecart que ca entre eux : sinon on a entendu autre chose.
  static const int maxSpreadMs = 30;

  /// La latence, ou `null` si la mesure n'est pas fiable.
  ///
  /// [clicksEngineMs] : quand le moteur a joue chaque clic. [onsetsMicMs] :
  /// les attaques entendues, en temps du micro. [micToEngineMs] : ce qu'il
  /// faut ajouter a un temps du micro pour l'avoir en temps du moteur.
  static LatencyEstimate? estimate({
    required List<int> clicksEngineMs,
    required List<int> onsetsMicMs,
    required int micToEngineMs,
  }) {
    final List<int> ecarts = <int>[];
    final List<int> entendues = <int>[
      for (final int o in onsetsMicMs) o + micToEngineMs,
    ]..sort();
    for (final int c in clicksEngineMs) {
      for (final int o in entendues) {
        final int e = o - c;
        if (e >= 0 && e <= maxLatencyMs) {
          ecarts.add(e);
          break;
        }
      }
    }
    if (ecarts.length < minMatched) {
      return null;
    }
    ecarts.sort();
    final int etendue = ecarts.last - ecarts.first;
    if (etendue > maxSpreadMs) {
      return null;
    }
    return LatencyEstimate(
      latencyMs: ecarts[ecarts.length ~/ 2],
      matched: ecarts.length,
      spreadMs: etendue,
    );
  }
}
