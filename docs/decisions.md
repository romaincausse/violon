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

> **Amende par l'ADR-007.** Le pre-rendu reste la voie pour importer un
> morceau entier du repertoire, mais il ne peut pas servir un passage saisi
> dans l'application. Voir ADR-007.

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
