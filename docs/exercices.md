# Les gammes et les exercices

Ce document dit d'ou viennent les dix-neuf exercices du catalogue, **ce qui est
fidele aux methodes et ce qui ne l'est pas**, et ou sont les limites qu'on
s'est donnees.

Code : `lib/core/exercises/`, `lib/core/music/scale_pattern.dart`,
`lib/core/music/finger_pattern.dart`.

---

## Pourquoi ce jalon d'abord

Un eleve de 4e annee passe une part considerable de son temps sur des gammes,
des arpeges et des etudes. C'est le cas d'usage ideal pour cette application :

- **aucune saisie, aucun import** : un exercice se genere a partir de trois
  parametres ;
- **la justesse est exactement ce qu'on y travaille**, c'est leur raison
  d'etre ;
- le suiveur y aura la tache la plus facile qui soit, ce qui en fera aussi un
  banc d'essai ;
- ca rend l'application utile **tous les jours, sans rien preparer**.

---

## Ce qui est repris des methodes, et ce qui ne l'est pas

| | |
|---|---|
| **Repris** | Le **principe de construction** : la combinatoire de doigts de Sevcik, la gamme declinee par tonalite de Hrimaly. |
| **Repris** | L'**ordre de difficulte** : les doigts avant les gammes, une octave avant deux, le majeur avant le mineur. Cet ordre a fait ses preuves depuis les annees 1880, et c'est celui que le professeur suivra de son cote. |
| **Pas repris** | Le **texte d'un numero precis**. L'application genere, elle ne recopie pas. Un exercice s'appelle "les doigts en ligne, 3-4 serres", pas "Sevcik op. 1 n. 14". |

C'est une distinction a garder honnete dans l'interface : chaque exercice
affiche sa methode pour que l'enfant retrouve la famille dont il s'agit, sans
pretendre etre la page du livre.

### Le domaine public, et sa limite

Sevcik (op. 1), Schradieck (*School of Violin Technics*) et Hrimaly (*Scale
Studies*) datent de la fin du XIXe et du debut du XXe siecle, et leurs auteurs
sont morts depuis plus d'un siecle. Rien n'empeche de s'en inspirer ni de les
citer.

> **A ne pas embarquer :** le *Contemporary Violin Technique* de Galamian,
> encore sous droits. C'est le systeme de gammes le plus connu, et c'est
> precisement celui qu'il ne faut pas copier.

### Les etudes melodiques n'y sont pas

Wohlfahrt op. 45, Kayser op. 20 et Mazas op. 36 sont dans le domaine public
eux aussi, et ils sont absents. Ce sont des **morceaux ecrits** : ils ne se
generent pas a partir de parametres, il faudrait les transcrire.

Transcrire de memoire une etude qu'on attribue ensuite a son auteur serait
pire que de ne pas la proposer. Elles arriveront par l'import (lot H6), qui
lira le vrai texte.

---

## Comment un exercice se genere

Deux familles, deux mecaniques.

### Les motifs de doigts

Un violon n'a pas de touches : la main gauche ne connait pas des notes, elle
connait des **ecarts entre les doigts**. La ou tombe le demi-ton dit tout le
reste, et c'est ce que Sevcik fait travailler.

Le catalogue croise donc deux variables :

- **quatre ecartements** de la premiere position, nommes par la paire de
  doigts qui se serre : 2-3, 1-2, 3-4, 0-1 ;
- **trois motifs** : les doigts en ligne (`0 1 2 3 4 3 2 1`), la verification
  (`1 0 2 0 3 0 4 0`), les tierces brisees (`0 2 1 3 2 4 3 1`).

Le motif se promene ensuite sur les quatre cordes sans rien recalculer. Douze
combinaisons possibles, dont sept retenues : la combinatoire est un moyen, pas
un but.

**Le motif de verification merite une mention a part.** Chaque doigt y est
suivi de la corde a vide. C'est un bon exercice de violon -- l'oreille a une
reference gratuite toutes les deux notes -- et c'est aussi **le seul exercice
ou l'application ne peut pas se tromper** : une corde a vide ne peut pas etre
jouee faux. C'est le meme discriminant que celui du `StringDriftMonitor`.

