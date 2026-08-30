# Violon

Application d'aide au travail du violon. Elle ecoute ce qui est joue, mesure
la justesse et le rythme, et surtout **rend la repetition supportable** :
plutot que dix fois la meme mesure a l'identique, elle propose dix facons
differentes de la travailler.

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
passer. L'identifiant d'application est `com.romaincausse.violon`, et
l'activite est verrouillee en portrait (telephone pose sur un pupitre).

`make check` avant chaque push : c'est exactement ce que rejoue la CI.

## Structure

```
lib/
  core/                logique pure, sans Flutter, entierement testee
    audio/             YIN, abstraction du micro, source factice
    music/             notes, passages, conversions hauteur/frequence/cents
    practice/          variations de travail, sessions
  ui/                  ecrans et widgets
test/                  miroir de lib/
tool/                  script Verovio (gravure des partitions, hors app)
docs/                  roadmap, backlog, decisions d'architecture
```

## Commandes

```bash
make check     # format + analyse + tests + verification d'architecture
make test
make apk
make scores    # regenere les partitions depuis tool/sources/
```

## Documentation

| Fichier | Contenu |
|---------|---------|
| `CLAUDE.md` | contexte et regles pour Claude Code |
| `docs/roadmap.md` | les quatre jalons |
| `docs/backlog.md` | une ligne = une PR |
| `docs/decisions.md` | pourquoi Flutter, pourquoi Verovio, pourquoi pas de backend |
| `docs/definition-of-done.md` | ce qu'il faut avant de merger |
| `CONTRIBUTING.md` | branches, commits, protection de `main` |

## Partitions

Le fonds pedagogique classique (Wohlfahrt, Kayser, Sevcik, Mazas, Vivaldi,
Bach) est dans le domaine public et peut etre versionne. Les methodes
modernes sous droits, type Suzuki, restent dans `tool/sources/`, qui est
exclu de git : usage familial uniquement, jamais embarque dans une
distribution.

## Etat

V1 en cours. Voir `docs/roadmap.md`.
