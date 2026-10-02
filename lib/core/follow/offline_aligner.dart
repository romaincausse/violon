import 'dart:typed_data';

import '../music/passage.dart';
import 'follow_model.dart';
import 'performance_features.dart';

/// Une note de la partition, reconnue dans la prise.
class AlignedNote {
  const AlignedNote({
    required this.noteId,
    required this.startMs,
    required this.endMs,
  });

  final String noteId;
  final int startMs;
  final int endMs;

  @override
  String toString() => 'AlignedNote($noteId, $startMs-$endMs ms)';
}

/// Le resultat d'un alignement : a chaque trame, la note de la partition ou
/// l'eleve en est, ou rien s'il ne joue pas.
class Alignment {
  Alignment({required this.frameTimesMs, required this.frameNotes})
      : assert(frameTimesMs.length == frameNotes.length, 'une note par trame');

  final List<int> frameTimesMs;

  /// Nul pendant un silence.
  final List<String?> frameNotes;

  /// Les notes reconnues, dans l'ordre ou elles ont ete jouees. Une mesure
  /// reprise trois fois y figure trois fois.
  List<AlignedNote> get notes {
    final List<AlignedNote> sortie = <AlignedNote>[];
    String? courante;
    int debut = 0;
    for (int t = 0; t <= frameNotes.length; t++) {
      final String? id = t < frameNotes.length ? frameNotes[t] : null;
      final bool nouvelle = t == frameNotes.length || id != courante;
      if (nouvelle && courante != null) {
        sortie.add(
          AlignedNote(
            noteId: courante,
            startMs: frameTimesMs[debut],
            endMs:
                t < frameTimesMs.length ? frameTimesMs[t] : frameTimesMs.last,
          ),
        );
      }
      if (nouvelle) {
        courante = id;
        debut = t;
      }
    }
    return sortie;
  }
}

/// Aligne une prise entiere sur la partition, apres coup.
///
/// **Ce que le jalon 5 doit prouver** : qu'on sait dire, note par note, ou
/// l'eleve en est -- y compris quand il s'arrete, reprend la mesure, saute,
/// se trompe de note. Hors ligne, l'aligneur voit toute la prise : c'est la
/// **borne haute** de ce que fait le suiveur en ligne, qui partage son modele
/// ([FollowModel]) mais ne peut pas se corriger apres coup.
class OfflineAligner {
  OfflineAligner(
    this.passage, {
    Set<String> slurredInto = const <String>{},
  }) : _modele = FollowModel(passage, slurredInto: slurredInto);

  final Passage passage;
  final FollowModel _modele;

  Alignment align(List<FeatureFrame> frames) {
    final int t0 = frames.length;
    if (t0 == 0) {
      return Alignment(frameTimesMs: <int>[], frameNotes: <String?>[]);
    }
    final int nEtats = _modele.stateCount;
    final Int32List retour = Int32List(t0 * nEtats);
    Float64List precedent = _modele.start(frames[0]);
    Float64List courant = Float64List(nEtats);

    for (int t = 1; t < t0; t++) {
      _modele.step(precedent, courant, frames[t],
          retour: retour, base: t * nEtats);
      final Float64List echange = precedent;
      precedent = courant;
      courant = echange;
    }

    int etat = 0;
    for (int s = 1; s < nEtats; s++) {
      if (precedent[s] > precedent[etat]) {
        etat = s;
      }
    }
    final List<String?> notes = List<String?>.filled(t0, null);
    for (int t = t0 - 1; t >= 0; t--) {
      notes[t] = _modele.isRest(etat)
          ? null
          : passage.notes[_modele.noteIndexOf(etat)!].id;
      if (t > 0) {
        etat = retour[t * nEtats + etat];
      }
    }
    return Alignment(
      frameTimesMs: <int>[for (final FeatureFrame f in frames) f.timeMs],
      frameNotes: notes,
    );
  }
}
