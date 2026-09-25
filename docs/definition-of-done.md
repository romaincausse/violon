# Definition of done

Une PR est prete a merger quand :

**Code**
- [ ] `dart format .` ne modifie rien
- [ ] `flutter analyze --fatal-infos` passe
- [ ] `flutter test` passe
- [ ] `lib/core/` n'importe toujours pas Flutter
- [ ] Aucune nouvelle dependance non discutee

**Tests**
- [ ] La logique ajoutee dans `lib/core/` est couverte
- [ ] Les tests sont deterministes (graine explicite si aleatoire)
- [ ] Aucun test ne depend du micro reel

**Produit**
- [ ] La fonctionnalite respecte les principes de `CLAUDE.md` : objectif fini
      et visible, pas de remise a zero apres erreur, "prochaine tache" plutot
      que "liste d'erreurs"
- [ ] **Aucune faute de l'application n'est imputee a l'eleve** : un suiveur
      perdu, une partition mal importee ou un violon qui s'est desaccorde en
      cours de seance ne doivent jamais ressortir en faute de justesse ou de
      rythme
- [ ] Testee sur un vrai telephone Android si elle touche l'audio ou l'affichage
- [ ] Lisible a 70 cm, telephone pose sur un pupitre, **d'un coup d'oeil** :
      l'eleve lit son papier, pas l'ecran (ADR-009)

**Documentation**
- [ ] `docs/roadmap.md` **et** `docs/backlog.md` mis a jour si un lot est
      termine, les deux devant rester d'accord
- [ ] Une entree dans `docs/decisions.md` si un choix structurant a ete fait
