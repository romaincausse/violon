# Plan

**Fichier unique de suivi.** Il remplace `roadmap.md` et `backlog.md`, qui
disaient la meme chose a deux endroits et finissaient toujours par diverger.

Le *pourquoi* est ailleurs : `docs/decisions.md` pour les choix structurants,
`docs/journal.md` pour les retournements et les tensions non tranchees,
`docs/professeur.md` pour l'usage par le professeur.

---

## Le principe

L'eleve joue sur **sa partition papier**, a son tempo, quand il veut.
**L'application l'ecoute et le suit** : elle sait a tout instant ou il en est.
De ce suivi elle tire la justesse, le rythme, et **les mesures a rejouer**.

Le telephone n'est pas un pupitre. C'est un professeur qui ecoute.

Et un objectif qui vaut regle de conception : **l'application doit donner
envie de travailler son violon.** Un outil juste et complet dont on n'a pas
envie de se servir a echoue.

---

## Comment lire ce plan

Chaque lot porte deux marques.

**Must** : sans lui, l'application ne fait pas son travail. Non negociable,
quel que soit le cout.

**ROI**, effet rapporte au cout :

| | Sens |
|---|---|
| ★★★ | Gros effet, petit cout. A faire en premier meme si ce n'est pas un *must*. |
| ★★ | Bon rapport, a sa place dans le fil normal. |
| ★ | Cher ou secondaire. Se justifie, mais se reporte sans douleur. |

Estimations en soirees de travail. Une ligne = une PR.

**Le principe d'ordonnancement.** Les jalons ne suivent pas les dependances
techniques mais le ROI, dependances respectees. C'est pourquoi le jalon 1 ne
contient aucun *must* : ce sont six lots a fort effet qui marchent **avec le
code deja livre**, sans attendre les quatorze soirees du suiveur. Mieux vaut
trois semaines qui se voient qu'un banc d'essai muet.

---

## Les huit jalons

| # | Jalon | Lots | Soirees | Ce qu'on gagne |
|---|-------|------|---------|----------------|
| 1 | Le retour qui se voit | 6 | 10 | Ca devient agreable, tout de suite |
| 2 | La preuve | 3 | 6 | On sait si le suiveur tient |
| 3 | Le suivi | 7 | 12 | L'application ne perd plus le fil |
| 4 | La note | 9 | 13 | Justesse et rythme, par mesure |
| 5 | Quoi rejouer | 5 | 8 | La boucle de travail se ferme |
| 6 | La memoire | 7 | 16 | Le progres devient visible |
| 7 | Le professeur | 4 | 7 | La semaine cesse d'etre invisible |
| 8 | L'accompagnement | 6 | 14 | On joue avec quelqu'un |

**47 lots, 86 soirees** au total, dont **28 soirees de *must*** -- le reste
est ce qui rend l'application agreable, et ce n'est pas du luxe : un outil
juste et complet dont on n'a pas envie de se servir a echoue.

---

## Jalon 1 - Le retour qui se voit

**Utilisable des maintenant :** tout ce jalon tourne sur le code deja livre.
Aucun lot n'attend le suiveur.

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| I1 | Cordes a vide comme ancre, alerte de desaccord | | ★★★ | 2 |
| I2 | Intonation expressive | | ★★★ | 2 |
| D1 | Bandeau de mesures | | ★★★ | 2 |
| D2 | Ruban de justesse | | ★★★ | 2 |
| D4 | Profils d'affichage | | ★★ | 1 |
| D5 | Halo de fin de mesure | | ★★ | 1 |

### I1 - Cordes a vide comme ancre, alerte de desaccord

Des qu'il joue une corde a vide, l'application obtient **gratuitement** une
mesure de l'accord reel de l'instrument, en plein morceau.

Un violon se desaccorde en jouant : cordes neuves, chauffage, chute de la
mentonniere. Aujourd'hui, si son mi descend de quinze cents en cours de
seance, l'application lui reproche sa justesse pendant une demi-heure --
**elle l'accuse d'une faute qui appartient a l'instrument.** Elle doit dire
"ton mi a baisse, reaccorde", et proteger son propre verdict au passage.

