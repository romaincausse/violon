# Backlog

Une ligne = une PR. L'estimation est en soirees de travail, pas en heures.

Priorite : **P0** bloquant pour le jalon, **P1** important, **P2** confort.

## V1

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| A1 | Capture micro Android en `UNPROCESSED` | P0 | 2 | - | Canal de plateforme si le paquet ne l'expose pas. Repli `VOICE_RECOGNITION`. |
| A2 | YIN dans un isolate | P0 | 1 | A1 | Buffers 2048, `Float32List` transferables. |
| A3 | Accordeur sol-re-la-bas-mi | P0 | 2 | A2 | Aiguille + cents. Premier ecran vraiment utile. |
| A4 | Calibration de latence | P1 | 1 | A1 | Emission de clics, reecoute, offset stocke. |
| A5 | Lissage et tolerance vibrato | P1 | 2 | A2 | Mediane glissante + detection d'oscillation periodique. |
| M1 | Metronome visuel | P0 | 1 | - | Pulsation en bord d'ecran. Prioritaire sur telephone. |
| M2 | Metronome sonore pre-planifie | P1 | 2 | M1 | Jamais de `Timer` Dart. |
| M3 | Gating du detecteur pendant les clics | P2 | 1 | M2, A2 | Le clic entre dans le micro a 10 cm. |
| P1 | Saisie manuelle d'un passage | P0 | 2 | - | Clavier de notes simple, sans MusicXML. |
| P2 | Ecran de session complet | P0 | 3 | P1, M1 | Une seule chose a l'ecran a la fois. |
| P3 | Detection automatique de reussite d'un tour | P1 | 3 | A2, P2 | Comparaison jeu / passage attendu. |
| P4 | Persistance du dernier passage travaille | P2 | 1 | P1 | Reprendre en 10 secondes. |

## V2

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| S1 | Script Verovio MusicXML -> SVG + timemap | P0 | 2 | - | Node, hors application. |
| S2 | Format de catalogue local | P0 | 1 | S1 | JSON par morceau. |
| S3 | Affichage SVG, systemes de 2 mesures | P0 | 3 | S2 | Portee ~10 mm de haut. |
| S4 | Curseur et defilement par saut | P0 | 2 | S3 | Jamais de defilement continu. |
| S5 | Selection de boucle par tap | P0 | 2 | S3 | Deux mesures tapees. |
| S6 | Overlay de coloration par note | P1 | 2 | S3, A2 | Vert / bas / haut / retard. |
| R1 | Enregistrement des tentatives | P0 | 2 | A1 | Fichier local + metadonnees. |
| R2 | Comparaison avec une tentative anterieure | P0 | 2 | R1 | Fort effet motivationnel, cout technique faible. |
| R3 | Replay synchronise sur la partition | P1 | 2 | R1, S4 | |

## V3

| ID | Titre | P | Est. | Depend de | Notes |
|----|-------|---|------|-----------|-------|
| H1 | Base locale des sessions | P0 | 2 | - | Drift ou sqflite. |
| H2 | Heatmap cumulee | P0 | 3 | H1, S3 | Le differenciateur principal. |
| H3 | Diagnostic actionnable | P1 | 3 | H1 | "Mesure 12, bas sur le do#". |
| H4 | Courbes de progression | P1 | 2 | H1 | Des donnees, pas des mascottes. |
| H5 | Timer de seance | P2 | 1 | - | Arret suggere sur une reussite. |
| E1 | Drone / bourdon | P1 | 1 | - | Meilleur rapport valeur / effort de la liste. |
| E2 | Gammes et arpeges notes | P1 | 3 | A2 | Score par degre. |
| E3 | Note tenue | P2 | 1 | A3 | |
| X1 | Export pour le professeur | P2 | 2 | R1, H2 | Inscrit l'outil dans le circuit pedagogique. |
