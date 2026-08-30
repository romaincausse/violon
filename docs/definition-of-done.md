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
- [ ] Testee sur un vrai telephone Android si elle touche l'audio ou l'affichage
- [ ] Lisible a 70 cm, telephone pose sur un pupitre

**Documentation**
- [ ] `docs/roadmap.md` mis a jour si un lot est termine
- [ ] Une entree dans `docs/decisions.md` si un choix structurant a ete fait
