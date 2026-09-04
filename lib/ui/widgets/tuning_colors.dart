import 'package:flutter/material.dart';

import '../../core/scoring/live_tuning.dart';

/// Couleur d'une note selon ce qu'on a entendu.
///
/// **Aucun rouge.** Le projet dit que l'application montre la prochaine tache,
/// pas la liste des echecs : une partition rouge partout serait une
/// regression. Le bleu et l'orange disent une **direction** -- trop bas, trop
/// haut -- la ou le rouge dirait une faute. Un enfant de 11 ans sait corriger
/// une direction ; une faute, il la subit.
class TuningColors {
  const TuningColors._();

  /// Juste.
  static const Color inTune = Color(0xFF2E7D32);

  /// Trop bas. Le bleu tire vers le grave dans toutes les representations
  /// courantes, et c'est la couleur la moins alarmante des trois.
  static const Color low = Color(0xFF1565C0);

  /// Trop haut.
  static const Color high = Color(0xFFE65100);

  /// Rien a dire : la note garde l'encre de la partition.
  static Color? of(TuningVerdict verdict) => switch (verdict) {
        TuningVerdict.unknown => null,
        TuningVerdict.inTune => inTune,
        TuningVerdict.low => low,
        TuningVerdict.high => high,
      };

  /// Libelle court, pour la legende.
  static String label(TuningVerdict verdict) => switch (verdict) {
        TuningVerdict.unknown => 'pas entendu',
        TuningVerdict.inTune => 'juste',
        TuningVerdict.low => 'bas',
        TuningVerdict.high => 'haut',
      };
}
