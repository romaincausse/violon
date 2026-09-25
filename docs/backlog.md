# Backlog

Une ligne = une PR. L'estimation est en soirees de travail, pas en heures.

Priorite : **P0** bloquant pour le jalon, **P1** important, **P2** confort.

> Backlog refondu apres les ADR-009 et ADR-010. Les lots barres sont faits et
> restent valables : le pivot change ce qui les alimente, pas ce qu'ils font.

## Jalon 0 - La preuve

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| P1 | Banc d'essai du suiveur | P0 | 2 | - | Enregistrer de vraies prises au violon, les annoter a la main note par note. Sans verite terrain, aucune mesure d'alignement ne veut rien dire. |
| P2 | Alignement hors ligne | P0 | 3 | P1 | DTW en ligne sur hauteurs + attaques, evalue hors ligne sur le banc. Dart pur, `lib/core/follow/`. |
| P3 | Verdict chiffre et ADR | P0 | 1 | P2 | Taux de notes bien placees, comportement sur arret et reprise. **Si le critere n'est pas atteint, le plan change ici.** |

## V1 - L'application sait ou tu en es

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| S1 | Flux unique hauteurs + attaques | P0 | 2 | - | **Le point dur.** L'analyse de hauteur jette des trames sous pression, le detecteur d'attaques exige un flux sans trou. Les deux alimentent le suiveur : l'arbitrage n'est plus reportable. |
| S2 | Suiveur en ligne | P0 | 3 | P3, S1 | Sort une position dans la partition et un tempo local, a chaque note. Elastique par construction : il ne juge rien (ADR-010). |
| S3 | Re-ancrage | P0 | 3 | S2 | Arret, reprise, saut, mesure rejouee dix fois. Un enfant qui travaille ne joue pas du debut a la fin : c'est le cas nominal, pas le cas limite. |
| S4 | Position suivie a l'ecran | P0 | 1 | S2 | La partition se cale sur la note suivie. La ligne courante reste visible sans toucher l'ecran. |
| S5 | Confiance du suiveur visible | P1 | 1 | S2 | Quand l'application ne sait plus ou elle en est, elle le dit. Un suiveur qui se trompe en silence noterait n'importe quoi. |
| S6 | Mode metronome conserve | P2 | 1 | S4 | `ScoreCursor` a l'horloge survit comme mode secondaire, pour travailler au metronome quand c'est le but. |

## V2 - L'application note ce que tu joues

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| ~~N1~~ | ~~Score de justesse par note~~ | P0 | 2 | - | **Fait.** Cents medians sur la partie tenue, attaque exclue, courbe genereuse. A rebrancher sur le suiveur : la note jugee devient celle qu'il joue, pas celle que l'horloge attendait. |
| N2 | Tempo reellement tenu | P0 | 2 | S2 | Courbe de tempo ajustee sur les attaques alignees. "74 au lieu de 92" est une information, pas une faute. |
| N3 | Score de rythme par note | P0 | 2 | N2 | Ecart residuel a la grille metrique, **au tempo tenu** (ADR-010). Ne depend ni de la calibration de latence ni d'un moteur audio : une latence constante disparait de la soustraction. |
| N4 | Detection des hesitations | P1 | 2 | N2 | Un trou anormal avant une note n'est ni un probleme de rythme ni de justesse. C'est souvent le diagnostic le plus utile a onze ans. |
| N5 | Agregation par mesure | P0 | 1 | N1, N3 | La mesure est l'unite de travail d'un professeur. C'est elle qu'on rejoue, donc c'est elle qu'on note. |
| N6 | Bilan de passage | P0 | 1 | N5 | Justesse, rythme, tempo tenu, hesitations. Le cumul ne redescend jamais. |

## V3 - L'application te dit quoi rejouer

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| R1 | Selection des mesures faibles | P0 | 1 | N5 | **Le lot demande.** Deux mesures, pas cinq : "voila ta prochaine tache", pas "voila tout ce que tu as rate". |
| R2 | Boucle sur la selection | P0 | 2 | R1, S3 | Suivie comme le reste. La reprise d'une boucle est exactement le cas que S3 doit encaisser. |
| R3 | Montee de tempo automatique | P0 | 2 | R2 | Le tempo monte quand c'est propre. Une erreur ne remet jamais le compteur a zero. |
| R4 | Fin sur une reussite | P1 | 1 | R3 | On ne quitte pas l'application sur un echec, et jamais en dessous du tempo ecrit. |

