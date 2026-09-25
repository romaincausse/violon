# Feuille de route

Six jalons. Chacun doit produire quelque chose d'utilisable, meme incomplet :
l'application doit servir a quelqu'un des le premier.

> **Ce plan remplace le precedent.** Le coeur n'est plus une partition que
> l'enfant suit, mais une application qui **le** suit. Le raisonnement est
> dans `docs/decisions.md`, ADR-009 et ADR-010.

---

## Le principe, en trois phrases

L'eleve joue sur **sa partition papier**, posee sur le pupitre, a son tempo,
quand il veut. **L'application l'ecoute et le suit** : elle sait a tout instant
ou il en est dans le morceau. De ce suivi elle tire tout le reste -- la
justesse note par note, le rythme, et surtout **les mesures qu'il faut
rejouer**.

Le telephone n'est pas un pupitre. C'est un professeur qui ecoute.

---

## Jalon 0 - La preuve

**Objectif :** savoir si le suiveur tient, avant de batir dessus.

**Utilisable des :** rien. C'est le seul jalon qui ne livre pas de
fonctionnalite, et c'est assume.

L'ancien plan rangeait le suivi adaptatif en V4 et le decrivait comme "le lot
le plus risque du projet". Il est maintenant le premier. **On commence donc
par le risque.** Si l'alignement ne tient pas sur de vraies prises d'un enfant
de onze ans -- avec ses hesitations, ses arrets, ses reprises -- alors c'est le
plan qu'il faut revoir, et il vaut mieux le decouvrir en deux soirees qu'en
trois mois.

- [ ] Banc d'essai : enregistrer de vraies prises, les annoter a la main
- [ ] Alignement hors ligne sur hauteurs + attaques, mesure contre l'annotation
- [ ] Verdict chiffre, ecrit dans un ADR

**Critere de sortie :** sur dix prises reelles, dont au moins trois avec arret
et reprise de mesure, l'alignement place **95 % des notes dans la bonne
mesure** et **90 % sur la bonne note**. En dessous, on ne passe pas au jalon
suivant : on change d'algorithme ou on change de plan.

---

## V1 - L'application sait ou tu en es

**Objectif :** il joue depuis son papier, l'application ne perd jamais le fil.

**Utilisable des :** la position affichee suit ce qu'il joue.

- [ ] Flux unique hauteurs + attaques, sans trou
- [ ] Suiveur en ligne : position et tempo local, a chaque note
- [ ] Re-ancrage : arret, reprise, saut, mesure rejouee dix fois
- [ ] La partition a l'ecran se cale sur la position suivie
- [ ] Le curseur a l'horloge survit comme mode secondaire

**Critere de sortie :** il joue ses quatre mesures depuis sa partition papier,
s'arrete au milieu, reprend la mesure precedente, repart -- et l'application
montre toujours le bon endroit.

**Le point dur.** Le suiveur consomme les hauteurs **et** les attaques. Or
l'analyse de hauteur jette des trames sous pression, et le detecteur
d'attaques a besoin d'un flux sans trou. L'ancien plan reportait cet
arbitrage ; il est ici, au premier lot.

**Ce que ce jalon repare au passage.** Aujourd'hui, un enfant en retard d'une
croche est mesure contre la note **suivante** : il peut jouer parfaitement
juste et se voir affiche faux. Avec le suivi, il est mesure contre la note
qu'il joue.

---

## V2 - L'application note ce que tu joues

**Objectif :** un score de justesse et de rythme par mesure, apres chaque
passage.

**Utilisable des :** le score de rythme s'affiche a cote de celui de justesse.

- [x] Score de justesse par note, en cents (attaque exclue)
- [ ] Tempo reellement tenu, deduit des attaques alignees
- [ ] Score de rythme : ecart de chaque note a la grille, **a ce tempo**
- [ ] Detection des hesitations, comptees a part
- [ ] Agregation par mesure
- [ ] Bilan de passage, et le total cumule qui ne redescend jamais

**Critere de sortie :** apres un passage joue au violon, il voit un score par
mesure, le tempo qu'il a tenu, et l'endroit ou il a hesite.

**La regle qui gouverne ce jalon (ADR-010).** Jouer juste rythmiquement a 74
au lieu de 92 n'est **pas** une faute de rythme : c'est un tempo tenu. Jouer
une noire comme une croche en est une. S'arreter deux secondes avant le do#
n'est ni l'un ni l'autre -- c'est une hesitation, et c'est souvent
l'information la plus utile des trois.

**Ce que ce jalon ne demande plus.** La calibration de latence bloquait tout
le rythme dans l'ancien plan, et elle-meme attendait un moteur audio. Comme le
rythme est desormais juge en comparant les attaques de l'eleve entre elles,
une latence constante disparait de la soustraction. **Plus aucune dependance
n'est necessaire pour finir V2.**

---

## V3 - L'application te dit quoi rejouer

**Objectif :** il ne choisit plus quoi travailler, l'application le lui dit.

**Utilisable des :** apres un passage, l'application propose deux mesures et
les boucle.

- [ ] Selection automatique des mesures les plus faibles
- [ ] Boucle sur ces mesures, suivie comme le reste
- [ ] Montee de tempo automatique quand c'est propre
- [ ] Fin de seance sur une reussite, au tempo ecrit

