import 'package:flutter/material.dart';

/// Les couleurs de l'interface.
///
/// **Une seule couleur d'interface, et trois couleurs de sens.** Le vert, le
/// bleu et l'orange sont deja pris : ils disent juste, trop bas, trop haut
/// (`TuningColors`). Une interface qui s'en servirait pour un bouton ou un
/// onglet les rendrait muettes -- l'oeil apprendrait que le vert ne veut rien
/// dire de particulier. Tout le reste de l'ecran est donc en encre sur
/// papier, et la seule couleur franche qui ne mesure rien est le lie-de-vin
/// de ce sur quoi on appuie.
abstract final class ViolonColors {
  /// L'encre : le texte, et la portee gravee.
  ///
  /// Un noir chaud plutot qu'un noir pur, comme celui d'une touche d'ebene.
  static const Color encre = Color(0xFF231F1D);

  /// L'encre des choses secondaires : sous-titres, unites, legendes.
  static const Color encreDouce = Color(0xFF6B625C);

  /// Le papier : le fond de l'application, et celui de la portee.
  static const Color papier = Color(0xFFF1EEE8);

  /// Les cartes, posees sur le papier.
  static const Color carte = Color(0xFFFBF9F5);

  /// Les filets : bords de carte, separateurs, graduations.
  static const Color trait = Color(0xFFDED7CC);

  /// Ce sur quoi on appuie.
  ///
  /// Sombre et froid, la ou l'orange de `TuningColors` est clair et chaud :
  /// les deux ne se confondent pas d'un coup d'oeil, ce qui est la seule
  /// chose qu'on leur demande.
  static const Color vin = Color(0xFF6E2A45);

  /// Le fond d'un etat choisi : onglet courant, pastille active.
  ///
  /// Un sable, et non un lie-de-vin delave : une teinte claire de cette
  /// couleur-la est un rose, c'est-a-dire exactement ce que le theme Material
  /// par defaut produisait et qu'on remplace.
  static const Color sable = Color(0xFFE8E0D2);
}

/// Le theme de l'application.
///
/// **Un seul theme, clair.** Le telephone est pose sur un pupitre, dans une
/// piece eclairee, a soixante-dix centimetres des yeux : la lisibilite passe
/// avant la discretion. Un theme sombre se justifiera le jour ou quelqu'un
/// travaillera dans le noir.
abstract final class ViolonTheme {
  /// Les titres.
  ///
  /// Un serif a fort contraste, parce que c'est l'ecriture de la partition
  /// papier que l'enfant a sous les yeux : les titres et les indications de
  /// mouvement y sont graves ainsi depuis toujours.
  static const String titres = 'InstrumentSerif';

  /// Ce qui se lit.
  ///
  /// Une lineale ouverte, qui tient a distance de lecture. C'est un fichier
  /// variable : l'epaisseur se demande par `fontWeight` comme pour n'importe
  /// quelle autre police.
  static const String lecture = 'Manrope';

