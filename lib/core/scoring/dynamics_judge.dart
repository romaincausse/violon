import 'dart:math' as math;

import '../follow/offline_aligner.dart';
import '../follow/performance_features.dart';
import '../music/passage.dart';
import '../music/score_note.dart';

/// Une nuance de la partition, et ce que la prise en a fait.
class DynamicsFinding {
  const DynamicsFinding({
    required this.at,
    required this.mark,
    required this.louder,
    required this.measuredDb,
  });

  /// La note ou la nuance change, ou ou le soufflet commence.
  final ScoreNote at;

  /// "mp", "f", "cresc", "dim".
  final String mark;

  /// La partition demande plus fort (vrai) ou plus doux (faux).
  final bool louder;

  /// Ce que la prise a fait : la difference d'energie, en decibels.
  final double measuredDb;

  /// La nuance s'entend : la difference va dans le bon sens, d'au moins
  /// [DynamicsJudge.heardDb].
  bool get heard =>
      (louder ? measuredDb : -measuredDb) >= DynamicsJudge.heardDb;
}

/// Les nuances (lot K9) : le forte de la mesure 9 est-il plus fort que le
/// piano de la mesure 5 ?
///
/// **On compare les passages entre eux**, jamais a une valeur : un micro a
/// soixante-dix centimetres ne donne pas de decibels absolus, mais il dit
/// sans faute qu'une phrase est plus douce que la precedente.
///
/// **Regle sur le banc**, avec les nuances de la photo de Firework (mf, mp a
/// la mesure 5, mf a la 13) et le vrai alignement : a la seance (prise 07),
/// le mp sonne 3,3 dB sous le mf qui precede et le mf de la 13 4,5 dB
/// au-dessus du mp ; dechiffree tres lentement (prise 08), le mp ne
/// s'entend pas (0,3 dB) et le mf de la 13 si (5,4). Une nuance s'entend a
/// partir de [heardDb].
class DynamicsJudge {
  const DynamicsJudge._();

  /// En dessous, la nuance ne s'entend pas.
  static const double heardDb = 2;

  /// De part et d'autre d'un changement, on compare au plus tant de
  /// mesures : la phrase qui precede et celle qui suit, pas tout le morceau.
  static const int sectionMeasures = 4;

  /// Il faut au moins tant de trames de chaque cote pour se prononcer.
  static const int minFrames = 8;

  /// L'attaque n'est pas la nuance.
  static const int attackMs = 60;

  static const Map<String, int> levels = <String, int>{
    'ppp': 0,
    'pp': 1,
    'p': 2,
    'mp': 3,
    'mf': 4,
    'f': 5,
    'ff': 6,
    'fff': 7,
  };

  /// Le nom d'une nuance, en toutes lettres : "f" se lirait comme la note
  /// fa, et un enfant ne sait pas forcement ce que "mp" abrege.
  static String nameOf(String mark) => switch (mark) {
        'ppp' => 'pianississimo',
        'pp' => 'pianissimo',
        'p' => 'piano',
        'mp' => 'mezzo piano',
        'mf' => 'mezzo forte',
        'f' => 'forte',
        'ff' => 'fortissimo',
        'fff' => 'fortississimo',
        _ => mark,
      };

  /// Ce que la prise a fait de chaque nuance qu'elle a jouee.
  static List<DynamicsFinding> judge({
    required Passage passage,
    required Alignment alignment,
    required List<FeatureFrame> frames,
  }) {
    final List<ScoreNote> notes = passage.notes;
    final Map<String, List<double>> energie = _energieParNote(
      alignment,
      frames,
    );
    List<double> de(int debut, int fin) => <double>[
          for (int i = debut; i <= fin && i < notes.length; i++)
            ...?energie[notes[i].id],
        ];

    final List<DynamicsFinding> sortie = <DynamicsFinding>[];
    // Les changements de nuance : la phrase d'avant contre celle d'apres.
    final List<int> marques = <int>[
      for (int i = 0; i < notes.length; i++)
        if (levels.containsKey(notes[i].dynamicMark)) i,
    ];
    for (int k = 1; k < marques.length; k++) {
      final int ici = marques[k];
      final int avant = levels[notes[marques[k - 1]].dynamicMark]!;
      final int apres = levels[notes[ici].dynamicMark]!;
      if (avant == apres) {
        continue;
      }
      final int mesure = notes[ici].measure;
      int debut = marques[k - 1];
      while (notes[debut].measure < mesure - sectionMeasures) {
        debut++;
      }
      int fin = k + 1 < marques.length ? marques[k + 1] - 1 : notes.length - 1;
      while (fin > ici && notes[fin].measure >= mesure + sectionMeasures) {
        fin--;
      }
      final List<double> a = de(debut, ici - 1);
      final List<double> b = de(ici, fin);
      if (a.length < minFrames || b.length < minFrames) {
        continue;
      }
      sortie.add(DynamicsFinding(
        at: notes[ici],
        mark: notes[ici].dynamicMark!,
        louder: apres > avant,
        measuredDb: _mediane(b) - _mediane(a),
      ));
    }
    // Les soufflets : le dernier tiers contre le premier.
    for (int i = 0; i < notes.length; i++) {
      final String? s = notes[i].hairpin;
      if (s != 'cresc' && s != 'dim') {
        continue;
      }
      int fin = i;
      while (fin + 1 < notes.length &&
          notes[fin + 1].hairpin != 'fin' &&
          notes[fin + 1].dynamicMark == null &&
          notes[fin + 1].hairpin == null) {
        fin++;
      }
      if (fin + 1 < notes.length && notes[fin + 1].hairpin == 'fin') {
        fin++;
      }
      final int tiers = math.max(1, (fin - i + 1) ~/ 3);
      final List<double> a = de(i, i + tiers - 1);
      final List<double> b = de(fin - tiers + 1, fin);
      if (fin - i < 2 || a.length < minFrames || b.length < minFrames) {
        continue;
      }
      sortie.add(DynamicsFinding(
        at: notes[i],
        mark: s!,
        louder: s == 'cresc',
        measuredDb: _mediane(b) - _mediane(a),
      ));
    }
    sortie.sort((DynamicsFinding a, DynamicsFinding b) =>
        a.at.onsetTicks.compareTo(b.at.onsetTicks));
    return sortie;
  }

  /// L'energie des trames voisees de chaque note, attaque ecartee, en dB.
  static Map<String, List<double>> _energieParNote(
    Alignment a,
    List<FeatureFrame> frames,
  ) {
    final Map<String, List<double>> parNote = <String, List<double>>{};
    int? debut;
    for (int t = 0; t < a.frameNotes.length && t < frames.length; t++) {
      final String? id = a.frameNotes[t];
      if (id == null) {
        debut = null;
        continue;
      }
      if (t == 0 || a.frameNotes[t - 1] != id) {
        debut = a.frameTimesMs[t];
      }
      final FeatureFrame f = frames[t];
      if (!f.voiced || a.frameTimesMs[t] - (debut ?? 0) < attackMs) {
        continue;
      }
      parNote
          .putIfAbsent(id, () => <double>[])
          .add(20 * math.log(f.rms) / math.ln10);
    }
    return parNote;
  }

  static double _mediane(List<double> x) {
    final List<double> s = List<double>.of(x)..sort();
    return s[s.length ~/ 2];
  }
}
