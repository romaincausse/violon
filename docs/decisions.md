# Decisions d'architecture

Format court : contexte, decision, consequences. Une entree par choix
structurant, pour ne pas avoir a rejouer le debat dans six mois.

---

## ADR-001 : Flutter plutot que natif ou web

**Contexte.** Il faut capturer le micro, analyser le signal en temps reel,
afficher une partition et tenir sur Android puis iOS.

**Decision.** Flutter, application native, cible telephone Android.

**Pourquoi pas le web.** C'est l'audio qui tranche, pas l'interface. Web
Audio est bride sur iOS/Safari, la capture se coupe en arriere-plan,
l'annulation d'echo systeme degrade le signal sans qu'on puisse la couper, et
la latence entree/sortie n'est pas connaissable. Or noter le rythme en
millisecondes suppose de connaitre cette latence.

**Consequences.** Le DSP est ecrit en Dart (YIN dans un isolate) ; si les
performances coincent, FFI vers du C reste ouvert. Flutter Web reste utilise
comme **environnement de developpement** de l'interface, avec une
`PitchSource` factice.

---

## ADR-002 : Partitions pre-gravees par Verovio, hors application

> **Caduque.** Amendee d'abord par l'ADR-007 -- un passage saisi dans
> l'application ne peut pas etre pre-grave -- puis videe de son dernier usage
> par l'ADR-009.
>
> Le pre-rendu devait rester la voie d'import d'un morceau entier. Mais depuis
> que l'application **suit** l'eleve, elle a besoin des notes elles-memes
> (hauteurs et durees, soit un `Passage`), pas d'une image accompagnee d'un
> timemap. Un SVG ne se suit pas. L'import du lot H6 lit donc directement le
> MusicXML, ce qui est de l'analyse d'XML et non de la gravure.
>
> `tool/build_scores.mjs` et `make scores` sont dormants en consequence.

**Contexte.** Il n'existe pas de moteur de gravure musicale mature en
Flutter. Trois voies : WebView + OpenSheetMusicDisplay ou alphaTab, moteur
maison SMuFL, ou pre-rendu.

**Decision.** Verovio en ligne de commande, hors application. Il produit un
SVG par systeme, un identifiant sur chaque glyphe, et un **timemap** donnant
l'onset en millisecondes de chaque note. La correspondance note / temps /
position a l'ecran est donc fournie gratuitement.

**Pourquoi pas la WebView.** Qualite equivalente et import libre, mais on
paie le pont JS, la latence de defilement et la synchronisation d'un curseur
qui vit de l'autre cote de la WebView.

**Pourquoi pas un moteur maison.** Dessiner les glyphes Bravura au
`TextPainter` est facile ; c'est le moteur de mise en page qui coute
(espacement non lineaire, ligatures, collisions d'alterations, liaisons,
justification, sauts de ligne). Plusieurs mois pour egaler Verovio.

**Consequences.** Pas d'import MusicXML arbitraire a l'execution. Acceptable :
le repertoire est controle. Avantage inattendu, on choisit soi-meme la
largeur de page, ce qui permet des systemes de 2 mesures adaptes a un ecran
de telephone -- ce qu'aucun moteur en reflow ne ferait correctement.

---

## ADR-003 : `PitchSource` comme unique frontiere audio

**Contexte.** Le portage iOS, le developpement de l'interface et les tests
ont tous besoin de ne pas dependre du micro reel.

**Decision.** Une interface `PitchSource` expose un `Stream<PitchEstimate>`
et une latence mesuree. Trois implementations : Android reelle, factice pour
le web et les tests, iOS plus tard.

**Consequences.** Le portage iOS ne touche qu'une classe. Les tests du moteur
de notation sont deterministes. L'interface se developpe sous Chrome avec le
hot reload, sans jouer du violon a chaque iteration.

---

## ADR-004 : Le boucleur a variations est le coeur, pas la notation

> **Remplace par l'ADR-006.** Conserve ici parce que son diagnostic reste
> valable : c'est sa conclusion qui change, pas son constat.

**Contexte.** Le projet a demarre sur une idee de scoring de justesse et de
rythme. L'entretien avec l'utilisateur a revele que ce qui le fatigue, c'est
de rejouer dix fois la meme mesure.

**Decision.** La fonctionnalite centrale est le generateur de variations :
dix repetitions **differentes** du meme passage. La notation devient un
support, pas la finalite.

**Consequences.** Le MVP n'a pas besoin de rendu de partition abouti.
L'application dit "voila ta prochaine tache" plutot que "voila tes erreurs".
Toute proposition ramenant l'application vers le jugement permanent doit
etre questionnee.

