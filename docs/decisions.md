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
