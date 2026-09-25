/// Une methode de violon dont le catalogue s'inspire.
///
/// **Aucun exercice n'est invente.** Le catalogue s'appuie sur les methodes
/// reelles, celles qu'un professeur donne deja, et il le dit : chaque exercice
/// porte sa source, affichee a l'ecran. Un enfant a qui on demande "la
/// premiere position, ecartement 2-3" doit pouvoir retrouver la page.
///
/// **Ce qui est fidele, et ce qui ne l'est pas.** Ce que l'application reprend
/// de ces methodes, c'est leur **principe de construction** -- la combinatoire
/// de doigts chez Sevcik, la gamme declinee par tonalite chez Hrimaly -- et
/// leur **ordre de difficulte**, qui a fait ses preuves sur quatre generations.
/// Ce n'est pas le texte d'un numero precis : l'application genere, elle ne
/// recopie pas. Voir `docs/exercices.md`.
///
/// **Domaine public.** Ces methodes datent de la fin du XIXe et du debut du
/// XXe siecle, et leurs auteurs sont morts depuis plus d'un siecle : rien
/// n'empeche de s'en inspirer ni de les citer.
///
/// > A ne pas embarquer : le *Contemporary Violin Technique* de Galamian,
/// > encore sous droits. C'est le systeme de gammes le plus connu, et c'est
/// > precisement celui qu'il ne faut pas copier.
class MethodSource {
  const MethodSource({
    required this.id,
    required this.auteur,
    required this.titre,
    required this.apport,
  });

  final String id;
  final String auteur;

  /// Titre de l'ouvrage, tel qu'il est imprime sur la couverture.
  final String titre;

  /// Ce que la methode apporte, en une ligne, pour l'afficher a cote d'un
  /// exercice.
  final String apport;

  /// Nom court pour une liste : "Sevcik, op. 1".
  String get court => '$auteur, $titre';

  static const MethodSource sevcik = MethodSource(
    id: 'sevcik-op-1',
    auteur: 'Sevcik',
    titre: 'op. 1',
    apport: 'Motifs de doigts, combinatoire systematique',
  );

  static const MethodSource schradieck = MethodSource(
    id: 'schradieck',
    auteur: 'Schradieck',
    titre: 'School of Violin Technics',
    apport: 'Deliement et changements de corde',
  );

  static const MethodSource hrimaly = MethodSource(
    id: 'hrimaly',
    auteur: 'Hrimaly',
    titre: 'Scale Studies',
    apport: 'Gammes et arpeges, tonalite par tonalite',
  );

  /// Les methodes d'ou sort le catalogue actuel.
  ///
  /// Wohlfahrt op. 45, Kayser op. 20 et Mazas op. 36 en sont absents a
  /// dessein : ce sont des **etudes melodiques**, c'est-a-dire des morceaux
  /// ecrits. Elles ne se generent pas a partir de parametres, il faudrait les
  /// transcrire -- et transcrire de memoire une etude qu'on attribue ensuite a
  /// son auteur serait pire que de ne pas la proposer. Elles arriveront par
  /// l'import (lot H6), qui lira le vrai texte.
  static const List<MethodSource> all = <MethodSource>[
    sevcik,
    schradieck,
    hrimaly,
  ];
}