---

## ADR-005 : Aucun backend

**Contexte.** L'application a un utilisateur unique et sert a cote d'un
pupitre, parfois sans reseau.

**Decision.** 100 % local. Pas de compte, pas de synchronisation, pas de
telemetrie. Les partitions sont des assets, l'historique une base locale.

**Consequences.** Rien a heberger, rien a securiser, aucune question RGPD sur
les enregistrements audio d'un mineur. L'export vers le professeur se fait
par partage de fichier.


---

## ADR-006 : La partition vivante est le coeur, pas le boucleur a cartes

> **Amende par l'ADR-009.** Le coeur reste la partition suivie en temps reel,
> mais le sens du suivi s'inverse : c'est l'application qui suit l'eleve, et
> non l'inverse. Le point 1 ci-dessous -- la boucle sur une selection --
> survit, en mieux : c'est desormais la mesure qui choisit les mesures a
> rejouer, pas l'enfant.

**Contexte.** L'ADR-004 avait fait du generateur de variations la
fonctionnalite centrale, la notation devenant un support. Six mois de recul
et un prototype jouable plus tard, l'utilisateur tranche autrement : ce qu'il
veut est un suivi interactif sur une partition qui vit, avec retour visuel et
notation de la justesse et du rythme, et un accompagnement.

**Decision.** Le coeur devient la **partition dynamique suivie en temps reel**.
Les cartes de variation et l'auto-evaluation ("C'etait propre" / "Pas
terrible") disparaissent.

**Ce qui ne change pas : le diagnostic de l'ADR-004.** L'enfant se lasse de
rejouer dix fois la meme mesure. Ce constat reste vrai, et le nouveau coeur
doit y repondre, sinon on aura resolu un probleme que personne n'avait.

**Comment le nouveau coeur y repond.**

1. **La boucle survit, la carte meurt.** On selectionne deux mesures sur la
   partition, on les boucle, et le tempo monte tout seul quand le passage est
   propre. C'est le meme mecanisme anti-lassitude, sans l'ecran de cartes.
2. **L'application mesure au lieu de demander.** L'auto-evaluation etait un
   pis-aller en attendant le micro. Un score mesure est plus motivant qu'un
   bouton sur lequel on appuie soi-meme, et plus honnete.
3. **L'accompagnement est la variete.** Jouer sur un accompagnement est ce
   qui rend une dixieme repetition supportable, bien mieux qu'une consigne
   "joue-le en pizzicato".

**Les garde-fous de l'ADR-004 restent en vigueur.** Une erreur ne remet jamais
un compteur a zero. On termine sur une reussite au tempo ecrit. On montre des
donnees qui montent, pas des recompenses. L'application dit "voila ta
prochaine tache", pas "voila tout ce que tu as rate" -- une partition rouge
partout serait exactement la derive que l'ADR-004 redoutait.

**Consequences.** `lib/core/practice/` est supprime : `Variation`,
`VariationGenerator` et `PracticeSession`, soit environ 600 lignes avec leurs
tests. `PracticeScreen` et `RoundDots` suivent. `lib/core/audio/` et
`lib/core/music/` sont conserves intacts et deviennent plus centraux qu'avant.

---

## ADR-007 : Rendu natif d'une portee monodique, plutot que Verovio a l'execution

**Contexte.** L'ADR-006 exige une partition affichee, coloree note par note et
parcourue par un curseur. L'ADR-002 avait choisi le pre-rendu Verovio hors
application, en rejetant un moteur maison au motif qu'egaler Verovio prendrait
des mois. Mais un passage saisi dans l'application ne peut pas etre pre-grave :
il n'existe pas au moment du build.

**Decision.** Ecrire un rendu natif Flutter (`CustomPainter` + police SMuFL
Bravura) pour **une seule ligne monodique**.

**Pourquoi l'argument de l'ADR-002 ne s'applique pas ici.** Ce qui coute cher
dans un graveur, c'est la mise en page generale : polyphonie, collisions
d'alterations, justification, sauts de systeme, liaisons. Rien de tout cela
n'existe sur deux a quatre mesures monodiques, sans accords, sans paroles,
avec une seule cle. Il reste a placer des tetes de notes sur des lignes, des
hampes, des crochets, des ligatures et des barres de mesure. C'est un
week-end, pas plusieurs mois.

**Ce qu'on gagne, et qui vaut a soi seul la decision.** Le curseur et la
coloration vivent dans le meme arbre de widgets que le reste : pas de pont
WebView, pas de SVG a re-parser, pas de synchronisation entre deux mondes. Or
c'est exactement ce que l'ADR-006 demande de faire tourner a 60 images par
seconde.

