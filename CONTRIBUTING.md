# Contribuer

## Flux de travail

Une branche par sujet, une PR par branche, jamais de commit direct sur `main`.

```bash
git switch main && git pull
git switch -c feat/accordeur
# ... travail ...
git push -u origin feat/accordeur
gh pr create --fill
```

## Nommage des branches

| Prefixe | Usage |
|---------|-------|
| `feat/` | nouvelle fonctionnalite |
| `fix/` | correction de bug |
| `chore/` | outillage, dependances, CI |
| `docs/` | documentation seule |
| `test/` | tests seuls |
| `refactor/` | reorganisation sans changement de comportement |

Description en kebab-case : `feat/suiveur-en-ligne`, `fix/octave-yin`.

## Messages de commit

Conventional Commits, en francais.

```
feat(follow): le suiveur encaisse une mesure rejouee
fix(audio): corrige l'erreur d'octave sur les harmoniques aigues
chore(ci): epingle la version de Flutter
docs(adr): acte que l'application suit l'eleve
```

Portees usuelles, calquees sur l'arborescence : `audio`, `music`, `score`,
`follow`, `scoring`, `play`, `ui`, `platform`, `android`, `ci`, `docs`,
`tool`.

> `practice` n'existe plus : `lib/core/practice/` a ete supprime avec le
> boucleur a cartes (lot Z1).

## Avant de pousser

```bash
dart format .
flutter analyze --fatal-infos
flutter test
```

Ou simplement `make check`.

## Merge

Squash merge, la branche est supprimee ensuite. La CI doit etre verte.

## Reglage a faire une fois sur GitHub

Dans **Settings > Branches > Add branch protection rule** pour `main` :

- Require a pull request before merging
- Require status checks to pass : cocher `qualite`
- Require branches to be up to date before merging
- (facultatif) Allow squash merging uniquement, et suppression auto des branches

Dans **Settings > General > Pull Requests** : cocher *Automatically delete
head branches*.