L'accordeur et le `A4Estimator` existent : il n'y a qu'a les ecouter en
continu.

### I2 - Intonation expressive

C'est une faute **deja livree**. `LiveTuning` compare a la note temperee. Or
un violoniste ne joue pas tempere : une sensible se joue haute, une tierce
majeure basse par rapport au piano, et en 4e annee c'est deja enseigne.

L'application marque donc systematiquement faux ce qu'il joue juste, sur des
notes precises et toujours les memes. Au minimum une tolerance elargie sur
les degres concernes, au mieux une reference melodique optionnelle.

### D1 - Bandeau de mesures

**Le second visuel principal.** Pas la partition gravee : un rectangle par
mesure, en ligne. Celui en cours est marque, les autres se colorent au fur et
a mesure qu'ils sont notes.

Pourquoi ca marche : pendant qu'il joue, **ses yeux sont sur le papier**. Il
ne reste que la vision peripherique, qui ne sait pas lire une tete de note
mais sait tres bien voir un gros bloc changer de couleur.

Et le meme widget sert deux fois : pendant le passage il montre ou on en est,
apres le passage **il est le bilan**. Un seul objet, deux moments.

### D2 - Ruban de justesse

Une bande horizontale ou un trait se deplace verticalement selon l'ecart :
**au milieu quand c'est juste, il monte quand c'est haut, il descend quand
c'est bas.** Le sens compte -- un violoniste pense en position de doigt, pas
en gauche-droite.

En laissant une trace, il dessine le contour reel de ce qui a ete joue : on
voit d'un coup qu'une note est attaquee basse puis rattrapee, ce qu'aucun
score ne raconte.

Contraintes : aucun rouge (regle produit), et la hauteur du trait doit porter
l'information **sans la couleur**, pour rester lisible a un daltonien.

### D4 - Profils d'affichage

Trois profils, parce que le bon affichage depend de ce qu'il sait deja :

- **Decouverte** -- il apprend les notes, il lit son papier. Ecran sobre : le
  bandeau, le ruban, rien d'autre.
- **Par coeur** -- il connait le passage. **La partition en direct prend tout
  son sens ici**, curseur et coloration compris.
- **Pupitre** -- trois informations maximum, taille maximale, lisible d'un
  coup d'oeil a soixante-dix centimetres.

### D5 - Halo de fin de mesure

Une mesure passee proprement fait brievement respirer le bord de l'ecran.
Discret, non textuel, lisible du coin de l'oeil, et cale sur la **mesure** --
jamais sur la note, qui clignoterait en permanence.

C'est la seule recompense autorisee : de la lumiere, pas un badge.

---

## Jalon 2 - La preuve

**Ne livre aucune fonctionnalite, et c'est assume.** Le suivi adaptatif etait
decrit comme le lot le plus risque du projet. Le prouver coute six soirees ;
batir quarante soirees dessus sans l'avoir prouve en couterait bien plus.

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| P1 | Banc d'essai : vraies prises, annotees a la main | **Must** | ★★ | 2 |
| P2 | Alignement hors ligne (hauteurs + attaques) | **Must** | ★★ | 3 |
| P3 | Verdict chiffre et ADR | **Must** | ★★★ | 1 |

**Critere de sortie :** sur dix prises reelles, dont au moins trois avec arret
et reprise de mesure, l'alignement place **95 % des notes dans la bonne
mesure** et **90 % sur la bonne note**. En dessous, c'est le plan qui change.

---

## Jalon 3 - Le suivi

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| S1 | Flux unique hauteurs + attaques, sans trou | **Must** | ★★ | 2 |
| S2 | Suiveur en ligne | **Must** | ★★★ | 3 |
| S3 | Re-ancrage : arret, reprise, saut | **Must** | ★★★ | 3 |
| S4 | Position suivie a l'ecran | **Must** | ★★★ | 1 |
| S5 | Confiance du suiveur visible | | ★★★ | 1 |
| D3 | Pouls du tempo detecte | | ★★ | 1 |
| S6 | Mode metronome conserve | | ★ | 1 |

