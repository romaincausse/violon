# Violon

Application d'aide au travail du violon. L'eleve joue sur **sa partition
papier**, a son tempo. **L'application l'ecoute et le suit** : elle sait a tout
instant ou il en est, colore les notes en direct, et mesure la justesse et le
rythme de ce qu'elle a entendu.

Et surtout elle **dit quoi rejouer** : les mesures les plus faibles sont
choisies par la mesure, bouclees, et le tempo monte tout seul quand c'est
propre. Une erreur ne remet jamais un compteur a zero.

Projet personnel, utilisateur unique, 100 % hors ligne.

## Demarrage

```bash
git clone https://github.com/romaincausse/violon.git
cd violon
flutter pub get
flutter test
flutter run
```

Le dossier `android/` est versionne : il n'y a plus de `flutter create` a
passer. L'identifiant d'application est `com.romaincausse.violon`, et les deux
orientations sont servies : le telephone se pose sur un pupitre.

`make check` avant chaque push : c'est exactement ce que rejoue la CI.

## Structure

```
lib/
  core/                logique pure, sans Flutter, entierement testee
    audio/             YIN, attaques, abstraction du micro, source factice
    music/             notes, passages, conversions hauteur/frequence/cents
    score/             mise en page d'une portee monodique
    follow/            suiveur, alignement joue / attendu (le coeur)
    scoring/           notation de la justesse et du rythme
    play/              metronome et accompagnement pre-planifies
  ui/                  ecrans et widgets
test/                  miroir de lib/
tool/                  script Verovio, dormant depuis l'ADR-009
docs/                  plan, decisions, journal, professeur
```

## Commandes

```bash
make check     # format + analyse + tests + verification d'architecture
make test
make apk
make scores    # dormant : voir ADR-002, marquee caduque
```

## Documentation

| Fichier | Contenu |
|---------|---------|
| `CLAUDE.md` | contexte et regles pour Claude Code |
| `docs/plan.md` | **le plan** : huit jalons, une ligne = une PR, trie par ROI |
| `docs/decisions.md` | pourquoi Flutter, pourquoi ce sens de suivi, pourquoi pas de backend |
| `docs/journal.md` | les trois retournements du projet, et les tensions ouvertes |
| `docs/professeur.md` | ce qu'un professeur de violon peut en faire |
| `docs/definition-of-done.md` | ce qu'il faut avant de merger |
| `CONTRIBUTING.md` | branches, commits, protection de `main` |

## Partitions

Le fonds pedagogique classique (Wohlfahrt, Kayser, Sevcik, Mazas, Vivaldi,
Bach) est dans le domaine public et peut etre versionne. Les methodes
modernes sous droits, type Suzuki, restent dans `tool/sources/`, qui est
exclu de git : usage familial uniquement, jamais embarque dans une
distribution.

## Etat

Dix-huit lots livres. Le plan a ete refondu : c'est desormais l'application
qui suit l'eleve, et non l'inverse (ADR-009), et il est reordonne par rapport
effet/cout.

Le prochain jalon ne demande donc pas le suiveur : six lots a fort effet qui
tournent sur le code deja livre -- l'ancre par cordes a vide, l'intonation
expressive, et les retours visuels qui se lisent du coin de l'oeil pendant
qu'on lit son papier.

Voir `docs/plan.md`.
