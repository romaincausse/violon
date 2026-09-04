# Backlog

Une ligne = une PR. L'estimation est en soirees de travail, pas en heures.

Priorite : **P0** bloquant pour le jalon, **P1** important, **P2** confort.

> Backlog refondu apres l'ADR-006. Les lots audio de l'ancien plan sont
> conserves a l'identique : ils n'ont jamais dependu du boucleur.

## Jalon 0 - Faire de la place

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| Z1 | Supprimer le boucleur a cartes | P0 | 1 | - | `lib/core/practice/`, `PracticeScreen`, `RoundDots` et leurs tests. L'app s'ouvre sur le passage. |

## V1 - La partition vivante

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| ~~G1~~ | ~~Police Bravura et metriques SMuFL~~ | P0 | 1 | - | **Fait.** Asset sous licence SIL OFL, livre non modifie (Reserved Font Name). Une dizaine de glyphes declares dans `Smufl`. |
| ~~G2~~ | ~~Mise en page d'une portee monodique~~ | P0 | 3 | G1 | Positions verticales, lignes supplementaires, alterations, barres de mesure. Dart pur, teste sans widget. |
| ~~G3~~ | ~~Hampes, crochets, ligatures~~ | P0 | 2 | G2 | Sens de hampe a la 3e ligne, ligatures par groupe de temps. |
| ~~G4~~ | ~~Widget de partition et coloration par note~~ | P0 | 2 | G3 | `CustomPainter`. Une couleur par note, pilotee de l'exterieur. |
| ~~A1~~ | ~~Capture micro Android en `UNPROCESSED`~~ | P0 | 2 | - | **Fait.** `record` l'expose, pas de canal de plateforme a ecrire. Repli `VOICE_RECOGNITION` teste. |
| ~~A2~~ | ~~YIN dans un isolate~~ | P0 | 1 | A1 | **Fait.** Buffers transferes, pas copies. File bornee a 4 trames : sous pression, ce sont les plus vieilles qui sautent. |
| ~~M1~~ | ~~Metronome visuel~~ | P0 | 1 | - | Pulsation en bord d'ecran. Le seul metronome autorise en mode notation. |
| ~~F1~~ | ~~Curseur pilote au tempo~~ | P0 | 2 | G4, M1 | Avance sur l'horloge, pas sur ce qui est joue. Le suivi adaptatif est en V4. |
| ~~F2~~ | ~~Coloration en direct de la justesse~~ | P0 | 2 | F1, A2 | **Fait.** Vert, bleu, orange -- aucun rouge. Mediane des ecarts a la note attendue, pas a la note la plus proche. |

## V1+ - La partition lisible

Ajoute apres coup, sur demande. La portee tenait sur **une seule ligne** qui
defilait horizontalement : sur un passage de plus de deux mesures, l'enfant ne
voyait qu'un bout de ce qu'il jouait, et devait pousser l'ecran du doigt en
plein morceau. Une partition papier passe a la ligne ; celle-ci doit le faire
aussi.

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| ~~G5~~ | ~~La partition passe a la ligne~~ | P0 | 3 | G4 | **Fait.** Un systeme est une `StaffLayout` posee sur un morceau du passage : la gravure ne change pas, seulement son decoupage. |
| ~~G6~~ | ~~Mode paysage~~ | P1 | 1 | G5 | **Fait.** Verrou du manifeste leve. Portrait : jusqu'a 4 systemes, tout empile. Paysage : 2 systemes, commandes sur le cote. L'ecran de saisie suit la meme regle. |
| ~~G7~~ | ~~Choix defilement / plusieurs lignes~~ | P0 | 1 | G5 | **Fait.** Le defilement, c'est `ScoreLayout` avec une largeur infinie. Bouton dans la barre du haut. |
| ~~G8~~ | ~~Zoom sur la partition~~ | P0 | 1 | G5 | **Fait.** Pincement lu sur les evenements bruts : un detecteur de gestes raflerait le glissement a un doigt. |

