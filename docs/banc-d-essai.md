# Banc d'essai du suiveur (P1)

Protocole d'enregistrement et d'annotation des prises reelles qui jugeront le
suiveur au jalon 5. Le *pourquoi* est dans `docs/plan.md` (jalon 5) et dans
l'ADR-009 ; ce fichier dit **comment** constituer le banc.

**Critere de sortie du jalon, rappele :** sur dix prises reelles, dont au
moins trois avec arret et reprise de mesure, l'alignement place **95 % des
notes dans la bonne mesure** et **90 % sur la bonne note**.

---

## Regle zero : rien de ce banc n'entre dans le depot

**Le depot est public.** Les prises sont la voix de l'instrument d'un mineur,
dans sa maison, avec ce qui s'y dit en fond. Elles ne sont versionnees nulle
part, ni en clair, ni compressees, ni "juste pour un test". L'ADR-005 a ecarte
toute question RGPD en ne stockant rien hors du telephone ; le banc ne la
rouvre pas.

Meme regle pour les partitions du repertoire du conservatoire : une piece sous
droits, meme reduite a une liste de hauteurs et de durees, ne va pas dans le
depot (voir `CLAUDE.md`).

Le banc vit donc **hors du depot**, dans un dossier designe par la variable
d'environnement `VIOLON_BANC` (par defaut `~/violon-banc/`). Le code de P2 lit
ce chemin et saute ses tests proprement s'il est absent : la CI ne voit jamais
une prise. Filet de securite : `/banc/` et `*.wav` sont ignores par git.

---

## Ce qu'on doit apprendre

Le banc n'est pas un echantillon de jeu propre. Il doit contenir **les cas qui
font perdre le fil**, parce que c'est eux que le suiveur doit tenir :

| Piege | Pourquoi il est dur |
|---|---|
| Arret puis reprise de la mesure | Le cas nominal d'un enfant qui travaille (ADR-009) |
| Saut en arriere de plusieurs mesures | La position attendue n'est plus la suivante |
| Notes liees dans un meme archet | **Aucune attaque** : seul le changement de hauteur existe |
| Notes repetees a la meme hauteur | **YIN ne voit rien** : seule l'attaque d'archet existe, souvent molle |
| Fausse note, note sautee, note ajoutee | Le suiveur ne doit ni reculer ni s'emballer |
| Tempo tres lent, hesitations | Les silences ressemblent a des fins de passage |
| Vibrato sur note longue | +/- 20 a 50 cents, a ne pas prendre pour une autre note |
| Changement de position, glissando audible | Une hauteur transitoire entre deux notes |
| Bruit de fond (voix, television) | Des hauteurs qui ne sont pas du violon |
| Doubles cordes | Hors de portee de YIN : **mesure a part, hors critere** |

---

## Le materiel

**La prise doit entendre ce que l'application entendra.** Un banc enregistre
autrement mesurerait un autre micro.

- **Appareil** : le Galaxy S22, pose sur le pupitre a sa place d'usage, a cote
  de la partition papier. Noter la distance au chevalet (ordre de grandeur :
  70 cm).
- **Source micro** : `UNPROCESSED`, comme l'application. La plupart des
  enregistreurs du telephone passent par `MIC`, avec AGC et reduction de
  bruit : **a proscrire**, cela fausse justement les attaques.
- **Enregistreur** : celui de l'application, *Outils > Banc d'essai*, present
  dans la **version de debug seulement** (`flutter run` ou `make apk` en
  debug). Il reprend exactement les reglages du micro de l'application, et
  nomme chaque fichier comme ses metadonnees. Une seconde prise du meme nom
  devient `-2`, jamais un ecrasement. Le niveau affiche sert a placer le
  telephone : une crete au-dessus de -1 dBFS sature.

  Les prises restent dans le dossier prive de l'application jusqu'a :

  ```sh
  tool/prises.sh     # copie dans $VIOLON_BANC/prises, verifie, efface du telephone
  ```

  Verifier une premiere fois la source pendant une prise :

  ```sh
  adb shell dumpsys media.audio_flinger | grep -i source
  ```

  On doit y lire `AUDIO_SOURCE_UNPROCESSED`.