**Critere de sortie :** il fait dix passages d'affilee sans choisir lui-meme
quoi rejouer, le tempo monte tout seul, et il termine propre.

**C'est ici que la boucle se ferme.** Jusqu'a V2 l'application constate ; a
partir d'ici elle **dirige le travail**. Et c'est aussi ici que survit la
reponse a la lassitude : ce n'est plus l'enfant qui decide de rejouer la meme
mesure pour la dixieme fois, c'est la mesure qui designe la mesure. La
difference est petite a decrire et grande a vivre.

---

## V4 - L'application voit ce qui resiste

**Objectif :** le progres devient visible, et les erreurs deviennent
diagnosticables.

**Utilisable des :** l'application retrouve la seance precedente.

- [ ] Persistance des passages et des seances **<- dependance a choisir**
- [ ] Heatmap cumulee sur la partition
- [ ] Erreurs systematiques : par doigt, par corde, par position
- [ ] Courbes : justesse dans le temps, tempo maximal atteint
- [ ] Journal de seance
- [ ] Import d'un morceau entier

**Critere de sortie :** l'application sait dire "ton 3e doigt est bas d'une
quinzaine de cents sur re et sol, depuis trois semaines".

**Pourquoi le diagnostic par doigt vaut mieux qu'un score.** Les fautes de
justesse d'un violoniste ne sont pas aleatoires : elles sont structurees par
la main. Un demi-ton mal place entre deux doigts se retrouve sur toutes les
notes qui le demandent, quelle que soit la mesure. Un score par note dit "cette
note est basse" ; un diagnostic par doigt dit **pourquoi**, et ce qu'il faut
travailler. Aucun metronome ni accordeur du marche ne sait le faire.

**L'import, et pourquoi il peut remonter.** Suivre suppose d'avoir la partition
en machine. Saisir quatre mesures a la main convient pour un passage ; un
morceau entier, non. Si l'usage montre que la saisie bloque tout des V1, ce
lot remonte -- il est ici par theme, pas par certitude.

---

## V5 - Le professeur entre dans la boucle

**Objectif :** ce qui s'est passe pendant la semaine cesse d'etre invisible.

**Utilisable des :** un rapport de travail lisible en trente secondes.

- [ ] Devoirs de la semaine : passages et tempo vise
- [ ] Rapport de travail : jours, minutes, repetitions, progression
- [ ] Export fichier, sans compte ni serveur (ADR-005)
- [ ] Mode lecon : l'application comme tiers pendant le cours

**Critere de sortie :** le professeur ouvre le rapport en debut de cours et
sait quoi regarder avant d'avoir fait jouer une note.

**La ligne a ne pas franchir.** Ce rapport doit se lire comme un progres, pas
comme un releve de surveillance. Le jour ou l'enfant comprend que
l'application rapporte a l'adulte ce qu'il n'a pas fait, il arrete de jouer
devant elle -- et l'outil meurt. L'export reste **un geste volontaire**, sur
son telephone, avec ses donnees.

---

## V6 - L'accompagnement

**Objectif :** il rejoue son morceau pour le plaisir, avec quelqu'un.

**Utilisable des :** un accompagnement tourne pendant qu'il joue.

- [ ] Moteur audio a evenements pre-planifies **<- dependance a choisir**
- [ ] Calibration de latence
- [ ] Metronome sonore
- [ ] Accompagnement deduit du passage (basse et accords simples)
- [ ] Accompagnement qui suit l'eleve

**Critere de sortie :** il rejoue le morceau avec l'accompagnement, une fois
le travail fini.

**La contradiction a resoudre avant le dernier lot.** L'ADR-008 interdit
d'ecouter pendant que l'application joue : sur un telephone, le haut-parleur
est a dix centimetres du micro. Mais un accompagnement qui *suit* -- le seul
qui vaille musicalement, celui qui attend l'eleve au lieu de le laisser
derriere -- doit precisement ecouter pendant qu'il joue. Trois issues : le
casque, l'annulation d'echo, ou renoncer a ce lot. Aucune n'est choisie.

---

## Ce qui est explicitement hors perimetre

- Tout backend, compte utilisateur ou synchronisation
- Toute telemetrie
- L'evaluation de la sonorite, du phrase ou de la conduite d'archet : aucune
  application ne sait le faire, et pretendre le contraire appauvrirait la
  musique. L'outil est un complement technique, pas un professeur.
- La gamification enfantine. On montre des donnees qui montent.
- La distribution publique tant que des partitions sous droits sont embarquees

---

## Etat au 25 septembre 2026

Le jalon V2 est a moitie fait et **V1 est a refaire dans l'autre sens.** Ce
qui existe et qui sert tel quel :

| Acquis | Devient |
|---|---|
| Gravure Bravura, multi-systemes, zoom, paysage | Surface de **retour**, plus de lecture |
| Micro `UNPROCESSED`, YIN en isolate, lissage | Entree du suiveur |
| Detecteur d'attaques | Entree du suiveur **et** du juge de rythme |
| Score de justesse par note, attaque exclue | Inchange, mais alimente par le suiveur |
| Accordeur, diapason mesure | Inchange |
| Curseur a l'horloge | Mode secondaire |

Rien n'est jete. Le seul composant retrograde est le curseur a l'horloge, et
il garde un usage : travailler au metronome quand c'est ce qu'on veut.
