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

  /// Quand sonne chaque clic, depuis le premier.
  ///
  /// **Des ecarts inegaux, et c'est voulu.** Sur le S22, le son met plus de
  /// six cents millisecondes a revenir au micro : avec des clics reguliers
  /// toutes les 500 ms, chaque clic aurait ete apparie a l'echo du precedent,
  /// et la mesure aurait rendu un chiffre faux et parfaitement regulier. Des
  /// ecarts tous differents ne laissent qu'un seul decalage ou tous les clics
  /// tombent juste.
  static const List<int> offsetsMs = <int>[0, 600, 1300, 1800, 2700, 3200];

  /// Combien de clics.
  static int get clicks => offsetsMs.length;

  /// Le dernier clic sonne a cet instant apres le premier.
  static int get spanMs => offsetsMs.last;

  /// Au-dela, un son entendu n'est pas ce clic-la. Le S22 mesure entre 600 et
  /// 850 ms selon le profil du moteur : la marge est large.
  static const int maxLatencyMs = 1500;

  /// Il faut au moins ces clics entendus.
  static const int minMatched = 4;

  /// Un clic entendu a moins de ca du decalage retenu lui correspond.
  static const int toleranceMs = 15;

  /// Et pas plus d'ecart que ca entre eux : sinon on a entendu autre chose.
  static const int maxSpreadMs = 30;

  /// La latence, ou `null` si la mesure n'est pas fiable.
  ///
  /// [clicksEngineMs] : quand le moteur a joue chaque clic. [onsetsMicMs] :
  /// les attaques entendues, en temps du micro. [micToEngineMs] : ce qu'il
  /// faut ajouter a un temps du micro pour l'avoir en temps du moteur.
  ///
  /// **On cherche le decalage qui fait tomber le plus de clics juste**, pas
  /// la premiere attaque apres chaque clic : dans une piece ou l'on parle,
  /// la premiere attaque est souvent une voix.
  static LatencyEstimate? estimate({
    required List<int> clicksEngineMs,
    required List<int> onsetsMicMs,
    required int micToEngineMs,
  }) {
    final List<int> entendues = <int>[
      for (final int o in onsetsMicMs) o + micToEngineMs,
    ]..sort();
    if (entendues.isEmpty) {
      return null;
    }
    List<int> ecartsPour(int decalage) {
      final List<int> e = <int>[];
      for (final int c in clicksEngineMs) {
        int? meilleur;
        for (final int o in entendues) {
          final int d = o - c - decalage;
          if (d.abs() <= toleranceMs &&
              (meilleur == null || d.abs() < (meilleur - decalage).abs())) {
            meilleur = o - c;
          }
        }
        if (meilleur != null) {
          e.add(meilleur);
        }
      }
      return e;
    }

    int meilleurNombre = 0;
    List<int> retenus = const <int>[];
    for (int decalage = 0; decalage <= maxLatencyMs; decalage++) {
      final List<int> e = ecartsPour(decalage);
      if (e.length > meilleurNombre) {
        meilleurNombre = e.length;
        retenus = e;
      }
    }
    if (retenus.length < minMatched) {
      return null;
    }
    final List<int> ecarts = List<int>.of(retenus)..sort();
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
