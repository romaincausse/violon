# Feuille de route

Quatre jalons. Chacun doit produire quelque chose d'utilisable, meme
incomplet : l'application doit servir a quelqu'un des le premier.

> **Ce plan remplace le precedent.** Le coeur n'est plus le boucleur a cartes
> mais la partition suivie en temps reel. Le raisonnement est dans
> `docs/decisions.md`, ADR-006 a ADR-008. Le constat qui avait fonde l'ancien
> plan reste vrai -- l'enfant se lasse de repeter -- et le nouveau coeur doit
> y repondre, pas l'ignorer.

---

## Jalon 0 - Faire de la place

**Objectif :** le depot ne contient plus que ce qui sert au nouveau plan.

- [x] Supprimer `lib/core/practice/` : variations, session, auto-evaluation
- [x] Supprimer `PracticeScreen` et `RoundDots`
- [x] L'application s'ouvre sur le passage, sans ecran de cartes

`lib/core/audio/` et `lib/core/music/` sont conserves entiers : ils
deviennent plus centraux qu'avant. L'editeur de passage aussi, il devient la
source des partitions.

---

## V1 - La partition vivante

**Objectif :** il voit son passage grave a l'ecran, et un curseur qui avance
avec lui pendant qu'il joue.

**Utilisable des :** la portee s'affiche et les notes se colorent en direct.

C'est le jalon qui coute le plus cher, et c'est assume : sans partition
affichee, rien du reste n'a de sens.

- [x] Police Bravura et metriques SMuFL
- [x] Mise en page d'une portee monodique (positions, alterations, barres)
- [x] Hampes, crochets, ligatures
- [x] Widget de partition, coloration par note
- [x] Capture micro reelle sur Android (`UNPROCESSED`)
- [ ] YIN dans un isolate
- [x] Metronome visuel
- [x] Curseur pilote au tempo
- [ ] Coloration en direct : juste, bas, haut

**Critere de sortie :** il joue ses deux mesures, les notes passent au vert ou
au rouge sous ses yeux, sans qu'il ait a toucher l'ecran.

**Ou on en est.** La partition se grave avec les glyphes de Bravura -- cle de
sol, tetes, alterations, crochets, points -- le curseur avance au tempo et le
metronome visuel bat. Le micro est capte en `UNPROCESSED` et la chaine rend
des hauteurs. Restent l'isolate et la coloration en direct, qui la relie
enfin a la partition.

---

## V2 - La note

**Objectif :** l'application mesure, et le chiffre monte de semaine en semaine.

**Utilisable des :** un score de justesse s'affiche apres un passage.

- [ ] Detecteur d'attaques (spectral flux)
- [ ] Calibration de latence au premier lancement
- [ ] Lissage et tolerance au vibrato
- [ ] Score de justesse par note, en cents
- [ ] Score de rythme par note, en millisecondes
- [ ] Bilan de passage, et le total cumule qui ne redescend jamais
- [ ] Boucle sur une selection, avec montee de tempo automatique
- [ ] Accordeur sol-re-la-mi

**Critere de sortie :** il fait dix passages d'affilee sans s'ennuyer, le
tempo monte tout seul, et il termine au tempo ecrit.

C'est ici que le projet repond a la lassitude. Si ce jalon sort et qu'il se
lasse quand meme, c'est le plan qu'il faut revoir, pas la fonctionnalite
suivante.

---

## V3 - L'accompagnement

**Objectif :** il joue avec quelqu'un.

**Utilisable des :** un accompagnement tourne au tempo pendant qu'il joue.

Mode separe de la notation : le micro est coupe pendant l'accompagnement
(ADR-008).

- [ ] Moteur audio a evenements pre-planifies
- [ ] Metronome sonore
- [ ] Accompagnement deduit du passage (basse et accords simples)
- [ ] Mode play-along, sans notation
- [ ] Depart compte, et arret sur la derniere note

**Critere de sortie :** il rejoue son morceau avec l'accompagnement pour le
plaisir, une fois le travail fini.

---

## V4 - La memoire et le repertoire

**Objectif :** le progres devient visible, et le professeur entre dans la
boucle.

- [ ] Persistance des passages et des sessions
- [ ] Courbe de justesse dans le temps, tempo maximal atteint
- [ ] Heatmap cumulee sur la partition
- [ ] Diagnostic actionnable ("mesure 12, systematiquement bas sur le do#")
- [ ] Suivi adaptatif : l'application attend la bonne note
- [ ] Import MusicXML pre-grave par Verovio, pour les morceaux entiers
- [ ] Export pour le professeur
- [ ] Portage iOS

---

## Ce qui est explicitement hors perimetre

- Tout backend, compte utilisateur ou synchronisation
- Toute telemetrie
- Etre note pendant l'accompagnement (ADR-008)
- L'evaluation de la sonorite, du phrase ou de la conduite d'archet :
  aucune application ne sait le faire, et pretendre le contraire
  appauvrirait la musique. L'outil est un complement technique, pas un
  professeur.
- La distribution publique tant que des partitions sous droits sont
  embarquees