## V2 - La note

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| ~~A3~~ | ~~Detecteur d'attaques~~ | P0 | 3 | A1 | **Fait.** Flux spectral sur sa propre decoupe (1024/256, soit 5,8 ms). FFT maison, `lib/core/` restant sans paquet. Rien ne le consomme avant N2. |
| A4 | Calibration de latence | P0 | 2 | A1 | Emission de clics, reecoute, offset stocke. Sans elle, le score de rythme ne veut rien dire. |
| ~~A5~~ | ~~Lissage et tolerance vibrato~~ | P0 | 2 | A2 | **Fait.** Mediane glissante qui ne franchit pas les notes, et reconnaissance d'oscillation. Branche dans la chaine : une erreur d'octave de YIN n'atteint plus la partition. |
| ~~N1~~ | ~~Score de justesse par note~~ | P0 | 2 | A5, F2 | **Fait.** Cents medians sur la partie tenue, attaque exclue. Note sur cent, courbe genereuse. Le bilan visible est N3. |
| N2 | Score de rythme par note | P0 | 2 | A3, A4 | Ecart d'attaque en ms par rapport a l'onset attendu. **A trancher a ce moment-la :** le detecteur d'attaques a besoin d'un flux sans trou, alors que l'analyse de hauteur jette des trames sous pression. Les deux ne peuvent pas partager la meme file. |
| N3 | Bilan de passage | P0 | 1 | N1, N2 | Un score par note, un global. Le cumul ne redescend jamais. |
| N4 | Boucle sur selection et montee de tempo | P0 | 2 | N3 | **Le lot anti-lassitude.** Deux mesures tapees, boucle, tempo qui monte quand c'est propre. |
| ~~A6~~ | ~~Accordeur sol-re-la-mi~~ | P1 | 2 | A2 | **Fait.** Aiguille horizontale et cents. Leve au passage le diapason fige a 440 : le la mesure devient la reference de la justesse. |

## V3 - L'accompagnement

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| J1 | Moteur audio a evenements pre-planifies | P0 | 2 | - | Jamais de `Timer` Dart, la derive est audible. **Dependance a choisir.** |
| J2 | Metronome sonore | P1 | 1 | J1 | Mode accompagnement uniquement (ADR-008). |
| J3 | Accompagnement deduit du passage | P0 | 3 | J1 | Basse et accords simples derives des notes. Pas d'arrangement savant. |
| J4 | Mode play-along | P0 | 1 | J3 | Micro coupe, aucune notation, depart compte. |

## V4 - La memoire et le repertoire

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| H1 | Persistance des passages et sessions | P0 | 2 | - | **Dependance a choisir.** Reprendre en 10 secondes. |
| H2 | Courbes de progression | P1 | 2 | H1 | Des donnees, pas des mascottes. |
| H3 | Heatmap cumulee sur la partition | P1 | 3 | H1, G4 | Le differenciateur principal. |
| H4 | Diagnostic actionnable | P1 | 3 | H1 | "Mesure 12, bas sur le do#". |
| F3 | Suivi adaptatif | P1 | 5 | N1, N2 | L'application attend la bonne note. Alignement en ligne, DTW ou HMM. Le lot le plus risque du projet. |
| S1 | Import MusicXML pre-grave par Verovio | P2 | 3 | G4 | Pour les morceaux entiers. Cohabite avec le rendu natif (ADR-007). |
| X1 | Export pour le professeur | P2 | 2 | H1 | Inscrit l'outil dans le circuit pedagogique. |

## Dependances a arbitrer

Aucune n'est ajoutee sans accord explicite.

| Paquet | Pour | Jalon |
|--------|------|-------|
| ~~Bravura (asset, SIL OFL)~~ | ~~G1, le rendu de partition~~ | **ajoutee** |
| ~~`record`~~ | ~~A1, la capture micro~~ | **ajoutee** |
| moteur audio bas niveau | J1, l'accompagnement pre-planifie | V3 |
| stockage local | H1, la persistance | V4 |
