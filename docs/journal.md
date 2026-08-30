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

## Le retournement du projet

Question posee : qu'est-ce qui le fatigue le plus dans son travail quotidien ?

Reponse : **recommencer dix fois la meme mesure**.

Ce n'est donc pas un probleme de justesse mais de **monotonie**. Consequence :
le coeur de l'application devient le generateur de variations, pas le moteur
de notation. L'application dit "voila ta prochaine tache" au lieu de "voila
tes erreurs". Voir ADR-004.

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
