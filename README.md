# Violon

Application d'aide au travail du violon, pour un enfant de 11 ans en 4e annee
de conservatoire.

L'eleve joue sur **sa partition papier**, a son tempo. **L'application
l'ecoute et le suit** : elle sait ou il en est, mesure la justesse et le
rythme de ce qu'elle a entendu, et **lui dit quelles mesures rejouer**. Le
telephone n'est pas un pupitre : c'est un professeur qui ecoute.

Projet personnel, utilisateur unique, 100 % hors ligne, sans compte ni
serveur.

> **Ou en est le projet reellement :** voir la section *Etat* en bas. Le
> paragraphe ci-dessus decrit la cible, pas ce qui tourne aujourd'hui.

## Demarrage

```bash
git clone https://github.com/romaincausse/violon.git
cd violon
flutter pub get
flutter test
flutter run
```

Le dossier `android/` est versionne : pas de `flutter create` a passer.
L'identifiant est `com.romaincausse.violon`, et les deux orientations sont
servies -- le telephone se pose sur un pupitre.

`make check` avant chaque push : c'est exactement ce que rejoue la CI.

## Structure

```
lib/
  core/                logique pure, sans AUCUN paquet, entierement testee
    audio/             YIN, attaques, lissage, abstraction du micro
    music/             notes, passages, conversions hauteur/frequence/cents
    score/             mise en page d'une portee monodique (calcul, pas dessin)
    follow/            suiveur, alignement joue / attendu (le coeur, a venir)
    scoring/           justesse, accordeur, diapason mesure
    play/              horloge de metronome
  platform/            adaptateurs vers les plugins, une classe par frontiere
  ui/                  ecrans et widgets, aucune logique metier
test/                  miroir de lib/, 320 tests
assets/fonts/          Bravura (SIL OFL), livree non modifiee
tool/                  script Verovio -- mort-ne, voir Etat
docs/                  plan, decisions, journal, navigation, professeur
```

Quatre regles structurantes, detaillees dans `CLAUDE.md` :

1. **`lib/core/` n'importe aucun paquet** -- ni Flutter, ni un plugin. Verifie
   par la CI et par `make core-pur`.
2. **`AudioCapture` et `PitchSource` sont les seules frontieres materielles.**
3. **`ScoreNote` est le modele pivot.**
4. **Le rendu de partition est natif** et volontairement limite a une ligne
   monodique (ADR-007).

## Commandes

```bash
make check     # format + analyse + tests + verification d'architecture
make test
make apk
make scores    # mort-ne : voir Etat, et ADR-002 marquee caduque
```

## Documentation

| Fichier | Contenu |
|---------|---------|
| `docs/plan.md` | **le plan** : onze jalons, une ligne = une PR, trie par ROI |
| `docs/decisions.md` | les dix ADR : pourquoi Flutter, pourquoi ce sens de suivi, pourquoi pas de backend |
| `docs/journal.md` | les trois retournements du projet, et les tensions ouvertes |
| `docs/navigation.md` | comment on s'y retrouve quand tout existera |
| `docs/professeur.md` | ce qu'un professeur de violon peut en faire |
| `docs/definition-of-done.md` | ce qu'il faut avant de merger |
| `CLAUDE.md` | contexte et regles pour Claude Code |
| `CONTRIBUTING.md` | branches, commits, protection de `main` |

## Partitions et exercices

Le fonds pedagogique classique est dans le domaine public et peut etre
versionne : Wohlfahrt op. 45, Kayser op. 20, Mazas op. 36, Sevcik op. 1,
Schradieck, Hrimaly, Vivaldi, Bach.

Deux exclusions fermes :

- **Les methodes modernes sous droits**, type Suzuki, restent dans
  `tool/sources/`, exclu de git. Usage familial, jamais embarque.
- **Le systeme de gammes de Galamian**, encore sous droits. C'est le plus
  connu, et c'est precisement celui qu'il ne faut pas copier.

## Etat

**320 tests, dix-huit lots livres.** Le plan a ete refondu : c'est desormais
l'application qui suit l'eleve, et non l'inverse (ADR-009), et il est
reordonne par rapport effet/cout.

### Ce qui tourne

Trois ecrans : le travail, la saisie d'un passage, l'accordeur.

La chaine audio est complete et branchee -- capture en `UNPROCESSED`, YIN dans
un isolate, lissage du vibrato, justesse note par note, diapason mesure sur
les cordes a vide. Le rendu grave une portee monodique avec Bravura, sur
plusieurs systemes, zoomable, dans les deux orientations.

### Ce qui est ecrit mais ne tourne pas

**Le detecteur d'attaques et sa FFT** (341 lignes) ne sont appeles par
personne : ils attendent le suiveur. Consequence a garder en tete, **ils n'ont
jamais vu un vrai signal de violon** -- uniquement des signaux de synthese.

`tool/build_scores.mjs` ecrit dans `assets/scores/`, qui n'existe pas. Il n'a
donc jamais rien produit : mort-ne plutot que dormant.

### Ce qui vient ensuite

Le prochain jalon ne demande pas le suiveur : six lots a fort effet qui
tournent sur le code deja livre. Deux d'entre eux sont des **corrections**,
pas des ajouts -- l'application reproche aujourd'hui a l'eleve le desaccord de
son violon (I1) et marque faux ce qu'il joue juste, parce qu'elle compare au
tempere alors qu'un violoniste ne joue pas tempere (I2).

Voir `docs/plan.md`.
