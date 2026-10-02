import 'dart:math' as math;
import 'dart:typed_data';

import '../music/passage.dart';
import '../music/score_note.dart';
import 'performance_features.dart';

/// Le modele de suivi : ce que l'aligneur hors ligne et le suiveur en direct
/// partagent, a l'identique.
///
/// **Un seul modele, deux lectures du temps.** Hors ligne, Viterbi voit toute
/// la prise et remonte le meilleur chemin ; en direct, le suiveur ne garde que
/// le dernier pas et dit ou en est le meilleur chemin *maintenant*. Les
/// probabilites sont les memes : ce que le banc a mesure sur l'un vaut pour
/// l'autre, a la difference pres que le direct ne peut pas se corriger apres
/// coup.
///
/// **Le modele.** Un modele de Markov cache. Deux etats par note de la
/// partition : "je joue cette note" et "je me suis arrete apres elle". Le
/// second garde la memoire de la position pendant le silence : c'est lui qui
/// rend une reprise possible, puisqu'on sait d'ou l'on repart. Un dernier
/// etat attend avant que rien n'ait ete joue.
///
/// **Ce qui en fait un suiveur de travail, et pas de concert** : les
/// transitions ne vont pas seulement a la note suivante. On peut revenir au
/// debut de n'importe quelle mesure -- la sienne surtout, les precedentes un
/// peu moins, les suivantes rarement -- et sauter une note. Un DTW classique,
/// qui ne fait qu'avancer, ne saurait pas representer une reprise.
///
/// **Tolerant, parce qu'il ne juge rien** (ADR-010). Une note fausse reste
/// plus proche de la note visee que de ses voisines ; une note qui ne
/// ressemble a rien garde une probabilite plancher plutot que de faire
/// sauter la position.
class FollowModel {
  FollowModel(
    this.passage, {
    Set<String> slurredInto = const <String>{},
  })  : _slurredInto = slurredInto,
        _n = passage.notes.length {
    for (int i = 0; i < _n; i++) {
      if (i == 0 || passage.notes[i].measure != passage.notes[i - 1].measure) {
        _debutsDeMesure.add(i);
      }
      _mesureDe.add(_debutsDeMesure.length - 1);
    }
    _sauts = _poidsDesSauts(_debutsDeMesure.length);
  }

  final Passage passage;

  /// Notes jouees dans le meme archet que la precedente. On y arrive sans
  /// attaque : seul le changement de hauteur le dit.
  final Set<String> _slurredInto;

  final int _n;
  final List<int> _debutsDeMesure = <int>[];

  /// Pour chaque note, l'index de sa mesure dans [_debutsDeMesure].
  final List<int> _mesureDe = <int>[];

  /// `_sauts[k][j]` : log-probabilite relative de repartir du debut de la
  /// mesure `j` quand on est dans la mesure `k`.
  late final List<Float64List> _sauts;

  /// Etats : `0..n-1` jouer la note i ; `n..2n-1` silence apres la note i ;
  /// `2n` silence avant d'avoir rien joue.
  int get stateCount => 2 * _n + 1;

  int get noteCount => _n;

  /// L'index de la note d'un etat : celle qu'on joue, ou celle apres laquelle
  /// on s'est arrete. `null` avant d'avoir rien joue.
  int? noteIndexOf(int state) => state < _n
      ? state
      : state < 2 * _n
          ? state - _n
          : null;

  /// Vrai si l'etat est un silence.
  bool isRest(int state) => state >= _n;

  // --- Emissions -----------------------------------------------------------

  /// Largeur de la cloche autour de la note visee, en demi-tons. Quarante
  /// cents couvrent le vibrato (+/- 20 a 50 cents, moyenne sur une trame) et
  /// une note fausse de soixante-dix cents reste bien plus proche de sa cible
  /// que de ses voisines, a un ton.
  static const double _sigma = 0.4;

  /// Ce qu'une note completement a cote garde de probabilite. Sans plancher,
  /// une seule note ajoutee ferait sauter la position.
  static const double _plancher = 0.02;

  /// YIN se trompe parfois d'une octave, surtout sur la corde de sol.
  static const double _octave = 0.05;