**S1 est le point dur.** L'analyse de hauteur jette des trames sous pression,
le detecteur d'attaques exige un flux sans trou, et le suiveur consomme les
deux. L'arbitrage n'est plus reportable.

**S5** n'est pas un confort : un suiveur qui se trompe en silence noterait
n'importe quoi. Quand il ne sait plus, il doit le dire.

**D3 - Pouls du tempo detecte.** Une pulsation visuelle calee non pas sur un
metronome, mais sur **le tempo qu'il est en train de tenir**. L'application
respire avec lui. C'est le retour qui rend le suivi credible : il voit qu'elle
le suit, donc il la croit.

Ce jalon repare au passage un defaut livre : aujourd'hui, un enfant en retard
d'une croche est mesure contre la note **suivante**.

---

## Jalon 4 - La note

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| ~~N1~~ | ~~Justesse par note~~ | **Must** | ★★★ | fait |
| N2 | Tempo reellement tenu | **Must** | ★★ | 2 |
| N3 | Score de rythme, a ce tempo | **Must** | ★★★ | 2 |
| N5 | Agregation par mesure | **Must** | ★★★ | 1 |
| N6 | Bilan de passage | **Must** | ★★★ | 1 |
| N4 | Detection des hesitations | | ★★★ | 2 |
| B1 | Compteur de reprises par mesure | | ★★★ | 1 |
| B2 | Carte des arrets | | ★★ | 1 |
| B3 | Notes evitees ou ecourtees | | ★★ | 1 |
| C1 | Courbe de tempo interne | | ★★★ | 2 |

**La regle du jalon (ADR-010).** Jouer juste a 74 au lieu de 92 n'est pas une
faute de rythme : c'est un tempo tenu. Jouer une noire comme une croche en est
une. S'arreter deux secondes avant le do# n'est ni l'un ni l'autre.

**B1 - Compteur de reprises.** Une mesure rejouee quatorze fois est une mesure
qui fait peur, meme si elle finit juste. C'est probablement un meilleur
indicateur de difficulte que le score lui-meme, et il est presque gratuit :
le suiveur le sait deja.

**B2 - Carte des arrets.** La ou il s'arrete, c'est la lecture ou le doigte
qui casse, pas la justesse. Autre diagnostic, autre remede.

**B3 - Notes evitees.** Un enfant qui doute d'une note l'ecourte ou la saute.
Le suiveur le voit ; l'oreille d'un parent, non.

**C1 - Courbe de tempo interne.** Presque tout le monde accelere dans le
facile et ralentit dans le difficile sans s'en rendre compte. Montrer la
courbe dit ce qu'aucun score par note ne dit : *"tu ralentis de 20 % a la
mesure 7"* -- le passage n'est pas sur, meme si chaque note est juste.

**Aucune dependance nouvelle pour finir ce jalon.** Le rythme est juge en
comparant les attaques entre elles ; une latence de capture constante
disparait de la soustraction.

---

## Jalon 5 - Quoi rejouer

**C'est ici que la boucle se ferme.** Jusqu'au jalon 4 l'application constate ;
a partir d'ici elle dirige le travail. Et c'est ici que survit la reponse a la
lassitude : ce n'est plus l'enfant qui decide de rejouer la meme mesure pour la
dixieme fois, c'est la mesure qui designe la mesure.

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| R1 | Selection des mesures faibles | **Must** | ★★★ | 1 |
| R2 | Boucle sur la selection | **Must** | ★★★ | 2 |
| R3 | Montee de tempo automatique | **Must** | ★★★ | 2 |
| R4 | Fin sur une reussite | | ★★★ | 1 |
| C2 | Point de rupture | | ★★★ | 2 |

**C2 - Point de rupture.** L'application monte le tempo jusqu'a ce que ca
casse, note le chiffre, et redescend. C'est la technique de travail classique,
automatisee -- et c'est une donnee qui monte de semaine en semaine, ce que le
projet cherche depuis le debut.

---

