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