  /// Poids de chaque trame dans le score.
  ///
  /// **Les trames d'une meme note ne sont pas des temoins independants** :
  /// quarante trames d'une note tenue trop haut disent une seule chose, pas
  /// quarante. Les compter a plein faisait couter une note fausse tenue plus
  /// cher qu'un saut n'importe ou dans la partition -- et l'aligneur perdait
  /// le fil pour huit notes, sur une seule faute.
  static const double _poidsTrame = 0.3;

  // --- Transitions ---------------------------------------------------------
  //
  // Deux jeux : sans attaque, et quand une attaque vient d'etre entendue. Une
  // attaque est ce qui fait changer de note ; sans elle, seul un changement de
  // hauteur franc -- une liaison -- justifie d'avancer.

  static final _Transitions _calme = _Transitions(
    reste: 0.95,
    avance: 0.03,
    avanceLiee: 0.15,
    saute: 0.002,
    arrete: 0.015,
    reprend: 0.002,
    silenceReste: 0.97,
    silenceRepart: 0.02,
    silenceRejoue: 0.003,
    silenceReprend: 0.005,
    nImporteOu: 1e-6,
  );

  static final _Transitions _attaque = _Transitions(
    reste: 0.1,
    avance: 0.6,
    avanceLiee: 0.6,
    saute: 0.05,
    arrete: 0.01,
    reprend: 0.15,
    silenceReste: 0.3,
    silenceRepart: 0.3,
    silenceRejoue: 0.05,
    silenceReprend: 0.3,
    nImporteOu: 1e-4,
  );

  /// Les scores de la premiere trame : on attend, ou l'on commence au debut
  /// d'une mesure.
  Float64List start(FeatureFrame premiere) {
    final Float64List s = Float64List(stateCount)
      ..fillRange(0, stateCount, double.negativeInfinity);
    s[2 * _n] = math.log(0.8);
    for (int j = 0; j < _debutsDeMesure.length; j++) {
      s[_debutsDeMesure[j]] = math.log(0.2) + _sauts[0][j];
    }
    _emettre(s, premiere);
    return s;
  }

  /// Un pas de Viterbi : de [precedent] a [courant], pour la trame [trame].
  ///
  /// [retour], s'il est donne, recoit a partir de [base] l'etat d'ou vient le
  /// meilleur chemin de chaque etat -- l'aligneur hors ligne en a besoin pour
  /// remonter, le suiveur en direct non.
  void step(
    Float64List precedent,
    Float64List courant,
    FeatureFrame trame, {
    Int32List? retour,
    int base = 0,
  }) {
    final int nEtats = stateCount;
    final int avantTout = 2 * _n;
    courant.fillRange(0, nEtats, double.negativeInfinity);
    final _Transitions tr = trame.onset ? _attaque : _calme;

    void pousser(int de, int vers, double logP) {
      final double v = precedent[de] + logP;
      if (v > courant[vers]) {
        courant[vers] = v;
        if (retour != null) {
          retour[base + vers] = de;
        }
      }
    }

    int meilleur = 0;
    for (int s = 1; s < nEtats; s++) {
      if (precedent[s] > precedent[meilleur]) {
        meilleur = s;
      }
    }

    for (int i = 0; i < _n; i++) {
      final int k = _mesureDe[i];
      if (precedent[i] != double.negativeInfinity) {
        pousser(i, i, tr.lReste);
        if (i + 1 < _n) {
          final bool liee = _slurredInto.contains(passage.notes[i + 1].id);
          pousser(i, i + 1, liee ? tr.lAvanceLiee : tr.lAvance);
        }
        if (i + 2 < _n) {
          pousser(i, i + 2, tr.lSaute);
        }
        pousser(i, _n + i, tr.lArrete);
        for (int j = 0; j < _debutsDeMesure.length; j++) {
          pousser(i, _debutsDeMesure[j], tr.lReprend + _sauts[k][j]);
        }
      }
      final int silence = _n + i;
      if (precedent[silence] != double.negativeInfinity) {
        pousser(silence, silence, tr.lSilenceReste);
        if (i + 1 < _n) {
          pousser(silence, i + 1, tr.lSilenceRepart);
        }
        pousser(silence, i, tr.lSilenceRejoue);
        for (int j = 0; j < _debutsDeMesure.length; j++) {
          pousser(
              silence, _debutsDeMesure[j], tr.lSilenceReprend + _sauts[k][j]);
        }
      }
    }
    pousser(avantTout, avantTout, tr.lSilenceReste);
    for (int j = 0; j < _debutsDeMesure.length; j++) {
      pousser(avantTout, _debutsDeMesure[j], tr.lSilenceRepart + _sauts[0][j]);
    }
    // N'importe ou : le filet de securite quand tout le reste a echoue.
    for (int s = 0; s < 2 * _n; s++) {
      pousser(meilleur, s, tr.lNImporteOu);
    }

    _emettre(courant, trame);
  }

