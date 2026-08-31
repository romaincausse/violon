# CLAUDE.md

Instructions pour Claude Code sur ce depot.

## Le projet en une phrase

Application Flutter d'aide au travail du violon pour un enfant de 11 ans,
4e annee de conservatoire. Elle ecoute ce qu'il joue, mesure la justesse et
le rythme, et surtout **rend la repetition supportable**.

## Le coeur de l'application

Le coeur est la **partition dynamique suivie en temps reel**. Elle affiche le
passage travaille, avance avec ce qui est joue, et rend trois choses :

1. un **retour visuel** note par note, en direct ;
2. une **notation** de la justesse et du rythme ;
3. un **accompagnement**, dans un mode separe.

Tout le reste est au service de ca.

## Le probleme reel a resoudre

L'utilisateur unique de cette application se lasse de rejouer dix fois la
meme mesure. Ce n'est pas un probleme de justesse, c'est un probleme de
**monotonie**.

Ce constat n'a pas change, et il ne doit pas etre oublie sous pretexte que
l'application sait maintenant noter. **Une application qui note en
permanence, sans repondre a la lassitude, aura resolu un probleme que
personne n'avait.**

Comment le coeur actuel y repond :

- **La boucle, pas la carte.** On selectionne deux mesures, on les boucle, et
  le tempo monte tout seul quand le passage est propre. Meme mecanisme
  anti-lassitude que l'ancien boucleur, sans l'ecran de cartes.
- **L'application mesure au lieu de demander.** Plus d'auto-evaluation : un
  score mesure est plus motivant qu'un bouton sur lequel on appuie soi-meme,
  et plus honnete.
- **L'accompagnement est la variete.** C'est lui qui rend une dixieme
  repetition supportable.

## Les regles produit, qui n'ont pas bouge

- L'application dit **"voila ta prochaine tache"**, jamais "voila tout ce que
  tu as rate". Une partition rouge partout est une regression, pas une
  fonctionnalite.
- Un objectif fini et visible des le premier passage.
- Une erreur ne remet **jamais** un compteur a zero.
- On termine toujours sur une reussite, au tempo ecrit.
- On montre des **donnees qui montent**, pas des recompenses.

Si une proposition entre en conflit avec ces principes, c'est la proposition
qui a tort. Signale-le plutot que de l'implementer.

## Architecture

```
lib/
  core/            <- logique pure, testable, sans aucun paquet
    audio/         <- detection de hauteur, attaques, abstraction du micro
    music/         <- modele de notes, conversions, passages, saisie
    score/         <- mise en page d'une portee monodique
    follow/        <- curseur, appariement joue / attendu
    scoring/       <- notation de la justesse et du rythme
    play/          <- metronome et accompagnement pre-planifies
  platform/        <- adaptateurs vers les plugins, une classe par frontiere
  ui/              <- widgets et ecrans, aucune logique metier
```

Quatre regles structurantes :

1. **`lib/core/` ne doit importer aucun paquet.** Pas Flutter, et pas
   davantage un plugin : un plugin ne se teste pas sans appareil, ce qui
   viderait la regle de son sens. Toute la logique metier est donc du Dart
   pur, testable sans `pumpWidget` et sans telephone. La mise en page de la
   portee y vit aussi : elle calcule des coordonnees, elle ne peint pas.
   C'est verifie par la CI et par `make core-pur`.
2. **`AudioCapture` et `PitchSource` sont les seules frontieres avec le
   materiel audio.** `AudioCapture` ne connait que des octets et vit dans
   `lib/platform/` cote implementation ; `PitchSource` rend des hauteurs.
   Ce sont les seules couches a reecrire pour porter sur iOS, et les seules a
   remplacer pour developper l'interface sous Flutter Web. Rien au-dessus ne
   connait le micro.
3. **`ScoreNote` est le modele pivot.** Le rendu de partition et la source des
   notes sont interchangeables ; le modele interne ne l'est pas.