**Consequences.** Une dependance d'asset : la police **Bravura**, sous licence
SIL OFL, donc versionnable sans probleme -- contrairement aux partitions sous
droits. Le pre-rendu Verovio de l'ADR-002 reste la voie pour importer un
morceau entier du repertoire, plus tard, et les deux chemins cohabiteront.

---

## ADR-008 : Accompagnement et notation sont deux modes, jamais simultanes

> **Tendu par l'ADR-009, pas encore revu.** Un accompagnement qui *suit*
> l'eleve -- le seul qui vaille musicalement -- doit ecouter pendant qu'il
> joue, ce que cet ADR interdit. La contradiction est reelle et reste ouverte :
> elle se resout au casque, par annulation d'echo, ou pas du tout. Voir le
> dernier jalon de la feuille de route.

**Contexte.** Sur un telephone pose sur un pupitre, le haut-parleur est a une
dizaine de centimetres du micro. Un accompagnement continu entre donc en
plein dans la capture, et le detecteur de hauteur analyserait un melange
violon + accompagnement. Le probleme etait deja signale pour le metronome,
mais un clic se coupe : un accompagnement, non.

**Decision.** Deux modes exclusifs.

- **Mode notation** : micro actif, aucun son emis par l'application. Le
  metronome est visuel. C'est le mode ou l'on est note.
- **Mode accompagnement** : accompagnement joue, micro coupe. On joue avec, on
  n'est pas note.

**Pourquoi pas le casque.** Ca resoudrait tout, et c'etait la voie la plus
propre techniquement. Ecarte comme contrainte materielle : imposer un casque a
chaque seance ajoute une friction avant de jouer, exactement la ou le projet
cherche a en enlever.

**Pourquoi pas l'annulation d'echo.** L'application sait ce qu'elle emet, donc
une soustraction est theoriquement possible. En pratique c'est un gros morceau
de DSP, qui se bat avec l'exigence de micro en `UNPROCESSED`, et qui peut tres
bien ne jamais atteindre une qualite suffisante. Mauvais pari de depart.

**Consequences.** La fonctionnalite "etre note pendant qu'on joue avec
l'accompagnement" n'existe pas, et c'est assume. Le mode accompagnement n'a
besoin d'aucun DSP : c'est le lot le moins risque des trois piliers. Si un
casque est branche, rien n'interdit de lever la restriction plus tard : la
detection de casque est triviale, et l'ADR pourra etre revu sans rien casser.

---

## ADR-009 : L'application suit l'eleve, l'eleve ne suit pas l'application

**Contexte.** L'ADR-006 a fait de la partition affichee le coeur, avec un
curseur qui avance sur l'horloge et un enfant qui se cale dessus. Deux choses
clochent, et l'usage les a revelees.

D'abord, **l'enfant lit sa partition papier**, posee sur le pupitre, comme il
le fait en cours et comme il le fera toute sa vie. Il ne lit pas un telephone
de six pouces pose a cote. La partition a l'ecran etait donc une surface de
lecture que personne ne lisait.

Ensuite, **un curseur qui avance tout seul impose un tempo a quelqu'un qui est
en train d'apprendre le passage**. Il le force a courir apres au lieu de le
laisser jouer. C'est exactement l'inverse de ce qu'un professeur fait avec un
eleve de quatrieme annee : on le laisse jouer, on ecoute, on corrige.

**Decision.** L'eleve joue, sur sa partition papier, a son tempo, quand il
veut. **L'application le suit.** Elle connait la partition, elle ecoute, elle
sait a tout instant ou il en est, et elle mesure la justesse et le rythme de
ce qu'elle a entendu.

**Ce que la decision coute.** Le suivi adaptatif etait en V4 dans l'ancien
plan, decrit comme "le lot le plus risque du projet". Il devient le premier
lot. **On commence donc par le risque**, et c'est volontaire : batir la
notation, la boucle et le diagnostic sur un suiveur non prouve reviendrait a
construire trois etages sur des fondations qu'on n'a pas coulees.

**Consequences.**

- La partition a l'ecran n'est plus une surface de lecture, c'est une
  **surface de retour**. Elle doit se comprendre d'un coup d'oeil entre deux
  traits d'archet, et se lire posement apres. Les lots G1 a G8 restent
  entierement valables : c'est leur moment qui change, pas leur contenu.
- `ScoreCursor`, pilote par l'horloge, n'est plus le coeur. Il survit comme
  mode secondaire, pour travailler au metronome quand c'est ce qu'on veut.