- **Format** : WAV PCM 16 bits, **mono, 44 100 Hz**, sans compression. C'est
  le format que `RecordAudioCapture` fournit au pipeline (`PcmFramer`, YIN et
  `OnsetDetector` sont regles sur 44 100 Hz). Pas de MP3 ni d'AAC : la
  compression lisse precisement les transitoires qu'on veut mesurer.
- **Telephone en mode avion / ne pas deranger**, ecran allume.

---

## Les partitions

Chaque prise se rapporte a une partition encodee au format du modele pivot
(`ScoreNote`) : `id`, `midi`, `onsetTicks`, `durationTicks`, `measure`, avec
`ticksPerBeat` et `writtenTempoBpm` au niveau du passage.

Deux informations manquent au modele et **sont necessaires a l'analyse** des
echecs. Elles sont ajoutees dans le fichier du banc, pas dans `ScoreNote` :
P1 ne touche pas au modele.

- `slur` : identifiant de liaison, identique pour les notes d'un meme archet ;
- `tie` : vrai si la note prolonge la precedente (aucune nouvelle hauteur ni
  attaque attendue).

Trois sources, pour couvrir le repertoire reel et garder un exemple partageable :

1. **Une gamme ou un exercice du catalogue** (`gamme-sol-majeur-1` par
   exemple) : deja encodee, domaine public, sert de reference propre.
2. **Deux pieces qu'il travaille en ce moment au conservatoire.** C'est le vrai
   usage, et c'est la que se trouvent les arrets. Encodees a la main, gardees
   dans le banc.
3. **Une piece du domaine public de son niveau** (Gossec, *Gavotte* ; Bach,
   *Menuet* en sol ; ou equivalent), si ses pieces du moment sont sous droits :
   c'est la seule dont l'annotation pourrait un jour etre publiee.

Un passage de **8 a 16 mesures** suffit. Mieux vaut beaucoup de reprises sur
peu de mesures qu'un morceau entier qu'on n'annotera jamais.

---

## La grille des prises

Douze prises, courtes (**20 a 60 secondes**). Dix comptent pour le critere,
deux sont mesurees a part.

| # | Partition | Consigne | Piege vise | Critere |
|---|---|---|---|---|
| 1 | Gamme | Detache, tempo regulier | Reference propre | oui |
| 2 | Gamme | Liee par deux puis par quatre | Liaisons sans attaque | oui |
| 3 | Exercice ou piece | Notes repetees en detache | YIN aveugle | oui |
| 4 | Piece A | Du debut a la fin, sans consigne | Passage fluide | oui |
| 5 | Piece A | S'arreter et reprendre la mesure difficile | **Arret / reprise** | oui |
| 6 | Piece A | Reprendre deux fois au debut de la phrase | **Saut en arriere** | oui |
| 7 | Piece B | Vraie seance de travail, **sans consigne** | **Arret / reprise reels** | oui |
| 8 | Piece B | Tres lent, comme pour dechiffrer | Hesitations, silences | oui |
| 9 | Piece B | Une note fausse, une sautee, une ajoutee (volontaires) | Erreurs controlees | oui |
| 10 | Piece A ou B | Notes longues avec vibrato, changements de position | Vibrato, glissando | oui |
| 11 | Piece A | Comme 4, avec une voix ou la television en fond | Bruit | a part |
| 12 | Passage en doubles cordes | Tel qu'ecrit | Doubles cordes | a part |

Les prises 5, 6 et 7 remplissent l'exigence des trois prises avec reprise.
**La 7 est la plus precieuse** : un arret qu'on demande n'a jamais l'allure
d'un arret vrai. Si possible, en capter deux ou trois pendant des seances
ordinaires, et garder les meilleures.

---

## Avec l'enfant

Les principes produit valent aussi pour le banc : c'est la machine qu'on
teste, pas lui.

- **Lui dire a quoi ca sert**, et que rien n'est note. Il a le droit de dire
  non a une prise, et de ne pas l'avoir en entier.