  static ThemeData clair() {
    const ColorScheme couleurs = ColorScheme(
      brightness: Brightness.light,
      primary: ViolonColors.vin,
      onPrimary: Color(0xFFFFFBFA),
      primaryContainer: ViolonColors.sable,
      onPrimaryContainer: Color(0xFF4A1A2C),
      secondary: ViolonColors.encreDouce,
      onSecondary: ViolonColors.papier,
      secondaryContainer: Color(0xFFEDE6DA),
      onSecondaryContainer: ViolonColors.encre,
      tertiary: ViolonColors.encre,
      onTertiary: ViolonColors.papier,
      tertiaryContainer: Color(0xFFE1DBD1),
      onTertiaryContainer: ViolonColors.encre,
      // **Une panne se dit en mots, pas en couleur.** Il n'y a plus de teinte
      // libre : le vert, le bleu et l'orange mesurent, le lie-de-vin lance.
      // Tout rouge d'erreur tomberait a quelques degres de l'orange du "trop
      // haut", et une alerte se lirait comme une note un peu haute. Une
      // erreur est donc en encre, comme le reste, et c'est la phrase qui
      // porte la mauvaise nouvelle.
      error: ViolonColors.encre,
      onError: ViolonColors.papier,
      errorContainer: Color(0xFFE1DBD1),
      onErrorContainer: ViolonColors.encre,
      surface: ViolonColors.papier,
      onSurface: ViolonColors.encre,
      onSurfaceVariant: ViolonColors.encreDouce,
      surfaceContainerLowest: Color(0xFFFFFDFA),
      surfaceContainerLow: ViolonColors.carte,
      surfaceContainer: Color(0xFFEDE9E1),
      surfaceContainerHigh: Color(0xFFE7E2D9),
      surfaceContainerHighest: Color(0xFFE1DBD1),
      outline: Color(0xFFB8AE9F),
      outlineVariant: ViolonColors.trait,
      inverseSurface: ViolonColors.encre,
      onInverseSurface: ViolonColors.papier,
      inversePrimary: Color(0xFFE7B9C8),
      shadow: ViolonColors.encre,
      scrim: ViolonColors.encre,
    );

    final TextTheme typo = _typographie(couleurs);

    return ThemeData(
      useMaterial3: true,
      colorScheme: couleurs,
      textTheme: typo,
      scaffoldBackgroundColor: couleurs.surface,
      // Le voile colore que Material 3 pose sur les surfaces elevees
      // rendrait chaque carte un peu plus rose que la precedente. Ici une
      // carte est blanche parce qu'elle est une carte, pas parce qu'elle est
      // haute.
      appBarTheme: AppBarTheme(
        backgroundColor: couleurs.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: couleurs.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: typo.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: ViolonColors.carte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: ViolonColors.trait),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        iconColor: couleurs.onSurfaceVariant,
        titleTextStyle: typo.titleMedium,
        subtitleTextStyle: typo.bodySmall,
      ),
      // Des gelules, et hautes : on appuie avec un archet dans l'autre main.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: typo.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
          side: const BorderSide(color: ViolonColors.trait),
          foregroundColor: couleurs.onSurface,
          textStyle: typo.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: const StadiumBorder(),
          textStyle: typo.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: ViolonColors.sable,
          selectedForegroundColor: couleurs.onPrimaryContainer,
          foregroundColor: couleurs.onSurfaceVariant,
          side: const BorderSide(color: ViolonColors.trait),
          textStyle: typo.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ViolonColors.carte,
        side: const BorderSide(color: ViolonColors.trait),
        labelStyle: typo.labelLarge,
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ViolonColors.carte,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ViolonColors.sable,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty<TextStyle?>.fromMap(
          <WidgetStatesConstraint, TextStyle?>{
            WidgetState.selected: typo.labelMedium?.copyWith(
              color: couleurs.onPrimaryContainer,
            ),
            WidgetState.any: typo.labelMedium,
          },
        ),
        iconTheme: WidgetStateProperty<IconThemeData>.fromMap(
          <WidgetStatesConstraint, IconThemeData>{
            WidgetState.selected: IconThemeData(
              color: couleurs.onPrimaryContainer,
            ),
            WidgetState.any: IconThemeData(color: couleurs.onSurfaceVariant),
          },
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ViolonColors.carte,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: ViolonColors.trait,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: couleurs.inverseSurface,
        contentTextStyle: typo.bodyMedium?.copyWith(
          color: couleurs.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ViolonColors.trait,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: const SliderThemeData(
        inactiveTrackColor: ViolonColors.trait,
        activeTrackColor: ViolonColors.vin,
        thumbColor: ViolonColors.vin,
      ),
    );
  }

  /// L'echelle typographique.
  ///
  /// Les tailles sont un cran au-dessus des valeurs Material : l'ecran est a
  /// soixante-dix centimetres, pas a trente.
  static TextTheme _typographie(ColorScheme couleurs) {
    final Color encre = couleurs.onSurface;
    final Color douce = couleurs.onSurfaceVariant;

    // Un serif de titre se serre : aux grandes tailles, les chasses par
    // defaut laissent des trous entre les lettres.
    TextStyle titre(double taille, {double interlettre = -0.5}) => TextStyle(
          fontFamily: titres,
          fontSize: taille,
          height: 1.05,
          letterSpacing: interlettre,
          color: encre,
        );

    TextStyle texte(
      double taille, {
      FontWeight graisse = FontWeight.w400,
      Color? couleur,
      double interlettre = 0,
      double hauteur = 1.35,
    }) =>
        TextStyle(
          fontFamily: lecture,
          fontSize: taille,
          fontWeight: graisse,
          height: hauteur,
          letterSpacing: interlettre,
          color: couleur ?? encre,
        );

    return TextTheme(
      displayLarge: titre(72, interlettre: -2),
      displayMedium: titre(56, interlettre: -1.5),
      displaySmall: titre(44, interlettre: -1),
      headlineLarge: titre(36),
      headlineMedium: titre(30),
      headlineSmall: titre(26),
      // 22 et pas 24 : c'est ce qui fait tenir "Gamme de sol majeur" dans
      // la barre de titre en portrait, a cote de ses quatre icones.
      titleLarge: titre(22, interlettre: -0.2),
      // A partir d'ici on lit des donnees -- des mesures, des tempos, des
      // noms d'exercice -- et une lineale les tient mieux qu'un serif.
      titleMedium: texte(17, graisse: FontWeight.w600),
      titleSmall: texte(15, graisse: FontWeight.w600),
      bodyLarge: texte(16),
      bodyMedium: texte(15),
      bodySmall: texte(13, couleur: douce),
      labelLarge: texte(16, graisse: FontWeight.w600, hauteur: 1.2),
      labelMedium: texte(12, graisse: FontWeight.w600, interlettre: 0.2),
      labelSmall: texte(12, couleur: douce, interlettre: 0.2),
    );
  }
}
