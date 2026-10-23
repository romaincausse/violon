/// D'ou l'on part dans le catalogue (lot K1).
///
/// **Le catalogue commence a Sevcik, "la main se pose"**, et un eleve de
/// quatrieme annee s'y ennuierait des le premier soir. Une question --
/// depuis combien d'annees joues-tu ? -- dit quels paliers sont deja acquis.
///
/// **Rien n'est verrouille pour autant** (ADR-011) : on change ce qui est
/// propose en premier, pas ce qui est jouable. Le professeur peut toujours
/// donner un exercice d'un palier plus bas.
///
/// Les correspondances suivent un premier cycle de conservatoire : la gamme
/// d'une octave en deuxieme annee, deux octaves en troisieme, les arpeges et
/// le mineur en quatrieme.
class StartingLevel {
  const StartingLevel({
    required this.label,
    required this.palier,
  });

  /// Ce que l'enfant repond.
  final String label;

  /// Le premier palier propose : ceux d'en dessous sont tenus pour acquis.
  final int palier;

  static const List<StartingLevel> all = <StartingLevel>[
    StartingLevel(label: 'Je commence', palier: 1),
    StartingLevel(label: '2 ans', palier: 3),
    StartingLevel(label: '3 ans', palier: 4),
    StartingLevel(label: '4 ans ou plus', palier: 5),
  ];

  /// La reponse qui correspond a [palier], ou la plus proche en dessous.
  static StartingLevel of(int palier) {
    StartingLevel retenu = all.first;
    for (final StartingLevel n in all) {
      if (n.palier <= palier) {
        retenu = n;
      }
    }
    return retenu;
  }
}