- **Trois courtes seances**, pas une longue : quinze minutes au plus, prises
  dans son travail normal. Ne jamais lui faire rejouer une prise "parce
  qu'elle n'etait pas bien" : une prise ratee est exactement ce qu'on cherche.
- Les consignes des prises 8 et 9 sont un jeu (faire expres de se tromper),
  pas un exercice.
- Terminer chaque seance sur un passage qu'il reussit.

---

## Avant chaque seance

- [ ] Violon accorde ; relever le la mesure par l'accordeur de l'application
- [ ] Telephone sur le pupitre, a la place d'usage ; distance notee
- [ ] Mode avion, ne pas deranger
- [ ] Version de debug installee ; source `UNPROCESSED` verifiee par
      `dumpsys` une premiere fois
- [ ] Une seconde de silence avant de jouer, une apres

---

## L'annotation corrigee (retenue)

**L'annotation de zero s'est revelee trop longue** des la prise pilote, sur
une simple gamme. Elle est remplacee par une annotation **corrigee** :
l'aligneur propose, l'oreille humaine ne reprend que ses erreurs.

```sh
dart run tool/marqueurs.dart proposer 05-stars-arret-reprise
#  -> prises/05-stars-arret-reprise.app.txt
```

1. Dans Audacity, ouvrir le WAV, puis *Fichier > Importer > Marqueurs* :
   `<prise>.app.txt`. Chaque marqueur se lit `m5 re n23` : mesure, note,
   identifiant.
2. Ecouter **une fois**, a vitesse normale, en suivant les marqueurs. Ne
   toucher qu'aux erreurs, en ecrivant ce qu'on entend, sans identifiant :
   `m6 mi`, `m6 mi faux`, `x`, `?`. Supprimer un marqueur qui ne correspond a
   rien, en ajouter un (Ctrl+B) sur une note oubliee, poser les regions
   `arret`.
3. Exporter les marqueurs sous `<prise>.corrige.txt`, puis :

```sh
dart run tool/marqueurs.dart valider 05-stars-arret-reprise
#  -> prises/05-stars-arret-reprise.labels.txt, lu par tool/banc.dart
```

L'outil retrouve l'identifiant de chaque note corrigee dans la mesure ecrite
et liste ceux qu'il a deduits, pour relecture.

**Le prix, ecrit ici pour ne pas l'oublier au verdict** : qui corrige une
machine lui donne raison quand il hesite. Le chiffre du jalon est donc un
**plafond** de ce qu'une annotation independante aurait donne, et l'ADR de
P3 le dira. Les erreurs grossieres -- perdre la mesure, ne pas voir une
reprise -- ne se laissent pas passer par complaisance : ce sont elles que
le critere vise.

**Effort reparti selon ce que chaque prise apprend** :

- prises avec reprise (05, 06, 07) : corrigees avec soin, c'est le cas
  nominal ;
- les autres, gammes comprises : ecoutees une fois, en ne relevant que les
  pertes de fil. Sur une gamme, c'est trente secondes d'ecoute.

Le critere ne change pas : dix prises, dont les trois avec reprise.

L'annotation de zero, ci-dessous, reste la reference si un doute sur le
chiffre demande un jour une verification independante.

## L'annotation de zero (reference)

