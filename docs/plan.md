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

## Les onze jalons

| # | Jalon | Lots | Soirees restantes | Ce qu'on gagne |
|---|-------|------|-------------------|----------------|
| 1 | Le retour qui se voit | 6 | 0 | Ca devient agreable, tout de suite |
| 2 | Les outils de tous les jours | 7 | 0 | L'application sert avant meme de jouer un morceau |
| 3 | Les gammes et les exercices | 2 | 0 | Utile **tous les jours**, sans rien preparer |
| 4 | Le son | 3 | 0 | Le bourdon, l'exercice de justesse le plus efficace |
| 5 | La preuve | 3 | 6 | On sait si le suiveur tient |
| 6 | Le suivi | 7 | 12 | L'application ne perd plus le fil |
| 7 | La note | 10 | 13 | Justesse et rythme, par mesure |
| 8 | Quoi rejouer | 6 | 9 | La boucle de travail se ferme |
| 9 | La memoire | 8 | 18 | Le progres devient visible |
| 10 | Le professeur | 4 | 7 | La semaine cesse d'etre invisible |
| 11 | L'accompagnement | 4 | 11 | On joue avec quelqu'un |

**60 lots, 76 soirees restantes**, dont **28 de *must*** -- le reste
est ce qui rend l'application agreable, et ce n'est pas du luxe : un outil
juste et complet dont on n'a pas envie de se servir a echoue.

Les lots barres sont livres ; la colonne des soirees ne compte que ce qui
reste.

**Le calendrier des dependances a change.** L'ancien plan n'arbitrait rien
avant le jalon 6. Le bourdon oblige a trancher le moteur audio au **jalon 4** :
c'est le prix a payer pour l'exercice de justesse que les violonistes citent
en premier.

## Jalon 1 - Le retour qui se voit

**Jalon termine.** Les six lots tournent sur le code deja livre, sans
dependance nouvelle, et deux d'entre eux -- I1 et I2 -- corrigeaient des
defauts en production plutot que d'ajouter une fonctionnalite.

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| ~~I1~~ | ~~Cordes a vide comme ancre, alerte de desaccord~~ | | ★★★ | fait |
| ~~I2~~ | ~~Intonation expressive~~ | | ★★★ | fait |
| ~~D1~~ | ~~Bandeau de mesures~~ | | ★★★ | fait |
| ~~D2~~ | ~~Ruban de justesse~~ | | ★★★ | fait |
| ~~D4~~ | ~~Profils d'affichage~~ | | ★★ | fait |
| ~~D5~~ | ~~Halo de fin de mesure~~ | | ★★ | fait |

### I1 - Cordes a vide comme ancre, alerte de desaccord

Des qu'il joue une corde a vide, l'application obtient **gratuitement** une
mesure de l'accord reel de l'instrument, en plein morceau.

Un violon se desaccorde en jouant : cordes neuves, chauffage, chute de la
mentonniere. Aujourd'hui, si son mi descend de quinze cents en cours de
seance, l'application lui reproche sa justesse pendant une demi-heure --
**elle l'accuse d'une faute qui appartient a l'instrument.** Elle doit dire
"ton mi a baisse, reaccorde", et proteger son propre verdict au passage.

