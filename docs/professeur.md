# Ce que le professeur peut en faire

Document de conception du jalon V5. Il repond a une question posee tot :
**un professeur de violon, concretement, s'en sert comment ?**

Le professeur n'est pas l'utilisateur de l'application. L'enfant l'est. Mais
le professeur est celui qui decide ce qui se travaille, et sans lui l'outil
reste un jouet de mesure.

---

## Le probleme du professeur, qui n'est pas celui de l'enfant

Un professeur voit son eleve **une demi-heure par semaine**. Les six jours et
demi restants lui sont invisibles. Il en tire ce qu'il peut :

- ce que l'enfant dit avoir travaille, qui est optimiste ;
- ce que le cahier de textes dit, qui est une ligne ecrite il y a sept jours ;
- ce qu'il entend au debut du cours, qui melange le travail de la semaine et
  la fatigue du jour.

Il reconstruit donc la semaine par deduction, chaque semaine, pour tous ses
eleves. C'est la que l'application a quelque chose a apporter -- pas en lui
apprenant son metier, mais en **rendant visible ce qui ne l'etait pas**.

---

## Quatre usages, par ordre de valeur

### 1. Lire ce qui s'est reellement passe dans la semaine

Le rapport de travail, ouvert en debut de cours : quels jours, combien de
minutes, quels passages, combien de repetitions, comment la justesse a
evolue, quel tempo a ete tenu, **et quelles mesures resistent encore**.

C'est l'usage qui change le plus le cours. Le professeur n'a plus a passer
dix minutes a decouvrir ou ca coince : il le sait avant que l'archet touche la
corde, et il consacre ces dix minutes a corriger.

Un detail qui compte : le nombre de **reprises** d'une mesure vaut souvent
plus que son score. Une mesure rejouee quatorze fois est une mesure qui fait
peur, meme si elle finit juste.

### 2. Poser le travail de la semaine

En fin de cours, le professeur marque les passages et le tempo vise. L'enfant
ouvre l'application chez lui et **le travail est deja la** : pas de ligne a
relire, pas d'interpretation, pas de "je croyais que c'etait jusqu'a la 20".

Ca remplace la ligne du cahier que personne ne relit, et surtout ca supprime
la marge de negociation entre ce qui a ete demande et ce qui a ete compris.

### 3. Objectiver un diagnostic pendant le cours

"Ton do# est bas" est un jugement. L'enfant peut ne pas l'entendre, ne pas y
croire, ou l'entendre comme un reproche.

"Ton do# a ete bas de 22 cents, 38 fois sur 41 cette semaine" n'est pas un
jugement : c'est un fait, et il n'est pas negociable. Plus important, **il
n'est adresse a personne** -- la mesure ne gronde pas.

L'application devient un tiers dans la piece. Le professeur enseigne, elle
mesure, et les deux roles ne se marchent pas dessus.

### 4. Prescrire precisement, plutot que largement

C'est ce que le lot H3 doit permettre. Les fautes de justesse d'un violoniste
ne sont pas aleatoires : elles sont **structurees par la main**. Un demi-ton
mal place entre deuxieme et troisieme doigt se retrouve sur toutes les notes
qui le demandent, sur toutes les cordes, dans toutes les mesures.

Un score par note dit "cette note est basse". Un diagnostic par doigt dit
**pourquoi**, et transforme "travaille ta justesse" en "ton troisieme doigt
est bas sur re et sol, voila l'exercice". La premiere consigne est inapplicable
a onze ans ; la seconde se travaille en dix minutes.

---

## La ligne a ne pas franchir

**Le rapport doit se lire comme un progres, jamais comme un releve de
surveillance.**

Le jour ou l'enfant comprend que l'application rapporte a l'adulte ce qu'il
n'a pas fait, il arrete de jouer devant elle. Il travaillera a cote, micro
eteint, et l'outil sera mort sans que personne ne s'en apercoive -- sinon par
des rapports etrangement vides.

Trois consequences concretes, qui sont des contraintes de conception et pas
des intentions :

1. **L'export est un geste volontaire**, fait sur le telephone de l'enfant.
   Aucun envoi automatique, aucun compte, aucun serveur (ADR-005). Ce n'est
   pas seulement une position technique : c'est ce qui rend l'outil
   acceptable pour celui qui l'utilise.
2. **Le rapport montre ce qui a monte**, pas les jours manques. Un jour sans
   travail n'apparait pas comme une absence a justifier.
3. **Aucun enregistrement audio n'est conserve.** L'application mesure et
   jette. Un enfant qui sait que son professeur pourra reecouter ses ratages
   ne joue plus pareil -- et ca poserait en prime une question de donnees
   personnelles d'un mineur que l'ADR-005 avait justement evacuee.

---

## Ce que l'application ne fera pas a sa place

Elle ne juge ni la sonorite, ni le phrase, ni la conduite d'archet. Aucune
application ne sait le faire, et pretendre le contraire appauvrirait la
musique en la reduisant a ce qui se mesure.

C'est aussi ce qui rend l'outil acceptable pour un professeur : il ne prend
pas sa place. Il lui rend la semaine visible et lui laisse la musique.