A la main, dans **Audacity** (piste d'etiquettes), le parent qui a une
oreille musicale suffit. Chaque note jouee recoit une etiquette ponctuelle
posee sur **son debut** :

- sur l'attaque d'archet quand il y en a une ;
- au changement de hauteur dans une liaison ;
- zoomer sur la forme d'onde et le spectrogramme ; une precision de **20 ms**
  suffit. Le critere porte sur la position, pas sur l'instant ; l'instant
  servira plus tard au juge (N3).

**Syntaxe des etiquettes** (une etiquette par note jouee) :

| Etiquette | Sens |
|---|---|
| `n12` | Note jouee a la place de la note `n12` de la partition, juste |
| `n12 faux` | Au bon endroit, mais pas la bonne hauteur. **Reste `n12`** : le suiveur doit savoir ou il en est meme si la note est fausse |
| `x` | Note jouee qui ne correspond a aucune note de la partition (ajoutee, essai de doigt, bruit de corde) |
| `?` | Doute de l'annotateur. Exclue du calcul, comptee a part |

Une note **sautee** n'a pas d'etiquette : son absence suffit. Une mesure
rejouee trois fois donne trois fois les memes `id`, dans l'ordre ou elles ont
ete jouees.

Les **arrets** sont des etiquettes de region `arret`, du dernier son au
suivant, quand le silence depasse une seconde.

Export : *Fichier > Exporter > Exporter les etiquettes*, a cote du WAV.

**Commencer par un pilote** : une prise enregistree et annotee de bout en
bout avant les onze autres, pour chronometrer l'annotation et corriger ce
protocole. Estimation de depart : une demi-heure par minute de jeu.

---

## L'arborescence du banc

```
$VIOLON_BANC/
  partitions/
    gamme-sol-majeur-1.json
    piece-a.json
  prises/
    07-piece-b-seance.wav
    07-piece-b-seance.labels.txt     <- export Audacity, tel quel
    07-piece-b-seance.json           <- metadonnees
  synthese/                          <- prises de synthese (lot P0)
```

Le dossier `synthese/` se remplit par `dart run tool/synthese.dart`. Ses prises
suivent le meme format que les vraies, etiquettes comprises, pour qu'on les
ecoute et les aligne avec les memes outils. **Elles ne comptent jamais pour le
critere.**

Metadonnees d'une prise :

```json
{
  "id": "07-piece-b-seance",
  "date": "2026-10-04",
  "partition": "piece-b",
  "mesures": [5, 16],
  "consigne": "vraie seance, sans consigne",
  "pieges": ["arret-reprise"],
  "critere": true,
  "la_mesure_hz": 441.2,
  "source_micro": "UNPROCESSED",
  "distance_cm": 70,
  "bruit": "aucun",
  "annotateur": "parent",
  "remarques": ""
}
```

Le JSON d'une partition reprend les champs de `ScoreNote` et y ajoute `slur`
et `tie`.

---

## Comment P2 et P3 compteront

Pour ne pas decider de la regle apres avoir vu les chiffres :

- **Denominateur** : les notes etiquetees `nX` ou `nX faux`. Les `x` et les
  `?` en sont exclus, et comptes a part (un suiveur qui prend un `x` pour une
  note de la partition est une erreur, mesuree separement).
- **Bonne mesure** : la mesure de la note que l'alignement associe egale la
  mesure de `nX`.
- **Bonne note** : l'identifiant associe est exactement `nX`.
- **Par prise et par piege**, pas seulement en moyenne : 95 % global peut
  cacher 60 % sur les reprises, qui sont le cas nominal. Le verdict de P3
  exige le seuil sur l'ensemble **et** sur les trois prises avec reprise.
- Les prises 11 et 12 sont rapportees, jamais melangees au critere.

---

## Passer le banc

```sh
dart run tool/banc.dart            # le tableau et le verdict
dart run tool/banc.dart --detail   # plus chaque note mal placee
```

L'outil lit les metadonnees de chaque prise. Deux champs y sont indispensables :

- `critere` : seules les prises a `true` comptent ;
- `pieges` : une prise est **avec reprise** au sens du critere si elle
  contient `arret-reprise` ou `saut-arriere`. Ecrire ces deux mots tels
  quels.

Le tableau rapporte aussi le **suiveur en direct** (colonne `direct`) et son
**pire rattrapage** apres une reprise ou un saut (lot S3). Ils ne comptent
pas pour le critere -- la note se calcule sur la prise entiere -- mais c'est
le direct que l'ecran montre.

`la_mesure_hz` sert d'accord de reference : un la joue sur un violon accorde a
441 est un la juste. Sans lui, l'outil suppose 440.

---

## Fini quand

- [ ] Le pilote est annote et le protocole corrige en consequence
- [ ] Au moins dix prises au critere, dont trois avec arret et reprise
- [ ] Chaque prise a son WAV, ses etiquettes et ses metadonnees
- [ ] Chaque partition utilisee est encodee, avec liaisons et tenues
- [ ] Rien du banc n'est dans le depot (`git status` propre)
