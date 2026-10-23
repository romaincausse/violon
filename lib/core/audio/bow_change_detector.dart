import 'dart:math' as math;
import 'dart:typed_data';

import 'onset_detector.dart';

/// Les changements d'archet, par le creux d'energie qui les separe (lot P4).
///
/// **Pourquoi un second detecteur.** Le banc d'essai (ADR-019) a montre que
/// le flux spectral ne voit pas la moitie des coups d'archet sur une meme
/// hauteur : le spectre d'un re qui suit un re ne change presque pas. Huit
/// croches de Firework passaient pour une ronde, et l'aligneur ne savait plus
/// quelle mesure, la piece repetant les memes. Sur les images du banc, chaque
/// coup d'archet est pourtant la : l'archet s'arrete et repart, l'energie
/// tombe de quatre a dix decibels pendant quelques dizaines de millisecondes.
///
/// **Le principe.** L'energie en decibels sur une fenetre courte ; un creux
/// est un minimum local plus bas d'au moins [depthDb] que ce qui l'entoure
/// **des deux cotes**. Les deux cotes, et c'est ce qui l'ecarte d'une fin de
/// note -- l'energie y tombe sans remonter -- et d'une attaque apres un
/// silence, que le flux spectral voit tres bien.
///
/// **Ce qu'il coute.** Un creux ne se confirme qu'en voyant l'energie
/// remonter : [decidedUntilMs] dit jusqu'ou il a tranche, et l'extracteur
/// attend cette limite avant de rendre une trame. Une quarantaine de
/// millisecondes de plus en direct.
class BowChangeDetector {
  BowChangeDetector({
    this.sampleRate = 44100,
    this.windowSize = 1024,
    this.hopSize = 256,
    this.depthDb = 3,
    this.minIntervalMs = 100,
    this.floorDb = -60,
  });

  final int sampleRate;

  /// 23 ms : un changement d'archet ne dure que quelques dizaines de
  /// millisecondes. Une fenetre deux fois plus longue l'effacait sur le banc.
  final int windowSize;

  /// 5,8 ms, comme le flux spectral.
  final int hopSize;

  /// Profondeur exigee des deux cotes. Le vibrato module l'energie d'un ou
  /// deux decibels ; un changement d'archet la creuse de trois a dix. Sur le
  /// banc, 3 dB comptent un peu plus de coups d'archet legers que 4, sans
  /// faux creux sur les notes tenues de la synthese, vibrato compris.
  final double depthDb;

  /// La plus courte note des partitions du banc dure plus de 200 ms ; deux
  /// creux plus proches que 100 ms sont le meme changement d'archet.
  final int minIntervalMs;

  /// En dessous, ce n'est pas un creux entre deux coups d'archet, c'est un
  /// silence : l'attaque qui suit sera vue par le flux spectral.
  final double floorDb;

  /// Combien de pas a gauche on cherche l'energie de la note precedente :
  /// 70 ms.
  static const int _gauche = 12;

  /// Combien de pas a droite on attend la remontee : 40 ms. C'est ce qui
  /// fixe le retard de decision.
  static const int _droite = 7;

  /// Le minimum doit l'etre sur 25 ms de part et d'autre.
  static const int _voisinage = 4;

  final List<double> _attente = <double>[];
  final List<double> _db = <double>[];
  int _indexDuPremier = 0;
  int _analyses = 0;
  int? _dernierMs;

  /// Instant jusqu'auquel tous les creux sont tranches : un creux plus ancien
  /// ne sera plus annonce.
  int get decidedUntilMs {
    if (_fini) {
      return 1 << 40;
    }
    final int dernier = _analyses - 1 - _droite;
    if (dernier < 0) {
      return -1;
    }
    return _temps(dernier);
  }

  int _temps(int index) => (index + 1) * hopSize * 1000 ~/ sampleRate;

  /// Analyse un morceau de signal qui suit exactement le precedent, et rend
  /// les changements d'archet qu'il permet de trancher.
  List<Onset> addSamples(Float32List samples) {
    _attente.addAll(samples);
    final List<Onset> sortie = <Onset>[];
    while (_attente.length >= windowSize) {
      double somme = 0;
      for (int i = 0; i < windowSize; i++) {
        final double v = _attente[i];
        somme += v * v;
      }
      _attente.removeRange(0, hopSize);
      final double efficace = math.sqrt(somme / windowSize);
      _db.add(20 * math.log(math.max(efficace, 1e-7)) / math.ln10);
      _analyses++;
      final Onset? o = _trancher(_analyses - 1 - _droite);
      if (o != null) {
        sortie.add(o);
      }
      // La memoire reste bornee : seul le voisinage d'un creux compte.
      while (_db.length > _gauche + _droite + 2) {
        _db.removeAt(0);
        _indexDuPremier++;
      }
    }
    return sortie;
  }

  Onset? _trancher(int index) {
    if (index - _gauche < _indexDuPremier || index < 0) {
      return null;
    }
    double at(int i) => _db[i - _indexDuPremier];
    final double ici = at(index);
    if (ici < floorDb) {
      return null;
    }
    for (int k = index - _voisinage; k <= index + _voisinage; k++) {
      if (k != index && at(k) < ici) {
        return null;
      }
    }
    double gauche = -1e9;
    for (int k = index - _gauche; k < index; k++) {
      gauche = math.max(gauche, at(k));
    }
    double droite = -1e9;
    for (int k = index + 1; k <= index + _droite; k++) {
      droite = math.max(droite, at(k));
    }
    if (math.min(gauche, droite) - ici < depthDb) {
      return null;
    }
    final int ms = _temps(index);
    final int? dernier = _dernierMs;
    if (dernier != null && ms - dernier < minIntervalMs) {
      return null;
    }
    _dernierMs = ms;
    return Onset(
      timestampMs: ms,
      strength: ((math.min(gauche, droite) - ici) / 20).clamp(0.0, 1.0),
    );
  }

  bool _fini = false;

  /// La prise est finie : ce qui n'a pas de suite ne sera jamais un creux,
  /// faute d'energie qui remonte. Tout est tranche.
  void finish() => _fini = true;

  /// Oublie tout : a appeler entre deux prises.
  void reset() {
    _fini = false;
    _attente.clear();
    _db.clear();
    _indexDuPremier = 0;
    _analyses = 0;
    _dernierMs = null;
  }
}
