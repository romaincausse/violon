# Journal de decisions produit

Trace des echanges qui ont oriente le projet. Utile pour ne pas rejouer les
memes debats, et pour Claude Code qui reprend le contexte a froid.

## Cadrage initial

Idee de depart : defilement de partition, ecoute du jeu, retour visuel sur la
justesse et le rythme, scores de precision.

Constats techniques poses d'emblee :
- le violon est monophonique, donc la detection de hauteur est le cas le plus
  favorable ;
- le vibrato fait varier la hauteur de +/- 20 a 50 cents volontairement ;
- les attaques d'archet sont floues, la detection d'onset est bien moins nette
  qu'avec un instrument percussif ;
- il faut juger la justesse relativement a l'accord reel de l'instrument.

## Le profil de l'utilisateur

11 ans, 4e annee de violon. 3e position, tonalites jusqu'a 3-4 alterations,
doubles cordes occasionnelles, vibrato qui demarre. Le rendu de partition doit
donc gerer les lignes supplementaires, les doigtes et les coups d'archet.

## Premier retournement : le boucleur a variations

> **Depasse deux fois depuis** (ADR-006 puis ADR-009). Conserve parce que le
> constat tient toujours -- c'est la conclusion qui a change.

Question posee : qu'est-ce qui le fatigue le plus dans son travail quotidien ?

Reponse : **recommencer dix fois la meme mesure**.

Ce n'est donc pas un probleme de justesse mais de **monotonie**. Consequence :
le coeur de l'application devient le generateur de variations, pas le moteur
de notation. L'application dit "voila ta prochaine tache" au lieu de "voila
tes erreurs". Voir ADR-004.

## Deuxieme retournement : la partition vivante

Apres six mois et un prototype jouable, l'utilisateur tranche autrement : ce
qu'il veut est un suivi interactif sur une partition qui vit, avec retour
visuel, notation de la justesse et du rythme, et un accompagnement.

Le boucleur a cartes et l'auto-evaluation disparaissent. Le constat de
monotonie reste vrai, mais il est servi autrement : la boucle survit sans les
cartes, et c'est desormais la mesure qui remplace le bouton sur lequel on
appuyait soi-meme. Voir ADR-006.
## Troisieme retournement : c'est l'application qui suit

Le plus important des trois, et celui qui a le plus coute au plan.

Constat de l'utilisateur : **l'enfant lit sa partition papier**, posee sur le
pupitre. Il ne lit pas un telephone de six pouces pose a cote. La partition
affichee etait donc une surface de lecture que personne ne lisait. Et un
curseur qui avance sur l'horloge impose un tempo a quelqu'un qui est
precisement en train d'apprendre le passage.

Le sens s'inverse : l'eleve joue a son tempo, l'application le suit, et de ce
suivi elle tire la justesse, le rythme, et **les mesures a rejouer**. Voir
ADR-009.

Le paradoxe immediat -- un suiveur qui s'adapte ne peut plus juger le retard
-- se resout par un seul alignement lu deux fois : un suiveur elastique qui ne
juge rien, un juge strict qui mesure l'ecart a la grille au tempo reellement
tenu. Voir ADR-010.

Deux consequences de calendrier : le lot le plus risque du projet passe en
premier, precede d'un jalon de preuve ; et la calibration de latence cesse
d'etre bloquante, ce qui libere les quatre premiers jalons de toute
dependance nouvelle.
## Ce que cherchent les musiciens (analyse des applications existantes)

- Etre cru par la machine : le faux negatif est le grief numero un. Mieux vaut
  un detecteur indulgent et fiable qu'un detecteur exigeant et bruyant.
- Savoir quoi travailler, pas seulement ce qui etait faux.
- Ralentir et boucler : la fonction la plus utilisee, loin devant.
- S'entendre soi-meme : le replay provoque souvent plus de progres qu'un score.
- Que ca demarre en 10 secondes.

Repoussoirs : la gamification infantilisante, le jugement permanent, et la
reduction de la musique a des notes justes en rythme.

Apprecie et rarement anticipe : le drone sur la tonique, un accompagnement
meme simple, l'export vers le professeur.

## Choix de plateforme

Telephone Android d'abord, iOS ensuite. Le web est ecarte pour l'audio, pas
pour l'interface. Voir ADR-001.

## Les gammes, et la tentation du verrou

Le jalon 3 a rendu l'application utile un soir ou l'on n'a rien prepare : un
exercice se genere, il ne s'importe pas. Trois points ont demande d'etre
tranches, et ils se ressemblent tous les trois.

**Verrouiller les paliers non ouverts, ou pas.** C'est ce que font la plupart
des applications de musique, et ca marche : voir le palier suivant grise donne
envie de finir celui-ci. Decision inverse quand meme (ADR-011) : ce n'est pas
l'application qui decide du programme, c'est le professeur. Si le cours de mardi
a donne la gamme de si bemol, la refuser serait la meilleure facon de faire
desinstaller l'application.

**Deux records ne font pas une reussite.** Retenir separement le meilleur score
et le meilleur tempo laissait un 95 obtenu a 50 et un 80 tenu salement
s'additionner en un exercice declare acquis a 80 -- jamais joue proprement a 80.
C'est le meilleur tempo **tenu proprement** qui est retenu.

**Un score calcule sur quatre notes n'en est pas un.** La regle "on ne compte
pas ce qu'on n'a pas entendu" est bonne -- elle empeche de punir un archet rate
-- mais elle rendait cent sur quatre notes de vingt-neuf, et l'exercice ne
revenait plus jamais. D'ou une part minimale entendue, et un score qui ne remonte
que si le passage a ete joue jusqu'au bout.

