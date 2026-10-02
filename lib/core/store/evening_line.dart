import 'progress.dart';
import 'take_history.dart';

/// Ce soir, en une phrase (lot V5).
///
/// A la fin de la seance, une phrase qu'il montre a qui il veut : la duree,
/// ce qui a tenu, et un fait s'il y en a un. Elle s'adresse a lui, pas a
/// l'adulte -- l'application ne rapporte pas, l'enfant montre
/// (`docs/professeur.md`). Des donnees qui montent, jamais ce qui manque.
class EveningLine {
  const EveningLine._();

  /// La phrase du soir, ou `null` s'il n'a rien joue aujourd'hui : on ne dit
  /// pas "rien", on ne dit rien.
  static String? of(TakeHistory history, DateTime now) {
    final DayJournal jour = DayJournal.of(history, now);
    if (jour.takes.isEmpty) {
      return null;
    }
    final List<String> parts = <String>[];
    final int minutes = jour.playing.inMinutes;
    parts.add(minutes < 1
        ? 'Ce soir : quelques instants d archet.'
        : 'Ce soir : $minutes minute${minutes > 1 ? 's' : ''} d archet.');

    // Ce qui a tenu : par travail, le meilleur tempo tenu jusqu'au bout
    // aujourd'hui, et s'il depasse tout ce qui precede, on le dit.
    for (final String cle in jour.keys) {
      int? tenu;
      String? titre;
      for (final TakeRecord t in jour.takes) {
        final int? h = t.reachedEnd ? t.heldPulseBpm : null;
        if (t.key == cle && h != null && (tenu == null || h > tenu)) {
          tenu = h;
          titre = t.title;
        }
      }
      if (tenu == null || titre == null) {
        continue;
      }
      int? avant;
      for (final TakeRecord t in history.forKey(cle)) {
        final int? h = t.reachedEnd ? t.heldPulseBpm : null;
        if (h != null &&
            t.at.isBefore(jour.day) &&
            (avant == null || h > avant)) {
          avant = h;
        }
      }
      if (avant == null) {
        parts.add('$titre tenu a $tenu, jusqu au bout.');
      } else if (tenu > avant) {
        parts.add('$titre tenu a $tenu : jamais aussi vite.');
      } else {
        parts.add('$titre tenu a $tenu.');
      }
      break;
    }

    // Un fait, s'il y en a un : la plus longue seance de la semaine.
    bool plusLongue = true;
    bool autreJour = false;
    for (int k = 1; k <= 6; k++) {
      final DayJournal j =
          DayJournal.of(history, now.subtract(Duration(days: k)));
      if (j.takes.isEmpty) {
        continue;
      }
      autreJour = true;
      if (j.playing >= jour.playing) {
        plusLongue = false;
      }
    }
    if (autreJour && plusLongue && minutes >= 1) {
      parts.add('Ta plus longue seance de la semaine.');
    }
    return parts.join(' ');
  }
}