4. **Le rendu de partition est natif** (`CustomPainter` + police Bravura), et
   volontairement limite a une ligne monodique. Voir ADR-007 : ce n'est pas un
   graveur general, et ca ne doit pas le devenir.

## Contraintes techniques a ne pas oublier

- **Cible : telephone Android**, en portrait, pose sur un pupitre. iOS plus tard.
- **Micro en `AudioSource.UNPROCESSED`**, repli sur `VOICE_RECOGNITION`. Le
  mode `MIC` par defaut applique AGC et reduction de bruit calibrees pour la
  voix : sur un son tenu de violon, la detection devient instable.
  `UNPROCESSED` existe depuis Android 7 mais reste **facultative** pour les
  constructeurs : le repli n'est pas theorique.
- **Jamais de `Timer` Dart pour le metronome.** La derive est audible. Les
  clics doivent etre pre-planifies dans le moteur audio natif.
- **Le YIN tourne dans un isolate**, sur des buffers de 2048 echantillons.
- **Tolerer le vibrato** : il fait varier la hauteur de +/- 20 a 50 cents
  volontairement. Un detecteur naif le note comme faux.
- **Justesse relative** : juger par rapport a l'accord reel de l'instrument,
  pas a une reference absolue.
- **Le metronome rentre dans le micro** (10 cm d'ecart sur un telephone), et
  l'accompagnement encore plus. En mode notation l'application n'emet **aucun
  son** : le metronome est visuel. Accompagnement et notation sont deux modes
  exclusifs (ADR-008).
- **Le curseur avance sur l'horloge**, pas sur ce qui est joue. Le suivi
  adaptatif est un lot a part, en V4, et le plus risque du projet.
- **YIN ne voit pas une note repetee a la meme hauteur.** Noter le rythme
  demande un detecteur d'attaques distinct.
- **100 % hors ligne.** Aucun serveur, aucun compte.

## Conventions de code

- Types explicites sur les declarations publiques. `strict-casts` et
  `strict-raw-types` sont actifs.
- `dart format` avant chaque commit, la CI le verifie.
- `flutter analyze --fatal-infos` doit passer.
- Commentaires en francais, sans accents dans le code source pour eviter les
  ennuis d'encodage. Les chaines affichees a l'utilisateur peuvent en avoir.
- Un commentaire explique **pourquoi**, pas **quoi**.

## Tests

- Toute logique dans `lib/core/` doit etre couverte.
- Le determinisme est obligatoire : tout ce qui depend du hasard ou de
  l'horloge accepte une graine ou une horloge injectee.
- Pour tester l'audio, utiliser `FakePitchSource` ou synthetiser un signal,
  jamais le vrai micro.
- Lancer : `flutter test`.

## Git

- Une branche par sujet, une PR par branche. Jamais de commit direct sur `main`.
- Nommage : `feat/`, `fix/`, `chore/`, `docs/`, `test/` + description en
  kebab-case. Exemple : `feat/curseur-au-tempo`.
- Messages de commit en Conventional Commits : `feat(practice): ...`.
- La CI doit etre verte avant merge. Squash merge.

## Ce que tu ne dois pas faire sans demander

- Ajouter une dependance. Le `pubspec.yaml` est volontairement minimal.
- Embarquer des partitions sous droits (methode Suzuki notamment) dans
  `assets/`. Seul le domaine public est versionnable.
- Introduire de la gamification enfantine (mascottes, confettis, badges
  bruyants). L'utilisateur a 11 ans et sait qu'il fait de la musique : on lui
  montre des **donnees** qui montent, pas des recompenses.
- Transformer le rendu de partition en graveur general. Il grave une ligne
  monodique, c'est tout ce qu'il doit savoir faire (ADR-007).
- Ajouter un backend, un compte utilisateur ou de la telemetrie.

## Etat d'avancement

Voir `docs/roadmap.md` pour les jalons et `docs/backlog.md` pour le detail
des taches. Mettre a jour ces fichiers quand un lot est termine.