## Jalon 6 - La memoire

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| H1 | Persistance passages et seances | **Must** | ★★ | 2 |
| H3 | Erreurs systematiques par doigt | | ★★★ | 3 |
| H4 | Courbes de progression | | ★★★ | 2 |
| H5 | Journal de seance | | ★★ | 1 |
| H2 | Heatmap cumulee sur la partition | | ★★ | 3 |
| M2 | Avant / apres audible | | ★★★ | 2 |
| H6 | Import d'un morceau entier | | ★★ | 3 |

**H3 - Erreurs systematiques.** Le differenciateur. Les fautes d'un violoniste
ne sont pas aleatoires, elles sont **structurees par la main** : un demi-ton
mal place entre deux doigts se retrouve sur toutes les notes qui le demandent,
sur toutes les cordes, dans toutes les mesures. Un score par note dit "cette
note est basse" ; un diagnostic par doigt dit **pourquoi**. Aucun metronome ni
accordeur du marche ne sait le faire.

**M2 - Avant / apres audible.** Enregistrer la premiere et la derniere prise
d'une seance, et le laisser les comparer. S'entendre progresser en vingt
minutes est le motivateur le plus puissant qui existe, bien plus qu'un score.

> **A trancher avant de commencer ce lot.** `docs/professeur.md` interdit de
> conserver le moindre enregistrement audio, pour de bonnes raisons. Sortie
> possible : strictement local, strictement ephemere, efface en quittant,
> jamais exportable, jamais accessible au professeur. Sa voix a lui, pour lui.

**H6 - Import.** Suivre suppose la partition en machine. La saisie a la main
tient pour un passage, pas pour un morceau. L'OMR (reconnaissance optique)
reste **hors de l'application** : une lecture a 95 % n'est pas 95 % utile ici,
elle est nuisible, car l'application reprocherait a l'enfant une faute de
rythme qu'elle a elle-meme inventee.

---

## Jalon 7 - Le professeur

Detail et garde-fous : `docs/professeur.md`.

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| T2 | Rapport de travail | | ★★★ | 2 |
| T1 | Devoirs de la semaine | | ★★ | 2 |
| T3 | Export fichier | | ★★ | 1 |
| T4 | Mode lecon | | ★ | 2 |

**La ligne a ne pas franchir.** Le jour ou l'enfant comprend que l'application
rapporte a l'adulte ce qu'il n'a pas fait, il arrete de jouer devant elle.
L'export reste un geste volontaire, sur son telephone, avec ses donnees.

---

## Jalon 8 - L'accompagnement

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| J1 | Moteur audio pre-planifie | | ★★ | 2 |
| J4 | Accompagnement deduit du passage | | ★★★ | 3 |
| J2 | Calibration de latence | | ★★ | 2 |
| J3 | Metronome sonore | | ★ | 1 |
| J5 | Accompagnement qui suit | | ★ | 5 |
| D6 | Retour haptique hors ecoute | | ★★ | 1 |

**D6 - Retour haptique.** Tentant, mais un telephone qui vibre sur un pupitre
en bois **est une source sonore** qui entre dans le micro. Le vibreur est donc
interdit pendant l'ecoute, et reserve aux moments ou l'application n'ecoute
pas : un depart compte qu'on sent, la relance d'une boucle. Il est range ici
pour cette raison, pas par manque d'interet.

**La contradiction a resoudre avant J5.** L'ADR-008 interdit d'ecouter pendant
que l'application joue. Mais un accompagnement qui *suit* -- le seul qui
vaille musicalement -- doit precisement ecouter. Casque, annulation d'echo, ou
renoncement : rien n'est choisi, d'ou le ★.

---

## Le palmares

Les douze meilleurs rapports effet/cout, tous jalons confondus. A piocher
dedans quand une soiree se libere.