- **La coloration en direct gagne en honnetete au passage.** Aujourd'hui, un
  enfant en retard d'une croche est mesure contre la note suivante : il peut
  jouer parfaitement juste et se voir affiche faux. Avec le suivi, il est
  mesure contre la note qu'il joue vraiment.
- Il faut la partition **en machine** pour la suivre. Saisir quatre mesures a
  la main convient pour un passage ; un morceau entier demandera un import.

---

## ADR-010 : Suivre est tolerant, juger est strict

**Contexte.** L'ADR-009 cree un paradoxe immediat. Si l'application s'adapte a
ce que joue l'eleve, alors par construction il n'est jamais en retard : le
suiveur le rattrape. Un suiveur parfait rendrait toute notation du rythme
impossible.

**Decision.** **Un seul alignement, deux lectures qui n'ont pas le meme
caractere.**

- Le **suiveur** est elastique. Son unique objectif est de ne jamais perdre la
  position, quoi qu'il arrive : hesitation, fausse note, arret net, reprise de
  la mesure pour la cinquieme fois. Il ne juge rien.
- Le **juge** est strict. Il reprend les instants d'attaque que l'alignement a
  produits, en deduit le tempo reellement tenu, et mesure l'ecart de chaque
  note a la grille metrique **a ce tempo-la**.

**Ce que cette separation distingue, et qui est exactement ce qu'un professeur
distingue a l'oreille :**

| Ce qui est joue | Verdict |
|---|---|
| Tout le passage a 74 au lieu de 92, rythme impeccable | Tempo tenu : 74. **Pas une faute de rythme.** |
| Une noire jouee comme une croche | Ecart residuel important sur cette note. **Faute de rythme.** |
| Deux secondes d'arret avant le do# | Ni l'un ni l'autre : une **hesitation**, qui vaut souvent plus que les deux. |

Compter le premier cas comme une faute de rythme serait reprocher a un enfant
d'avoir choisi un tempo qu'il tient. C'est pourtant ce que fait toute
application calee sur un metronome.

**Consequence majeure : la calibration de latence cesse d'etre bloquante.**
Le rythme est desormais juge en comparant les attaques de l'eleve **entre
elles**. Une latence de capture constante les decale toutes du meme montant et
disparait de la soustraction. Le lot A4 reste necessaire au jalon de
l'accompagnement, ou l'application emet un son qui doit tomber avec l'eleve.
Le score de rythme, lui, n'attend plus rien -- ni A4, ni la dependance de
moteur audio qui le bloquait.

**Consequence technique a ne pas oublier.** Le suiveur consomme les deux flux
a la fois : les hauteurs et les attaques. Le probleme signale dans l'ancien
lot N2 -- le detecteur d'attaques a besoin d'un flux sans trou, l'analyse de
hauteur jette des trames sous pression -- n'est donc plus reportable. Il est
au premier jalon.

---

## ADR-011 : La progression guide, elle ne verrouille pas

**Contexte.** Le catalogue d'exercices (E1) est ordonne par difficulte, et la
progression (E2) ouvre un palier quand le precedent est acquis. La question
suit tout de suite : un palier non ouvert doit-il etre **jouable** ?

Verrouiller est ce que font la plupart des applications de musique, et ca
marche : voir le palier suivant grise donne envie de finir celui-ci. L'argument
n'est pas mauvais.

**Decision.** **Un palier non ouvert porte un cadenas, et reste jouable.** Le
cadenas dit ou en est la progression ; il ne ferme pas la porte.

**Pourquoi.** Parce que ce n'est pas l'application qui decide du programme de
l'eleve, c'est son professeur. Si le cours de mardi a donne la gamme de si
bemol majeur, l'application n'a aucune raison valable de la refuser -- et la
refuser serait la meilleure facon de faire desinstaller l'application, par le
parent ou par l'enfant.

L'ordre des methodes est un **conseil eprouve**, pas un reglement : Hrimaly
n'a jamais interdit de sauter une page.

**Ce que ca coute.** Le ressort de motivation du deverrouillage. On le remplace
par ce que le projet s'est deja engage a montrer : des donnees qui montent --
le meilleur score, le tempo tenu, le nombre d'exercices acquis -- et **une
seule prochaine tache mise en avant**. La carte du haut de l'ecran dit quoi
travailler ce soir ; le catalogue entier est en dessous, pour qui veut choisir.

**Coherence avec le reste.** C'est la meme regle que pour les mesures a
rejouer : l'application **designe**, elle n'impose pas. Et c'est la regle
produit prise au serieux -- "voila ta prochaine tache", jamais "voila ce que tu
n'as pas le droit de jouer".