## V4 - L'application voit ce qui resiste

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| H1 | Persistance passages et seances | P0 | 2 | - | **Dependance a choisir.** Reprendre en 10 secondes. |
| H2 | Heatmap cumulee sur la partition | P0 | 3 | H1 | Ou ca coince depuis trois semaines, pas depuis trois minutes. |
| H3 | Erreurs systematiques par doigt | P0 | 3 | H1 | **Le differenciateur.** Les fautes d'un violoniste sont structurees par la main : un demi-ton mal place se retrouve partout ou il est demande. Dire "3e doigt bas sur re et sol" est actionnable ; dire "cette note est basse" ne l'est pas. |
| H4 | Courbes de progression | P1 | 2 | H1 | Justesse dans le temps, tempo maximal atteint. Des donnees, pas des mascottes. |
| H5 | Journal de seance | P1 | 1 | H1 | Ce qui a ete joue, combien de fois. Alimente le rapport du jalon suivant. |
| H6 | Import d'un morceau entier | P1 | 3 | - | Suivre suppose la partition en machine. La saisie a la main tient pour un passage, pas pour un morceau. **Remonte en V1 si l'usage le demande.** |

## V5 - Le professeur entre dans la boucle

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| T1 | Devoirs de la semaine | P0 | 2 | H1 | Passages et tempo vise, poses en fin de cours. Remplace la ligne du cahier que personne ne relit. |
| T2 | Rapport de travail | P0 | 2 | H5 | Jours, minutes, repetitions, progression, mesures qui resistent. Lisible en trente secondes. |
| T3 | Export fichier | P0 | 1 | T2 | Sans compte ni serveur (ADR-005). **Geste volontaire de l'enfant**, jamais un envoi automatique. |
| T4 | Mode lecon | P1 | 2 | T2 | L'application comme tiers pendant le cours : elle mesure, le professeur enseigne. |

## V6 - L'accompagnement

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| J1 | Moteur audio pre-planifie | P0 | 2 | - | **Dependance a choisir.** Jamais de `Timer` Dart, la derive est audible. |
| J2 | Calibration de latence | P0 | 2 | J1 | Emission de clics, reecoute, offset stocke. **N'est plus bloquante pour le rythme** (ADR-010) : elle ne sert qu'a faire tomber le son de l'application avec l'eleve. |
| J3 | Metronome sonore | P1 | 1 | J1 | Mode accompagnement uniquement (ADR-008). |
| J4 | Accompagnement deduit du passage | P0 | 3 | J1 | Basse et accords simples derives des notes. Pas d'arrangement savant. |
| J5 | Accompagnement qui suit | P1 | 5 | J4, S2 | Le seul qui vaille musicalement : il attend l'eleve. **Bute frontalement sur l'ADR-008**, qui interdit d'ecouter pendant que l'application joue. Casque, annulation d'echo, ou renoncement. |

## Dependances a arbitrer

Aucune n'est ajoutee sans accord explicite.

| Paquet | Pour | Jalon |
|--------|------|-------|
| ~~Bravura (asset, SIL OFL)~~ | ~~le rendu de partition~~ | **ajoutee** |
| ~~`record`~~ | ~~la capture micro~~ | **ajoutee** |
| stockage local | H1, la persistance | V4 |
| moteur audio bas niveau | J1, l'accompagnement pre-planifie | V6 |

**Rien a arbitrer avant le jalon V4.** Le pivot a libere les jalons 0 a V3 de
toute dependance nouvelle : le suivi et la notation du rythme sont du calcul
sur des flux qu'on capte deja.

## Lots devenus caducs

| Ancien ID | Titre | Sort |
|----|-------|------|
| A4 | Calibration de latence | Deplace en V6 (J2), plus bloquant pour le rythme |
| F1 | Curseur pilote au tempo | Fait, retrograde en mode secondaire (S6) |
| F3 | Suivi adaptatif, V4 | **Devient le coeur** : jalon 0, puis S2 et S3 |
