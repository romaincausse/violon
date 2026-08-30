# CLAUDE.md

Instructions pour Claude Code sur ce depot.

## Le projet en une phrase

Application Flutter d'aide au travail du violon pour un enfant de 11 ans,
4e annee de conservatoire. Elle ecoute ce qu'il joue, mesure la justesse et
le rythme, et surtout **rend la repetition supportable**.

## Le probleme reel a resoudre

L'utilisateur unique de cette application se lasse de rejouer dix fois la
meme mesure. Ce n'est pas un probleme de justesse, c'est un probleme de
**monotonie**.

Consequence directe sur toutes les decisions produit :

- La fonctionnalite centrale n'est pas la notation, c'est le **boucleur a
  variations** : dix repetitions differentes du meme passage plutot que dix
  repetitions identiques.
- L'application dit **"voila ta prochaine tache"**, jamais "voila tout ce que
  tu as rate".
- Un objectif fini et visible des le premier tour.
- Une erreur ne remet **jamais** un compteur a zero.
- On termine toujours sur une reussite, au tempo ecrit.

Si une proposition entre en conflit avec ces principes, c'est la proposition
qui a tort. Signale-le plutot que de l'implementer.

## Architecture

```
lib/
  core/            <- logique pure, testable, sans Flutter
    audio/         <- detection de hauteur, abstraction du micro
    music/         <- modele de notes, conversions, passages
    practice/      <- variations, sessions de travail
  ui/              <- widgets et ecrans, aucune logique metier
```

Trois regles structurantes :

1. **`lib/core/` ne doit jamais importer `package:flutter/material.dart`.**
   Toute la logique metier est du Dart pur, donc testable sans `pumpWidget`.
2. **`PitchSource` est la seule frontiere avec le materiel audio.** C'est la
   seule couche a reecrire pour porter sur iOS, et la seule a remplacer pour
   developper l'interface sous Flutter Web. Rien au-dessus ne connait le micro.
3. **`ScoreNote` est le modele pivot.** Le rendu de partition (Verovio
   pre-genere aujourd'hui) est interchangeable ; le modele interne ne l'est pas.

## Contraintes techniques a ne pas oublier

- **Cible : telephone Android**, en portrait, pose sur un pupitre. iOS plus tard.
- **Micro en `AudioSource.UNPROCESSED`**, repli sur `VOICE_RECOGNITION`. Le
  mode `MIC` par defaut applique AGC et reduction de bruit calibrees pour la
  voix : sur un son tenu de violon, la detection devient instable.
- **Jamais de `Timer` Dart pour le metronome.** La derive est audible. Les
  clics doivent etre pre-planifies dans le moteur audio natif.
- **Le YIN tourne dans un isolate**, sur des buffers de 2048 echantillons.
- **Tolerer le vibrato** : il fait varier la hauteur de +/- 20 a 50 cents
  volontairement. Un detecteur naif le note comme faux.
- **Justesse relative** : juger par rapport a l'accord reel de l'instrument,
  pas a une reference absolue.
- **Le metronome rentre dans le micro** (10 cm d'ecart sur un telephone).
  Privilegier le metronome visuel, et couper le detecteur pendant les clics.
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
- Le determinisme est obligatoire : `VariationGenerator` et `PracticeSession`
  acceptent une graine.
- Pour tester l'audio, utiliser `FakePitchSource` ou synthetiser un signal,
  jamais le vrai micro.
- Lancer : `flutter test`.

## Git

- Une branche par sujet, une PR par branche. Jamais de commit direct sur `main`.
- Nommage : `feat/`, `fix/`, `chore/`, `docs/`, `test/` + description en
  kebab-case. Exemple : `feat/boucleur-variations`.
- Messages de commit en Conventional Commits : `feat(practice): ...`.
- La CI doit etre verte avant merge. Squash merge.

## Ce que tu ne dois pas faire sans demander

- Ajouter une dependance. Le `pubspec.yaml` est volontairement minimal.
- Embarquer des partitions sous droits (methode Suzuki notamment) dans
  `assets/`. Seul le domaine public est versionnable.
- Introduire de la gamification enfantine (mascottes, confettis, badges
  bruyants). L'utilisateur a 11 ans et sait qu'il fait de la musique : on lui
  montre des **donnees** qui montent, pas des recompenses.
- Ajouter un backend, un compte utilisateur ou de la telemetrie.

## Etat d'avancement

Voir `docs/roadmap.md` pour les jalons et `docs/backlog.md` pour le detail
des taches. Mettre a jour ces fichiers quand un lot est termine.