  void _emettre(Float64List scores, FeatureFrame trame) {
    final double? midi = trame.midi;
    final bool calme = trame.rms < PerformanceFeatures.silenceRms;
    final double silence = midi != null ? _plancher : (calme ? 0.9 : 0.3);
    for (int i = 0; i < _n; i++) {
      final double p;
      if (midi == null) {
        p = calme ? 0.15 : 0.4;
      } else {
        final ScoreNote note = passage.notes[i];
        final double d = (midi - note.midi).abs();
        final double o = (d - 12).abs();
        p = math.exp(-d * d / (2 * _sigma * _sigma)) +
            _octave * math.exp(-o * o / (2 * _sigma * _sigma)) +
            _plancher;
      }
      scores[i] += _poidsTrame * math.log(p);
    }
    final double lSilence = _poidsTrame * math.log(silence);
    for (int s = _n; s < 2 * _n + 1; s++) {
      scores[s] += lSilence;
    }
  }

  /// La reprise la plus probable est celle de la mesure en cours, puis des
  /// precedentes, de moins en moins a mesure qu'on remonte. Sauter en avant
  /// arrive, mais rarement.
  static List<Float64List> _poidsDesSauts(int m) {
    return <Float64List>[
      for (int k = 0; k < m; k++)
        () {
          final Float64List poids = Float64List(m);
          for (int j = 0; j < m; j++) {
            if (j == k) {
              poids[j] = 1;
            } else if (j < k) {
              poids[j] = 0.6 * math.pow(0.6, k - j - 1).toDouble();
            } else if (j == k + 1) {
              poids[j] = 0.3;
            } else {
              poids[j] = 0.05 * math.pow(0.5, j - k - 2).toDouble();
            }
          }
          final double somme =
              poids.fold<double>(0, (double a, double b) => a + b);
          for (int j = 0; j < m; j++) {
            poids[j] = math.log(poids[j] / somme);
          }
          return poids;
        }(),
    ];
  }
}

/// Un jeu de probabilites de transition, pris une fois en logarithme.
class _Transitions {
  _Transitions({
    required double reste,
    required double avance,
    required double avanceLiee,
    required double saute,
    required double arrete,
    required double reprend,
    required double silenceReste,
    required double silenceRepart,
    required double silenceRejoue,
    required double silenceReprend,
    required double nImporteOu,
  })  : lReste = math.log(reste),
        lAvance = math.log(avance),
        lAvanceLiee = math.log(avanceLiee),
        lSaute = math.log(saute),
        lArrete = math.log(arrete),
        lReprend = math.log(reprend),
        lSilenceReste = math.log(silenceReste),
        lSilenceRepart = math.log(silenceRepart),
        lSilenceRejoue = math.log(silenceRejoue),
        lSilenceReprend = math.log(silenceReprend),
        lNImporteOu = math.log(nImporteOu);

  final double lReste;
  final double lAvance;
  final double lAvanceLiee;
  final double lSaute;
  final double lArrete;

  /// Repartir du debut d'une mesure sans s'etre arrete.
  final double lReprend;
  final double lSilenceReste;
  final double lSilenceRepart;
  final double lSilenceRejoue;
  final double lSilenceReprend;
  final double lNImporteOu;
}
