# Feuille de route

Quatre jalons. Chacun doit produire quelque chose d'utilisable, meme
incomplet : l'application doit servir a quelqu'un des le premier.

---

## V1 - Rendre la repetition supportable

**Objectif :** il travaille une mesure difficile sans se lasser.
**Utilisable des :** le boucleur avec variations tourne, meme sans partition.

Ce jalon ne contient volontairement **aucun rendu de partition**. C'est le
poste le plus couteux du projet, et celui dont il a le moins besoin
aujourd'hui.

- [x] Modele de notes (`ScoreNote`, `Passage`)
- [x] Conversions hauteur / frequence / cents
- [x] Detection de hauteur YIN
- [x] Abstraction `PitchSource` + implementation factice
- [x] Generateur de variations
- [x] Session de travail (tours, tempo progressif, resultats)
- [ ] Capture micro reelle sur Android (`UNPROCESSED`)
- [ ] YIN dans un isolate
- [ ] Accordeur sol-re-la-mi avec affichage en cents
- [ ] Calibration de latence au premier lancement
- [ ] Metronome visuel
- [ ] Metronome sonore pre-planifie
- [ ] Saisie manuelle d'un passage (sans MusicXML)
- [ ] Ecran de session complet et jouable

**Critere de sortie :** il fait une session de 10 tours du debut a la fin,
sur son telephone, sans mon aide.

---

## V2 - La partition arrive

**Objectif :** il voit ce qu'il joue, l'application suit.

- [ ] Pipeline Verovio hors ligne (script Node) : MusicXML -> SVG + timemap
- [ ] Format de catalogue local des morceaux
- [ ] Affichage SVG, systemes courts de 2 mesures
- [ ] Curseur de position, defilement par saut de systeme
- [ ] Mode tempo impose
- [ ] Selection d'une boucle en tapant deux mesures
- [ ] Overlay de coloration par note
- [ ] Enregistrement de chaque tentative
- [ ] Comparaison avec une tentative anterieure

**Critere de sortie :** un morceau de son repertoire est dans l'application,
et il peut selectionner une boucle directement sur la partition.

---

## V3 - Le suivi

**Objectif :** le progres devient visible, et le professeur entre dans la boucle.

- [ ] Persistance des sessions (base locale)
- [ ] Heatmap cumulee sur la partition
- [ ] Diagnostic actionnable ("mesure 12, systematiquement bas sur le do#")
- [ ] Courbe de justesse dans le temps
- [ ] Tempo maximal atteint par passage
- [ ] Timer de seance avec arret suggere
- [ ] Drone / bourdon sur la tonique
- [ ] Gammes et arpeges avec score par degre
- [ ] Note tenue dans la zone verte
- [ ] Export pour le professeur

---

## V4 - Plus tard

- [ ] Suivi adaptatif (l'application attend la bonne note)
- [ ] Doigtes et coups d'archet editables
- [ ] Play-along a partir du MusicXML
- [ ] Mode "a toi, a moi"
- [ ] Portage iOS
- [ ] Import MusicXML depuis l'application

---

## Ce qui est explicitement hors perimetre

- Tout backend, compte utilisateur ou synchronisation
- Toute telemetrie
- L'evaluation de la sonorite, du phrase ou de la conduite d'archet :
  aucune application ne sait le faire, et pretendre le contraire
  appauvrirait la musique. L'outil est un complement technique, pas un
  professeur.
- La distribution publique tant que des partitions sous droits sont
  embarquees
