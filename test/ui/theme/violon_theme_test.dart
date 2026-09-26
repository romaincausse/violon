import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/ui/theme/violon_theme.dart';
import 'package:violon/ui/widgets/tuning_colors.dart';

/// Est-ce que deux couleurs peuvent se confondre en tant que **signaux** ?
///
/// Pas de colorimetrie ici : deux couleurs franches de teinte voisine se
/// confondent d'un coup d'oeil sur un ruban de quarante pixels de haut, deux
/// couleurs dont l'une est un gris ou un beige ne se confondent jamais. La
/// regle tient donc en deux conditions -- teintes proches, et toutes deux
/// vives.
bool _confusables(Color a, Color b) {
  final HSVColor x = HSVColor.fromColor(a);
  final HSVColor y = HSVColor.fromColor(b);
  if (x.saturation < 0.35 || y.saturation < 0.35) {
    return false;
  }
  final double brut = (x.hue - y.hue).abs();
  final double ecart = brut > 180 ? 360 - brut : brut;
  return ecart < 35;
}

void main() {
  group('ViolonTheme', () {
    final ThemeData theme = ViolonTheme.clair();

    test('le vert, le bleu et l orange restent aux mesures', () {
      // **La contrainte de fond de l'identite visuelle.** Ces trois couleurs
      // disent juste, trop bas, trop haut. Une interface qui s'en servirait
      // pour un bouton ou un onglet apprendrait a l'oeil qu'elles ne veulent
      // rien dire de particulier -- et le ruban d'ecart perdrait sa langue.
      const List<Color> reservees = <Color>[
        TuningColors.inTune,
        TuningColors.low,
        TuningColors.high,
      ];
      final ColorScheme c = theme.colorScheme;
      final Map<String, Color> roles = <String, Color>{
        'primary': c.primary,
        'onPrimary': c.onPrimary,
        'primaryContainer': c.primaryContainer,
        'onPrimaryContainer': c.onPrimaryContainer,
        'secondary': c.secondary,
        'secondaryContainer': c.secondaryContainer,
        'tertiary': c.tertiary,
        'tertiaryContainer': c.tertiaryContainer,
        'error': c.error,
        'errorContainer': c.errorContainer,
        'surface': c.surface,
        'onSurface': c.onSurface,
        'onSurfaceVariant': c.onSurfaceVariant,
        'surfaceContainer': c.surfaceContainer,
        'outline': c.outline,
        'outlineVariant': c.outlineVariant,
        'inverseSurface': c.inverseSurface,
        'inversePrimary': c.inversePrimary,
      };
      for (final MapEntry<String, Color> role in roles.entries) {
        for (final Color reservee in reservees) {
          expect(
            _confusables(role.value, reservee),
            isFalse,
            reason: '${role.key} se confond avec une couleur de mesure',
          );
        }
      }
    });

    test('les titres sont graves, le reste se lit', () {
      // Deux roles, deux polices. Si quelqu'un retire les fichiers d'assets,
      // Flutter retombe silencieusement sur la police du systeme : ce test
      // est ce qui rend la chute bruyante.
      expect(theme.textTheme.displayLarge?.fontFamily, ViolonTheme.titres);
      expect(theme.textTheme.titleLarge?.fontFamily, ViolonTheme.titres);
      expect(theme.textTheme.bodyMedium?.fontFamily, ViolonTheme.lecture);
      expect(theme.textTheme.labelLarge?.fontFamily, ViolonTheme.lecture);
    });

    test('rien ne se lit en gris clair sur clair', () {
      // Le texte secondaire est la premiere victime d'un theme pose a l'oeil.
      // A soixante-dix centimetres, un contraste de 3 ne se lit plus.
      final double clair = theme.colorScheme.surface.computeLuminance();
      final double sourdine =
          theme.colorScheme.onSurfaceVariant.computeLuminance();
      final double contraste = (clair + 0.05) / (sourdine + 0.05);
      expect(contraste, greaterThan(4.5));
    });

    test('le bouton plein est une gelule assez haute pour un archet', () {
      // On appuie dessus avec un violon dans l'autre main.
      final ButtonStyle? style = theme.filledButtonTheme.style;
      expect(style?.shape?.resolve(<WidgetState>{}), isA<StadiumBorder>());
      expect(style?.minimumSize?.resolve(<WidgetState>{})?.height, 52);
    });
  });
}
