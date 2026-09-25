# CLAUDE.md

Instructions pour Claude Code sur ce depot.

## Le projet en une phrase

Application Flutter d'aide au travail du violon pour un enfant de 11 ans,
4e annee de conservatoire. **Elle le suit pendant qu'il joue sur sa partition
papier**, mesure la justesse et le rythme, et lui dit quelles mesures
rejouer.

## Le coeur de l'application

Le coeur est le **suivi de l'eleve** (ADR-009). L'eleve joue sur **sa
partition papier**, a son tempo, quand il veut. L'application ecoute, sait a
tout instant ou il en est dans le morceau, et en tire :

1. un **retour visuel** note par note, en direct ;
2. une **notation** de la justesse et du rythme, par note et par mesure ;
3. **les mesures a rejouer**, choisies par la mesure et non par l'enfant ;
4. un **accompagnement**, dans un mode separe.

**Le sens du suivi n'est pas negociable.** Ce n'est pas l'enfant qui suit un
curseur : c'est l'application qui le suit. Toute proposition qui remet un
curseur maitre du tempo au centre contredit l'ADR-009.

Le telephone n'est pas un pupitre. C'est un professeur qui ecoute.

## Suivre est tolerant, juger est strict

Consequence directe, et piege principal du projet (ADR-010). Un suiveur qui
s'adapte a l'eleve le rattrape toujours : il ne peut donc pas servir a le
juger. Un seul alignement, deux lectures.

- Le **suiveur** ne juge rien. Son seul objectif est de ne jamais perdre la
  position : hesitation, fausse note, arret, mesure rejouee dix fois.
- Le **juge** reprend les attaques alignees, en deduit le tempo reellement
  tenu, et mesure l'ecart a la grille metrique **a ce tempo**.

Ce que ca separe :

| Ce qui est joue | Verdict |
|---|---|
| Tout a 74 au lieu de 92, rythme impeccable | Tempo tenu, **pas une faute** |
| Une noire jouee comme une croche | **Faute de rythme** |
| Deux secondes d'arret avant une note | **Hesitation**, comptee a part |

## Le probleme de fond

L'enfant se lasse de rejouer dix fois la meme mesure. Ce constat reste vrai,
mais il n'est plus la finalite : c'est **l'application qui designe les mesures
a retravailler**, a partir de ce qu'elle a mesure. La repetition devient
dirigee au lieu d'etre subie, et l'accompagnement apporte la variete.

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
    follow/        <- suiveur, alignement joue / attendu (le coeur)
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

- **Cible : telephone Android**, pose sur un pupitre. iOS plus tard. Les deux
  orientations sont servies : portrait pour empiler jusqu'a quatre systemes,
  paysage pour deux systemes larges avec les commandes sur le cote.
- **Micro en `AudioSource.UNPROCESSED`**, repli sur `VOICE_RECOGNITION`. Le
  mode `MIC` par defaut applique AGC et reduction de bruit calibrees pour la
  voix : sur un son tenu de violon, la detection devient instable.
  `UNPROCESSED` existe depuis Android 7 mais reste **facultative** pour les
  constructeurs : le repli n'est pas theorique. Verifie sur l'appareil cible,
  un Galaxy S22 : `dumpsys media.audio_flinger` y montre bien
  `AUDIO_SOURCE_UNPROCESSED` pendant la capture. Le repli sert donc aux autres
  appareils, pas a celui-la.
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
- **Le curseur suit ce qui est joue**, pas l'horloge (ADR-009). C'est le lot
  le plus risque du projet, et il est desormais le premier : un jalon de
  preuve le valide sur de vraies prises avant qu'on batisse dessus.
- **Un enfant qui travaille ne joue pas du debut a la fin.** Il s'arrete,
  reprend la mesure, saute. Pour le suiveur c'est le cas nominal, pas le cas
  limite.
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
  kebab-case. Exemple : `feat/suiveur-en-ligne`.
- Messages de commit en Conventional Commits : `feat(follow): ...`. Les
  portees suivent l'arborescence ; `practice` n'existe plus.
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