| Lot | Jalon | Est. | Pourquoi |
|-----|-------|------|----------|
| R1 | 5 | 1 | Une soiree, et l'application se met a diriger le travail |
| B1 | 4 | 1 | Le meilleur indicateur de difficulte, presque gratuit |
| S4 | 3 | 1 | Le suivi devient enfin visible |
| S5 | 3 | 1 | Empeche de noter n'importe quoi en silence |
| P3 | 2 | 1 | Un chiffre qui valide ou annule quarante soirees |
| D5 | 1 | 1 | La seule recompense autorisee : de la lumiere |
| I1 | 1 | 2 | Cesse d'accuser l'enfant du desaccord de son violon |
| I2 | 1 | 2 | Cesse de marquer faux ce qu'il joue juste |
| D1 | 1 | 2 | Un seul widget : suivi pendant, bilan apres |
| D2 | 1 | 2 | L'ecart se voit sans lire, du coin de l'oeil |
| C1 | 4 | 2 | Dit ce qu'aucun score par note ne dit |
| C2 | 5 | 2 | Une donnee qui monte, semaine apres semaine |

---

## Dependances a arbitrer

Aucune n'est ajoutee sans accord explicite.

| Paquet | Pour | Jalon |
|--------|------|-------|
| ~~Bravura (asset, SIL OFL)~~ | ~~le rendu de partition~~ | **ajoutee** |
| ~~`record`~~ | ~~la capture micro~~ | **ajoutee** |
| stockage local | H1, la persistance | 6 |
| moteur audio bas niveau | J1, l'accompagnement | 8 |

**Rien a arbitrer avant le jalon 6.** Les cinq premiers jalons sont du calcul
sur des flux deja captes et du dessin sur un `CustomPainter` deja ecrit.

---

## Deja fait

Dix-huit lots livres. Le pivot de l'ADR-009 change ce qui les alimente et le
moment ou ils servent, pas ce qu'ils font.

| ID | Titre | PR | Devient |
|----|-------|----|---------|
| Z1 | Suppression du boucleur a cartes | #7 | - |
| - | Saisie manuelle d'un passage | #5 | Seule entree de partition jusqu'a H6 |
| G1 | Police Bravura et metriques SMuFL | #15 | Inchange |
| G2 | Mise en page d'une portee monodique | #6 | Inchange |
| G3 | Hampes, crochets, ligatures | #9 | Inchange |
| G4 | Widget de partition et coloration | #12 | Sert le profil "par coeur" (D4) |
| G5 | La partition passe a la ligne | #19 | Idem |
| G6 | Mode paysage | #20 | Idem |
| G7 | Choix defilement / plusieurs lignes | #19 | Idem |
| G8 | Zoom sur la partition | #19 | Idem |
| M1 | Metronome visuel | #11 | Devient le pouls du tempo detecte (D3) |
| F1 | Curseur pilote au tempo | #13 | Retrograde en mode secondaire (S6) |
| F2 | Coloration en direct de la justesse | #18 | A rebrancher sur le suiveur (S2) |
| A1 | Capture micro en `UNPROCESSED` | #16 | Entree du suiveur |
| A2 | YIN dans un isolate | #17 | Entree du suiveur |
| A3 | Detecteur d'attaques | #21 | Entree du suiveur **et** du juge de rythme |
| A5 | Lissage et tolerance vibrato | #22 | Inchange |
| A6 | Accordeur sol-re-la-mi | #23 | Base de l'ancre par cordes a vide (I1) |
| N1 | Score de justesse par note | #24 | Alimente par le suiveur, plus par l'horloge |

Le diapason mesure (#26) et le bilan affiche (#25) completent A6 et N1, sans
lot propre.

## Lots devenus caducs

| Ancien ID | Sort |
|----|------|
| A4 - Calibration de latence | Deplace en jalon 8 (J2), plus bloquant pour le rythme |
| F3 - Suivi adaptatif, V4 | **Devient le coeur** : jalons 2 et 3 |
| S1 (ancien) - Import MusicXML pre-grave | Remplace par H6, qui lit le MusicXML directement |

---

## Hors perimetre

- Tout backend, compte utilisateur, synchronisation ou telemetrie
- L'OMR embarque dans l'application (voir H6)
- L'evaluation de la sonorite, du phrase ou de la conduite d'archet : aucune
  application ne sait le faire, et pretendre le contraire appauvrirait la
  musique. L'outil est un complement technique, pas un professeur.
- La gamification enfantine. On montre des donnees qui montent.
- La distribution publique tant que des partitions sous droits sont embarquees