**Fait (PR #34).** `StringDriftMonitor` surveille l'accord pendant la seance
et annonce "ton mi a baisse, reaccorde", sans chiffre : quinze cents ne
veulent rien dire a onze ans.

Le piege n'etait pas la mesure mais le **faux positif** -- un re joue au
quatrieme doigt sur la corde de sol tombe exactement sur la frequence du re a
vide. Le discriminant retenu : **une corde a vide ne peut pas etre jouee
faux**, donc elle donne toujours le meme ecart, alors qu'un doigt se pose un
peu differemment a chaque fois. Un verdict n'est rendu que sur une serie
nombreuse **et groupee**.

A verifie au passage : le flux lisse est remonte dans l'interface
`PitchSource`. L'accordeur testait le type reel de sa source et restait donc
muet des qu'on developpait avec une source factice.

### I2 - Intonation expressive

**Fait (PR #35).**

`LiveTuning` comparait a la note temperee. Or la gamme temperee est un
compromis de clavier : sur un instrument a hauteur libre, **deux references
sont enseignees et toutes deux sont justes**, et elles vont en sens inverse.
En jeu melodique on monte les sensibles et les tierces ; en double corde ou
sur un bourdon, on les baisse pour que l'accord sonne.

| Intervalle | Juste | Pythagoricienne |
|---|---|---|
| tierce mineure | +15,6 | -5,9 |
| tierce majeure | -13,7 | +7,8 |
| sixte majeure | -15,6 | +5,9 |
| septieme majeure | -11,7 | +9,8 |

**Correction de ce que ce plan affirmait.** Il disait que l'application
"marque systematiquement faux ce qu'il joue juste". C'etait exagere : avec
une tolerance de 35 cents, la couleur n'etait jamais fausse. Ce qu'elle
faisait, c'est **retirer des points** -- de 4 a 11 sur cent -- toujours sur
les memes degres.

L'argument reel est ailleurs, et il est plus fort : **les deux systemes
valides different de 21,5 cents sur la tierce majeure, alors que le bareme
distinguait a 10 cents.** Il notait donc plus finement que ne different deux
reponses correctes. `perfectCents` passe a 22.

**Le prix est assume :** une quinte ou une octave, qui ne varient que de deux
cents d'un systeme a l'autre, sont desormais jugees aussi largement. Les
corriger demande de connaitre le degre de la note dans la tonalite -- voir
I3.

**Defaut corrige en chemin.** Quand toutes les notes valaient cent, le bilan
designait quand meme une mesure a retravailler : la premiere, faute de mieux.
L'application demandait de retravailler ce qui etait deja juste.

### D1 - Bandeau de mesures

**Le second visuel principal.** Pas la partition gravee : un rectangle par
mesure, en ligne. Celui en cours est marque, les autres se colorent au fur et
a mesure qu'ils sont notes.

Pourquoi ca marche : pendant qu'il joue, **ses yeux sont sur le papier**. Il
ne reste que la vision peripherique, qui ne sait pas lire une tete de note
mais sait tres bien voir un gros bloc changer de couleur.

Et le meme widget sert deux fois : pendant le passage il montre ou on en est,
apres le passage **il est le bilan**. Un seul objet, deux moments.

**Fait (PR #36).** Une precision retenue a l'ecriture : l'information est
portee par la **hauteur de remplissage**, pas seulement par la couleur. La
teinte est ce qui se degrade en premier en vision peripherique, et elle ne dit
rien a un daltonien ; une hauteur se voit dans les deux cas. La case se
remplit donc litteralement -- des donnees qui montent, au sens propre -- et
une mesure faible est peu remplie, jamais rouge.

Le remplissage tient compte de la part reellement entendue : cent sur cent
etabli sur une note sur quatre ne s'affiche pas comme une mesure tenue de bout
en bout.

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

**Fait (PR #37).** Le ruban montre la bande qui vaut cent sur cent plutot
qu'une cible ponctuelle : sur un violon, juste est une bande, pas un point.
Un ecart enorme -- une erreur d'octave de YIN vaut 1200 cents -- sature au
bord au lieu de sortir du cadre.

Cote coeur, `TuningTrace` borne la fenetre **par la duree et non par le
nombre de points** : le micro perd des trames sous charge, et un tampon de
taille fixe ferait se dilater puis se contracter le trace sans que rien n'ait
change dans le jeu.

### D4 - Profils d'affichage

Trois profils, parce que le bon affichage depend de ce qu'il sait deja :

- **Decouverte** -- il apprend les notes, il lit son papier. Ecran sobre : le
  bandeau, le ruban, rien d'autre.
- **Par coeur** -- il connait le passage. **La partition en direct prend tout
  son sens ici**, curseur et coloration compris.
- **Pupitre** -- trois informations maximum, taille maximale, lisible d'un
  coup d'oeil a soixante-dix centimetres.

**Fait (PR #38).** Les profils defilent en boucle sur un seul bouton plutot
que dans un menu : un menu couterait deux appuis, et on change de profil
violon en main. Le reglage defilement / plusieurs lignes disparait hors du
profil "par coeur" -- choisir la mise en page d'une partition qu'on n'affiche
pas n'a pas de sens.

### D5 - Halo de fin de mesure

Une mesure passee proprement fait brievement respirer le bord de l'ecran.
Discret, non textuel, lisible du coin de l'oeil, et cale sur la **mesure** --
jamais sur la note, qui clignoterait en permanence.

C'est la seule recompense autorisee : de la lumiere, pas un badge.

**Fait (PR #38).** Elle s'allume vite et s'eteint doucement -- une lueur qui
monte progressivement distrait plus qu'elle ne se remarque -- et laisse
passer les appuis : une recompense ne doit jamais avaler un bouton.

Une mesure se felicite a partir de quatre-vingt-dix, et seulement si elle a
ete entendue pour moitie au moins. Exiger cent serait severe et n'arriverait
presque jamais ; feliciter une mesure a peine entendue reviendrait a feliciter
un silence.

---

## Jalon 2 - Les outils de tous les jours

**Jalon termine.** Sept lots courts, tous sur le code deja livre. Ils ne font
pas progresser la notation d'un pouce, et ils changent completement le fait de
s'en servir :
c'est le jalon ou l'application cesse d'etre une demo et devient un objet
qu'on pose sur son pupitre tous les soirs.

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| ~~L1~~ | ~~Demarrer en dix secondes~~ | | ★★★ | fait |
| ~~L2~~ | ~~Refonte de la navigation~~ | | ★★★ | fait |
| ~~O3~~ | ~~Ecran de controle du micro~~ | | ★★★ | fait |
| ~~O5~~ | ~~Mode libre, sans partition~~ | | ★★★ | fait |
| ~~O4~~ | ~~Quintes a vide dans l'accordeur~~ | | ★★ | fait |
| ~~O2~~ | ~~Metronome visuel a subdivisions et accents~~ | | ★★ | fait |
| ~~D7~~ | ~~Depart compte~~ | | ★★★ | fait |

### L1 - Demarrer en dix secondes

Nos propres notes d'analyse le donnent comme une attente forte, et ce n'etait
un critere nulle part. Concretement : aucun ecran d'accueil, aucun menu,
aucune selection a refaire. **L'application s'ouvre sur le travail en cours**
-- le devoir de la semaine, ou ce qu'il faisait hier, avec le tempo atteint --
et un seul appui lance la prise.

Dix secondes, c'est la duree au-dela de laquelle un enfant de onze ans repose
le violon.

**Fait a moitie (PR #39), et il faut le dire.** L'application n'a plus
d'ecran d'accueil et s'ouvre sur le travail, un appui lance la prise. Mais
"ce qu'il faisait hier, avec le tempo atteint" suppose de se souvenir de la
veille : **cette moitie-la attend la persistance (H1)**, et le passage de
demonstration en tient lieu jusque-la.

### L2 - Refonte de la navigation

Voir `docs/navigation.md`. A faire **ici et pas plus tard** : c'est le jalon ou
l'application passe d'un ecran plus un accordeur a une dizaine de
fonctionnalites, et une navigation rattrapee apres coup ne se rattrape jamais.

**Fait (PR #39), avec deux ecarts assumes par rapport au document.**

*Progres* n'est pas une destination : il n'a rien a montrer avant la
persistance (H1), et **un onglet vide est pire que pas d'onglet**. Il reste
donc deux destinations, Jouer et Repertoire, plus le tiroir d'outils.

Le rappel "accorder d'abord ?" n'est pas fait. Accorder garde en revanche son
raccourci depuis la seance, en plus du tiroir : c'est la premiere chose de
chaque seance, elle merite un appui et pas deux.

### O3 - Ecran de controle du micro

"Est-ce qu'elle m'entend bien ?" C'est le probleme numero un de toutes les
applications d'ecoute, et le premier soupcon de l'utilisateur quand un score
le surprend. L'ecran montre le niveau, la source retenue (`UNPROCESSED` ou le
repli), la hauteur detectee en direct et les trames perdues.

Double usage : il rassure l'eleve, et il sert de banc de diagnostic quand
quelque chose cloche sur un appareil.

**Fait (PR #39).** `sourceLabel` et `droppedFrames` sont remontes dans
l'interface `PitchSource` plutot que lus sur le type concret : c'est la meme
correction que pour `smoothedPitches` au lot I1, et elle evite qu'un ecran de
diagnostic devine avec quoi il parle.

### O5 - Mode libre, sans partition

Elle ecoute et montre la justesse, sans rien attendre de precis : pas de
partition, pas de score, pas de jugement. Pour s'echauffer, pour chercher une
note, pour jouer d'oreille.

C'est aussi, et surtout, la facon dont il apprend a lui faire confiance avant
de la laisser le noter.

**Fait (PR #39).** L'ecart y est mesure a la note temperee la plus proche,
faute de tonalite -- acceptable ici precisement parce qu'on ne note pas : on
montre ce qu'on entend, on ne dit pas que c'est faux.

### O4 - Quintes a vide dans l'accordeur

Un violoniste accorde **par quintes en double corde**, pas corde par corde :
on tire deux cordes voisines ensemble et on ecoute les battements. Notre
accordeur fait quatre mesures independantes -- ce n'est pas la technique
reelle, et c'est celle qu'on lui enseigne.

**Fait (PR #39).** Le detecteur etant monophonique, il n'entend pas la double
corde : on mesure les cordes l'une apres l'autre et on rend l'intervalle.
Meme question, moyens differents.

Point qui decide du lot : **la reference est la quinte JUSTE, pas la
temperee.** Un violon s'accorde sur le rapport 3:2, soit 701,955 cents ; le
piano rabote ses quintes a 700 pour que les douze tonalites tiennent. Juger
contre 700 declarerait fausses, de deux cents et trois fois de suite, des
cordes accordees exactement comme il faut.

### O2 - Metronome visuel a subdivisions et accents

Le metronome actuel bat la noire, point. En 4e annee on travaille en croches,
en triolets, en doubles, et **on accentue le premier temps**. Un metronome qui
ne sait pas subdiviser ne sert plus a rien des que le rythme se complique.

Visuel uniquement ici : la version sonore est J3.

**Fait (PR #39).** Trois intensites pour trois roles -- le premier temps
porte la mesure, les autres temps la scandent, les subdivisions remplissent.
Le reglage se change d'un appui **sur la barre elle-meme** : on change de
subdivision en plein travail, et aller la chercher dans un menu couterait le
fil.

### D7 - Depart compte

Bete, et bloquant : on ne peut pas commencer une prise notee sans savoir quand
partir. Une mesure comptee visuellement, au tempo choisi. La version sentie au
vibreur viendra avec D6.

**Fait (PR #39).** On compte **en montant**, comme un chef : "un, deux, trois,
quatre" est ce qu'il entend en cours et en orchestre. Le temps du passage est
obtenu par soustraction du temps absolu, jamais remis a zero : rien n'est
cumule, donc rien ne derive.

---

## Jalon 3 - Les gammes et les exercices

**Jalon termine (PR #40).** Un catalogue de dix-neuf exercices repartis sur
six paliers, generes et non saisis, et une progression qui designe la
prochaine tache. Voir `docs/exercices.md` pour le detail de ce qui est fidele
aux methodes et de ce qui ne l'est pas.

**Le meilleur rapport effet/cout de tout le plan.** Un eleve de 4e annee passe
une part considerable de son temps sur des gammes, des arpeges et des etudes.
Or c'est le cas d'usage ideal pour cette application :

- **aucune saisie, aucun import** : une gamme se genere a partir d'une
  tonalite, d'une position et d'un nombre d'octaves ;
- **la justesse est exactement ce qu'on y travaille**, c'est leur raison
  d'etre ;
- le suiveur y a la tache la plus facile qui soit, ce qui en fait aussi un
  excellent banc d'essai ;
- ca rend l'application utile **tous les jours, sans rien preparer**.

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| ~~E1~~ | ~~Catalogue d'exercices issus des methodes~~ | | ★★★ | fait |
| ~~E2~~ | ~~Progression de difficulte et score~~ | | ★★★ | fait |

### E1 - Catalogue d'exercices issus des methodes

**Pas d'exercices inventes.** Le catalogue s'appuie sur les methodes reelles,
celles que son professeur lui donne deja :

| Methode | Ce qu'elle apporte |
|---|---|
| Sevcik op. 1 | Motifs de doigts, combinatoire systematique |
| Schradieck, *School of Violin Technics* | Deliement, changements de corde |
| Hrimaly, *Scale Studies* | Gammes et arpeges par tonalite |
| Wohlfahrt op. 45 | Etudes de base |
| Kayser op. 20, Mazas op. 36 | Etudes melodiques |

**Toutes sont dans le domaine public** (fin du XIXe, debut du XXe), donc
versionnables sans probleme -- contrairement aux methodes modernes.

> A ne pas embarquer : le *Contemporary Violin Technique* de Galamian, encore
> sous droits. C'est le systeme de gammes le plus connu, et c'est
> precisement celui qu'il ne faut pas copier.

Point technique qui rend ce lot abordable : ces exercices sont **systematiques
par construction**. Sevcik est de la combinatoire de doigts, Hrimaly est une
gamme declinee par tonalite. La plupart se **generent** a partir de quelques
parametres au lieu d'etre saisis un a un.

**Fait (PR #40).** Dix-neuf exercices, trois formules de motifs de doigts
croisees avec quatre ecartements de la premiere position, et des gammes et
arpeges declines par tonalite. Deux ecarts a assumer :

*Les etudes melodiques n'y sont pas.* Wohlfahrt op. 45, Kayser op. 20 et Mazas
op. 36 sont des **morceaux ecrits** : ils ne se generent pas a partir de
parametres, il faudrait les transcrire. Transcrire de memoire une etude qu'on
attribue ensuite a son auteur serait pire que de ne pas la proposer -- elles
arriveront par l'import (H6), qui lira le vrai texte.

*Rien ne depasse la premiere position.* Une gamme de trois octaves demanderait
de demancher jusqu'a la septieme position, ce qui n'est pas le programme d'une
quatrieme annee. Le catalogue se tient sous le si de la corde de mi, et un test
le verifie exercice par exercice.

### E2 - Progression de difficulte et score

**La progression existe deja, on ne l'invente pas.** Sevcik, Schradieck et
Hrimaly sont ordonnes par difficulte croissante depuis 1880, et c'est cet
ordre-la qu'on suit : il a fait ses preuves sur quatre generations de
violonistes, et il correspond a ce que son professeur lui fera travailler.

Un palier s'ouvre quand le precedent est propre au tempo vise. Le score par
exercice, le tempo atteint et les paliers ouverts sont **des donnees qui
montent** -- pas des badges, pas de mascotte, pas de confettis. La regle
produit tient : montrer une progression n'est pas de la gamification, offrir
une recompense en est.

**Fait (PR #40).** Trois decisions ont demande d'etre tranchees en cours de
route :

*Le score et le tempo ne se combinent pas.* Retenir separement le meilleur
score et le meilleur tempo laisserait un 95 obtenu a 50 et un tempo de 80 tenu
a 40 s'additionner en un exercice declare acquis a 80 -- qui n'a jamais ete
joue proprement a 80. C'est le **meilleur tempo tenu proprement** qui est
retenu, pas les deux records separement.

*Une prise a peine entendue ne rend rien acquis.* Le score ne compte que les
notes entendues, parce que compter un silence pour zero punirait un archet
rate. Mais quatre notes justes sur vingt-neuf donneraient alors cent, et
l'exercice ne reviendrait plus jamais. Il faut avoir entendu les trois quarts
de l'exercice pour qu'une prise compte.

*Un passage interrompu ne compte pas du tout.* Le score ne remonte a la
progression que si le passage a ete joue **jusqu'au bout** : sans ca, on
declarerait un exercice acquis en l'abandonnant apres trois notes justes.

Et un choix de produit, qui a valu une ADR : **la progression guide, elle ne
verrouille pas** (ADR-011).

---

## Jalon 4 - Le son

**Jalon termine (PR #41).** L'application emet enfin, et l'arbitrage du moteur
audio est tranche : `flutter_soloud`, en 4.x, avec ce qu'on s'autorise a en
utiliser ecrit noir sur blanc (ADR-012).

**Le jalon qui oblige a trancher le moteur audio**, bien plus tot que dans
l'ancien plan. Ce qu'on achete avec cette dependance :

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| ~~J1~~ | ~~Moteur audio pre-planifie~~ | | ★★ | fait |
| ~~O1~~ | ~~Bourdon sur la tonique~~ | | ★★★ | fait |
| ~~J3~~ | ~~Metronome sonore~~ | | ★★ | fait |

### J1 - Moteur audio pre-planifie

**Fait (PR #41), avec deux choses apprises en chemin.**

*La version comptait autant que le paquet.* `flutter_soloud` 5.x compile son
C++ sur la machine de developpement : `flutter test` reclame alors clang et
echoue sans lui, ici comme sur la CI. La 4.x livre ses binaires deja compiles,
et expose les memes appels. `make check` doit marcher sans chaine de
compilation C.

*Construire le moteur chargeait la bibliotheque native.* Assez pour faire
echouer tout test de widget montant l'application -- et, cote produit, pour
reveiller le haut-parleur au lancement d'une seance entierement silencieuse.
Le moteur ne resout plus rien tant qu'on ne lui a pas demande de son, et un
test le verifie.

### O1 - Bourdon sur la tonique

**L'exercice de justesse le plus efficace qui existe pour un instrument a
cordes**, et celui que nos propres notes d'analyse citaient en premier parmi
les fonctions "appreciees et rarement anticipees" -- avant de disparaitre du
plan.

Jouer contre un bourdon fait entendre les battements. L'enfant corrige **tout
seul**, a l'oreille, sans qu'aucune application ne lui dise qu'il est faux.
C'est l'exact inverse d'un score, et c'est pour ca que ca marche.

**Mode d'entrainement, pas de notation** (ADR-008) : l'application emet, donc
elle n'ecoute pas. On ne note pas, on s'entraine. La contradiction du jalon 11
ne se pose pas ici.

Une note tenue est par ailleurs la sortie audio la plus simple imaginable :
c'est le meilleur premier usage possible du moteur, et une facon peu risquee
de le mettre a l'epreuve avant l'accompagnement.

**Fait (PR #41).** Les douze notes, la quinte **pure** en option, le volume, et
la frequence prise sur le diapason mesure. Changer de note ne coupe pas le son :
on cherche sa tonalite en glissant, pas en rallumant.

Propriete heureuse, decouverte en choisissant l'octave : le bourdon de sol
sonne **exactement la corde de sol a vide**. L'enfant peut donc verifier le
bourdon contre son propre instrument -- et une corde a vide ne peut pas etre
jouee faux.

### J3 - Metronome sonore

Reserve au mode accompagnement et au mode bourdon, jamais pendant la notation
(ADR-008). Complete O2, qui en est la version visuelle.

**Fait (PR #41), dans le tiroir d'outils.** Tempo, subdivision, temps par
mesure, et les clics synthetises plutot qu'enregistres : trois fichiers de
moins a versionner, et surtout un accent obtenu **en montant la hauteur, pas le
volume** -- un accent plus fort fatigue, un accent plus aigu s'entend aussi bien
et se laisse oublier.

Le clic n'est jamais declenche par l'interface : a chaque image, l'ecran demande
au planificateur ce qui reste a poser dans la seconde et demie qui vient. Si
l'interface bloque un quart de seconde, les clics deja poses sonnent quand meme,
a l'heure. L'interdiction du `Timer` visait le declenchement, pas le
remplissage -- voir ADR-012.

---

## Jalon 5 - La preuve

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

## Jalon 6 - Le suivi

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

## Jalon 7 - La note

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

## Jalon 8 - Quoi rejouer

**C'est ici que la boucle se ferme.** Jusqu'au jalon 7 l'application constate ;
a partir d'ici elle dirige le travail. Et c'est ici que survit la reponse a la
lassitude : ce n'est plus l'enfant qui decide de rejouer la meme mesure pour la
dixieme fois, c'est la mesure qui designe la mesure.

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| R1 | Selection des mesures faibles | **Must** | ★★★ | 1 |
| R2 | Boucle sur la selection | **Must** | ★★★ | 2 |
| R3 | Montee de tempo automatique | **Must** | ★★★ | 2 |
| R5 | Selection manuelle des mesures | | ★★★ | 1 |
| R4 | Fin sur une reussite | | ★★★ | 1 |
| C2 | Point de rupture | | ★★★ | 2 |

**R5 - Selection manuelle.** R1 designe les mesures faibles automatiquement,
mais il doit pouvoir repondre "non, moi je veux celles-la". **L'application
propose, il dispose** -- sinon elle devient autoritaire, ce qui est exactement
ce qu'on cherche a eviter a onze ans. C'est aussi ce qui permet de travailler
un passage que la mesure n'a pas encore vu.

**C2 - Point de rupture.** L'application monte le tempo jusqu'a ce que ca
casse, note le chiffre, et redescend. C'est la technique de travail classique,
automatisee -- et c'est une donnee qui monte de semaine en semaine, ce que le
projet cherche depuis le debut.

---

## Jalon 9 - La memoire

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| H1 | Persistance passages et seances | **Must** | ★★ | 2 |
| H3 | Erreurs systematiques par doigt | | ★★★ | 3 |
| H4 | Courbes de progression | | ★★★ | 2 |
| H5 | Journal de seance | | ★★ | 1 |
| H2 | Heatmap cumulee sur la partition | | ★★ | 3 |
| M2 | Avant / apres audible | | ★★★ | 2 |
| H6 | Import d'un morceau entier | | ★★ | 3 |
| I3 | Justesse par degre dans la tonalite | | ★★ | 2 |

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

**I3 - Justesse par degre.** Le complement de I2. Une quinte et une tierce
n'ont pas la meme marge : la premiere ne varie que de deux cents d'un systeme
d'intonation a l'autre, la seconde de vingt-et-un. Les juger avec la meme
tolerance est le prix qu'on paie aujourd'hui.

Y remedier demande le **degre de la note dans la tonalite**, donc la
tonalite -- que ni `Passage` ni `ScoreNote` ne portent. Ce lot est range ici
parce que **le MusicXML la transporte** : l'import la fournit gratuitement.
Il peut aussi remonter plus tot si l'ecran de saisie se met a demander
l'armure.

**H6 - Import.** Suivre suppose la partition en machine. La saisie a la main
tient pour un passage, pas pour un morceau. L'OMR (reconnaissance optique)
reste **hors de l'application** : une lecture a 95 % n'est pas 95 % utile ici,
elle est nuisible, car l'application reprocherait a l'enfant une faute de
rythme qu'elle a elle-meme inventee.

---

## Jalon 10 - Le professeur

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

## Jalon 11 - L'accompagnement

| ID | Lot | Must | ROI | Est. |
|----|-----|------|-----|------|
| J4 | Accompagnement deduit du passage | | ★★★ | 3 |
| J2 | Calibration de latence | | ★★ | 2 |
| J5 | Accompagnement qui suit | | ★ | 5 |
| D6 | Retour haptique hors ecoute | | ★★ | 1 |

Le moteur audio (J1) et le metronome sonore (J3) ont ete avances au jalon 4,
tires par le bourdon.

**D6 - Retour haptique.** Tentant, mais un telephone qui vibre sur un pupitre
en bois **est une source sonore** qui entre dans le micro. Le vibreur est donc
interdit pendant l'ecoute, et reserve aux moments ou l'application n'ecoute
pas : un depart compte qu'on sent, la relance d'une boucle. Il est range au dernier jalon
pour cette raison, pas par manque d'interet.

**La contradiction a resoudre avant J5.** L'ADR-008 interdit d'ecouter pendant
que l'application joue. Mais un accompagnement qui *suit* -- le seul qui
vaille musicalement -- doit precisement ecouter. Casque, annulation d'echo, ou
renoncement : rien n'est choisi, d'ou le ★.

---

## Le palmares

Les meilleurs rapports effet/cout, tous jalons confondus. A piocher dedans
quand une soiree se libere.

**Une soiree chacun.**

| Lot | Jalon | Pourquoi |
|-----|-------|----------|
| O1 | 4 | Le bourdon : l'exercice de justesse le plus efficace qui existe |
| L1 | 2 | Dix secondes, au-dela desquelles un enfant repose le violon |
| O3 | 2 | Repond au premier soupcon : "est-ce qu'elle m'entend bien ?" |
| O5 | 2 | Le mode libre : c'est la qu'il apprend a lui faire confiance |
| D7 | 2 | Le depart compte : bete, et bloquant sans lui |
| R1 | 8 | Une soiree, et l'application se met a diriger le travail |
| R5 | 8 | Et il garde le dernier mot : elle propose, il dispose |
| B1 | 7 | Le meilleur indicateur de difficulte, presque gratuit |
| S4 | 6 | Le suivi devient enfin visible |
| S5 | 6 | Empeche de noter n'importe quoi en silence |
| P3 | 5 | Un chiffre qui valide ou annule quarante soirees |
| D5 | 1 | La seule recompense autorisee : de la lumiere |

**Deux soirees chacun.**

| Lot | Jalon | Pourquoi |
|-----|-------|----------|
| I1 | 1 | Cesse d'accuser l'enfant du desaccord de son violon |
| I2 | 1 | Cesse de marquer faux ce qu'il joue juste |
| D1 | 1 | Un seul widget : suivi pendant, bilan apres |
| D2 | 1 | L'ecart se voit sans lire, du coin de l'oeil |
| L2 | 2 | Une navigation rattrapee apres coup ne se rattrape jamais |
| C1 | 7 | Dit ce qu'aucun score par note ne dit |
| C2 | 8 | Une donnee qui monte, semaine apres semaine |

**Et le bloc a trois soirees qui rend l'application quotidienne :** E1 et E2,
les gammes et les exercices. Rien a preparer, rien a saisir, et c'est ce qu'il
travaille tous les soirs de toute facon.

---

## Dependances a arbitrer

Aucune n'est ajoutee sans accord explicite.

| Paquet | Pour | Jalon |
|--------|------|-------|
| ~~Bravura (asset, SIL OFL)~~ | ~~le rendu de partition~~ | **ajoutee** |
| ~~`record`~~ | ~~la capture micro~~ | **ajoutee** |
| stockage local | H1, la persistance | 9 |
| moteur audio bas niveau | O1 le bourdon, puis l'accompagnement | **4** |

**Premier arbitrage au jalon 4.** Les cinq premiers jalons sont du calcul
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
| A4 - Calibration de latence | Deplace en jalon 11 (J2), plus bloquant pour le rythme |
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
