# Navigation

Document de conception du lot L2. Il repond a une question posee une fois les
fonctionnalites listees : **quand tout existera, comment on s'y retrouve ?**

A la fin du plan, l'application contient treize choses : accordeur, controle
du micro, bourdon, metronome, mode libre, gammes et exercices, passages et
morceaux, devoirs de la semaine, bilan, historique, diagnostic, rapport pour
le professeur, accompagnement. **Un menu a treize entrees serait un echec.**

---

## Les quatre contraintes qui decident de tout

1. **Dix secondes.** Au-dela, un enfant de onze ans repose le violon. C'est la
   contrainte la plus dure, et elle interdit a elle seule tout ecran d'accueil.
2. **Le violon est en main.** On ne navigue pas avec un archet dans une main
   et un instrument sous le menton. Tout ce qui est frequent doit etre
   atteignable au pouce, en bas de l'ecran, sur une cible large.
3. **Le telephone est sur un pupitre**, a soixante-dix centimetres, pas dans
   la main.
4. **Une seule intention est frequente.** Sur dix ouvertures de
   l'application, neuf sont "je travaille". Le reste du temps c'est "je
   choisis quoi travailler" ou "je regarde ou j'en suis".

---

## Le principe : la navigation, c'est la seance

L'application **n'a pas d'accueil**. Elle s'ouvre sur le travail en cours.

Une seance de violon a un deroule naturel -- on accorde, on s'echauffe, on
travaille, on finit sur une reussite, on regarde ce que ca a donne. La
navigation suit ce deroule au lieu de le decouper en rubriques.

```
   lancement
       |
       v
   +---------------------------------------------+
   |  JOUER                                      |   <- l'ecran par defaut
   |  "Kayser n3, mesures 12-16 - hier 74 bpm"   |      9 ouvertures sur 10
   |                                             |
   |  [ zone de jeu : bandeau, ruban, partition ]|
   |                                             |
   |            (  Demarrer  )                   |
   +---------------------------------------------+
   |  Jouer    |  Repertoire  |  Progres   | [~] |   <- 3 onglets + outils
   +---------------------------------------------+
                                              |
                     +------------------------+
                     v
            +----------------------+
            | Accordeur   Bourdon  |   <- tiroir en surimpression,
            | Metronome   Micro    |      ne quitte jamais la seance
            +----------------------+
```

---

## Trois destinations, pas treize

### Jouer -- l'ecran par defaut

C'est la que l'application s'ouvre, sans passer par rien. En haut, **une seule
ligne** dit ce qu'on travaille et ou on en etait : *"Kayser n3, mesures 12-16
-- hier : 74 bpm"*. En bas, **un seul bouton**, qui lance le depart compte.

Au centre, la zone de jeu, dont le contenu suit le profil d'affichage (D4) :
bandeau et ruban en mode decouverte, partition en mode par coeur.

**Le bilan n'est pas une autre page.** Quand la prise se termine, le meme
ecran bascule : le bandeau de mesures se remplit de couleurs et devient le
bilan, avec la proposition "on rejoue les mesures 14 et 15 ?". Envoyer sur une
page separee couterait deux appuis et ferait perdre le fil au moment precis ou
il faut relancer.

### Repertoire -- choisir quoi travailler

Dans cet ordre, qui est celui de la priorite reelle :

1. **Les devoirs de la semaine**, poses par le professeur
2. Les gammes et les exercices, avec les paliers ouverts
3. Les morceaux et passages deja saisis
4. Nouveau passage : saisie ou import

### Progres -- regarder ou on en est

Consulte en fin de seance, ou avec le professeur pendant le cours. Courbes de
justesse, tempo maximal atteint, temps de travail, heatmap cumulee,
diagnostic par doigt, et le rapport exportable.

---

## Le tiroir d'outils

Accordeur, bourdon, metronome, controle du micro. **Ce ne sont pas des
destinations : ce sont des outils qu'on prend violon en main, au milieu d'une
seance.**

Ils s'ouvrent donc en **surimpression**, depuis un bouton toujours au meme
endroit, et se referment d'un geste. Accorder au milieu d'un passage ne fait
rien perdre : on revient exactement ou on etait.

C'est ce qui interdit d'en faire un quatrieme onglet. Un onglet remplace
l'ecran ; un outil se pose par-dessus.

Les reglages vivent au bas de ce tiroir : ils sont rares, ils n'ont pas besoin
d'etre visibles.

---

## Quatre regles de disposition

**Le violon ne se repose jamais pour naviguer.** Toute action frequente est en
bas de l'ecran, sur une cible large. Rien d'important en haut, ou le pouce
n'arrive pas.

**Les memes choses au meme endroit.** Le bandeau de mesures est a la meme
place en gammes, en passage et en mode libre. La memoire du geste vaut mieux
qu'une disposition optimale par mode.

**Portrait pour choisir, paysage pour jouer.** Tourner le telephone est un
geste qui ne demande de viser aucun bouton, et c'est deja la posture de jeu --
deux systemes larges, commandes sur le cote. Le passage en paysage peut donc
valoir "je commence".

**Accorder est propose, jamais impose.** Si l'application n'a entendu aucune
corde a vide depuis l'ouverture, l'ecran *Jouer* affiche discretement
"accorder d'abord ?". Un appui. Pas une etape obligatoire : un enfant qui vient
de repeter il y a une heure n'a pas a repasser par la.

---

## Ce qu'on ne fait pas

- **Un tiroir lateral a treize entrees.** C'est la solution par defaut, et
  c'est un aveu qu'on n'a pas choisi.
- **Plus de trois onglets.** Au-dela, on ne les lit plus, on les cherche.
- **Un ecran d'accueil avec des tuiles.** Il coute un appui a chaque seance,
  tous les jours, pour une information qu'on connait deja.
- **Un assistant de premiere utilisation.** Il se subit une fois et se
  contourne toujours. Si l'application a besoin d'etre expliquee, c'est
  l'application qu'il faut reprendre.