### Les gammes et les arpeges

Une formule d'intervalles, une tonique, un nombre d'octaves. Le sommet n'est
joue qu'une fois : une gamme qui repeterait sa tonique au sommet donnerait deux
notes de meme hauteur a la suite, et le detecteur d'attaques n'en verrait
qu'une.

**Le mineur melodique descend par le mineur naturel.** Ce n'est pas une
subtilite de theoricien : c'est ainsi qu'il se joue et qu'il se travaille.
Faire redescendre la formule montante afficherait deux notes que le professeur
n'a pas demandees, et l'enfant -- qui joue ce qu'on lui a appris -- se verrait
compter faux ce qu'il joue juste.

---

## Les limites qu'on s'est donnees

**Rien au-dela de la premiere position.** La note la plus aigue du catalogue est
le si de la corde de mi (MIDI 83), au quatrieme doigt. Une gamme de trois
octaves demanderait de demancher jusqu'a la septieme position, ce qui n'est pas
le programme d'une quatrieme annee : l'ajouter aurait fait un catalogue plus
impressionnant et moins utilisable. Un test le verifie exercice par exercice.

**Jamais deux fois la meme hauteur a la suite.** YIN ne voit pas une note
rejouee a la meme hauteur, et le detecteur d'attaques n'a pas encore vu de
vrai signal de violon. Le piege est reel : le quatrieme doigt d'une corde sonne
exactement la corde a vide suivante, donc un motif mal ordonne produit un
unisson au changement de corde. Un test verifie les dix-neuf exercices.

**Tout se grave en figures reelles.** Le modele ne stocke qu'une duree en
ticks, et le graveur en deduit la tete de note : une duree qui n'est la duree
d'aucune figure se dessinerait quand meme, en affichant n'importe quoi. Les
exercices sont donc ecrits en croches, **la derniere note completant la
mesure**, et la duree obtenue doit tomber sur une figure existante -- sinon la
construction echoue au lieu d'arrondir en silence.

---

## Les paliers

| # | Palier | Ce qu'on y travaille |
|---|--------|----------------------|
| 1 | La main se pose | Un seul ecartement, sur les quatre cordes |
| 2 | Les autres ecartements | Le demi-ton change de place |
| 3 | Une octave | La premiere gamme, d'une corde a l'autre |
| 4 | Deux octaves | La gamme traverse les quatre cordes et revient |
| 5 | Les arpeges | Des sauts, sans gamme pour rattraper l'oreille |
| 6 | Le mineur | Harmonique et melodique |

**Un palier s'ouvre quand le precedent est acquis**, et **il reste jouable
avant** : la progression guide, elle ne verrouille pas (ADR-011).

### Ce qui compte comme acquis

Trois conditions, et chacune vient d'un piege qu'on a failli laisser passer.

1. **Un score d'au moins 90**, comme le halo de fin de mesure. Cent
   demanderait chaque note dans la bande parfaite et n'arriverait presque
   jamais.
2. **Au tempo vise, dans la meme prise.** Retenir separement le meilleur score
   et le meilleur tempo laisserait un 95 obtenu a 50 et un tempo de 80 tenu a
   40 s'additionner en un exercice declare acquis a 80 -- qui n'a jamais ete
   joue proprement a 80.
3. **Les trois quarts de l'exercice entendus.** Le score ne compte que les
   notes entendues, parce que compter un silence pour zero punirait un archet
   rate. Mais quatre notes justes sur vingt-neuf donneraient alors cent, et
   l'exercice ne reviendrait plus jamais.

Et une quatrieme, qui vit dans l'ecran de seance : **le passage doit avoir ete
joue jusqu'au bout.** Un arret manuel ne remonte rien, sans quoi on declarerait
un exercice acquis en l'abandonnant apres trois notes justes.

**Rien n'est encore persiste** (lot H1) : la progression vit le temps d'une
seance. Mieux vaut un compteur honnetement volatile qu'un historique sauvegarde
a moitie.