Le point commun des trois : **une mesure incomplete n'est pas une mesure**, et
une regle protectrice appliquee sans garde-fou devient une faille. Detail dans
`docs/exercices.md`.

## Le son, et une interdiction mal comprise

L'application emet enfin. La dependance audio etait annoncee comme le morceau
delicat du jalon 4 ; ce n'est pas la qu'etaient les surprises.

**La version du paquet comptait autant que le paquet.** `flutter_soloud` 5.x
compile son C++ sur la machine de developpement : `flutter test` reclame alors
clang et echoue sans lui, ici comme sur la CI. La 4.x livre ses binaires deja
compiles et expose exactement les memes appels. Une dependance ne se juge pas
seulement sur son API.

**Construire le moteur chargeait deja la bibliotheque native**, avant meme
qu'on lui demande le moindre son. Assez pour faire echouer tout test de widget
montant l'application -- et surtout, cote produit, pour reveiller le
haut-parleur au lancement d'une seance qu'on ouvre pour travailler en silence.
J'avais ecrit dans un commentaire que "le construire n'ouvre rien" avant que ce
soit vrai ; c'est le test qui l'a dit.

**Et une interdiction du projet s'est revelee plus etroite qu'elle n'en avait
l'air.** "Jamais de `Timer` Dart pour le metronome" visait le **declenchement**,
pas la planification. Un minuteur qui se contente de remplir la file a l'avance
reste permis : s'il se reveille cinquante millisecondes trop tard, il pose les
memes clics aux memes instants, parce que chaque instant est calcule depuis le
depart et fige dans le moteur des la planification. La derive devient alors
structurellement impossible, et non plus simplement improbable. Voir ADR-012.

Un dernier point, moins technique : le bourdon est le seul endroit de
l'application ou elle **ne juge rien**. Elle tient une note, l'enfant joue
contre, et les battements lui disent tout. C'est l'exact inverse d'un score --
et c'est cense etre l'exercice de justesse le plus efficace qui existe pour un
instrument a cordes.

## Consolider plutot qu'ajouter

Quatre jalons livres d'affilee, et la question posee n'etait pas "quoi de
plus ?" mais "qu'est-ce qui ne tient pas ensemble ?". Trois choses, toutes nees
de ce qui venait d'etre livre.

**Le jalon 3 avait livre une progression qui ne progressait pas.** Dix-neuf
exercices, six paliers, des donnees qui montent -- et tout repartait de zero a
chaque lancement, puisque la persistance etait au jalon 9. Une progression qui
s'efface n'est pas une progression, c'est une demonstration. H1 a ete remonte,
et il achevait au passage "demarrer en dix secondes", laisse a moitie depuis le
jalon 2.

**Le jalon 4 avait livre un bourdon que les gammes ne pouvaient pas
utiliser.** Le catalogue connaissait la tonique de chaque gamme, le bourdon
connaissait une note, et les deux ne se parlaient pas -- il fallait aller
choisir Sol a la main dans les outils. Le lien manquant a fait apparaitre une
distinction qui manquait aussi : **travailler** et **passer** (ADR-013). La
contrainte de l'ADR-008 -- emettre ou ecouter, jamais les deux -- s'est
revelee etre la distinction d'un cours de violon. Quand une contrainte
technique tombe juste, il vaut mieux s'en servir que la contourner.

**Et le meilleur tempo tenu ne servait a rien.** Il etait mesure, range,
affiche, et l'application n'en faisait rien. Apres une gamme propre a 60, elle
propose maintenant 66. C'est la seule facon dont une donnee qui monte devient
une invitation -- et la seule recompense que le projet s'autorise.

Le point commun des trois : **rien de neuf, que des liens**. Cinq soirees pour
qu'une pile de fonctionnalites devienne une routine du soir.

## Tensions ouvertes, a trancher un jour

Notees ici plutot que tranchees dans l'urgence, parce que chacune oppose deux
choses vraies.

**S'entendre soi-meme contre ne rien conserver.** L'analyse des applications
existantes, plus haut, dit que le replay provoque souvent plus de progres
qu'un score. `docs/professeur.md` dit qu'aucun enregistrement audio n'est
conserve, et pour de bonnes raisons. Sortie possible : un "avant / apres"
strictement local et ephemere, efface en quittant, jamais exportable et
jamais accessible au professeur. Non tranche.

**Doigtes et coups d'archet.** Le profil de l'utilisateur, plus haut, les
reclame. L'ADR-007 limite volontairement le graveur a une ligne monodique et
interdit d'en faire un graveur general. Les deux ne sont pas incompatibles --
un doigte est un chiffre au-dessus d'une tete de note -- mais rien n'est au
backlog. Non tranche.

**~~L'intonation expressive.~~ Tranchee, lot I2.** Le constat etait bon, sa
formulation exageree : avec 35 cents de tolerance, la couleur n'etait jamais
fausse -- l'application retirait des points, de 4 a 11 sur cent, toujours sur
les memes degres.

L'argument retenu est plus solide que celui-ci : les deux references
d'intonation enseignees, juste et pythagoricienne, **different de 21,5 cents
sur la tierce majeure**, et vont en sens inverse. Un bareme qui distingue a 10
cents note donc plus finement que ne different deux reponses correctes.
`perfectCents` passe a 22.

Reste ouvert : une quinte ne varie que de deux cents d'un systeme a l'autre et
merite une marge plus serree qu'une tierce. Cela demande le degre dans la
tonalite -- lot I3, que l'import MusicXML rendra gratuit.
