import 'take_history.dart';

/// Les premieres fois (lot V2) : ce qu'une prise a de nouveau, dit avant les
/// chiffres.
///
/// Un nombre absolu bouge lentement, et un nombre qui ne bouge pas
/// decourage. Ce qu'un enfant retient, c'est une premiere fois ou un ecart :
/// "la mesure 7 tient pour la premiere fois", "tempo +8 depuis lundi". Les
/// donnees sont celles de l'historique ; ici on les raconte autrement.
class Firsts {
  const Firsts._();

  /// Les phrases pour [take], au vu de [history] **avant** qu'on l'y ajoute.
  /// Vide quand rien n'est nouveau, ou quand c'est la toute premiere prise :
  /// une premiere fois se mesure a ce qui precede.
  static List<String> of(TakeHistory history, TakeRecord take) {
    final List<TakeRecord> avant = <TakeRecord>[
      for (final TakeRecord t in history.forKey(take.key))
        if (t.atMs < take.atMs) t,
    ];
    if (avant.isEmpty) {
      return const <String>[];
    }
    final List<String> phrases = <String>[];

    // Jusqu'au bout, pour la premiere fois.
    if (take.reachedEnd && !avant.any((TakeRecord t) => t.reachedEnd)) {
      phrases.add('Jusqu au bout, pour la premiere fois.');
    }

    // Les mesures qui tiennent pour la premiere fois : propres aujourd'hui,
    // jamais propres avant, et vues au moins une fois.
    final List<int> tiennent = <int>[];
    for (final MeasureTrace m in take.measures) {
      if (m.difficulty > 0) {
        continue;
      }
      bool vue = false;
      bool dejaPropre = false;
      for (final TakeRecord t in avant) {
        for (final MeasureTrace v in t.measures) {
          if (v.measure == m.measure) {
            vue = true;
            if (v.difficulty <= 0) {
              dejaPropre = true;
            }
          }
        }
      }
      if (vue && !dejaPropre) {
        tiennent.add(m.measure);
      }
    }
    if (tiennent.length == 1) {
      phrases.add('La mesure ${tiennent.single} tient pour la premiere fois.');
    } else if (tiennent.length == 2) {
      phrases.add('Les mesures ${tiennent.first} et ${tiennent.last} tiennent '
          'pour la premiere fois.');
    } else if (tiennent.length > 2) {
      phrases.add('${tiennent.length} mesures tiennent pour la premiere fois.');
    }

    // Le tempo, depuis le debut de la semaine : l'ecart au premier tempo tenu
    // des sept derniers jours, s'il monte d'au moins quatre.
    final int? tenu = take.reachedEnd ? take.heldPulseBpm : null;
    if (tenu != null) {
      TakeRecord? reference;
      for (final TakeRecord t in avant) {
        final int? h = t.reachedEnd ? t.heldPulseBpm : null;
        if (h == null || take.atMs - t.atMs > 7 * 24 * 3600 * 1000) {
          continue;
        }
        reference ??= t;
      }
      if (reference != null && reference.heldPulseBpm != null) {
        final int ecart = tenu - reference.heldPulseBpm!;
        if (ecart >= 4) {
          phrases.add('Tempo +$ecart depuis ${_jour(reference.at, take.at)}.');
        }
      }
    }
    return phrases;
  }

  static const List<String> _jours = <String>[
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  /// "lundi", ou "tout a l heure" si c'est le meme jour.
  static String _jour(DateTime d, DateTime maintenant) {
    final bool memeJour = d.year == maintenant.year &&
        d.month == maintenant.month &&
        d.day == maintenant.day;
    return memeJour ? 'tout a l heure' : _jours[d.weekday - 1];
  }
}
