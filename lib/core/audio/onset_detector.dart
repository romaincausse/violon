import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

/// Une attaque detectee : l'instant ou une note commence.
class Onset {
  const Onset({required this.timestampMs, required this.strength});

  /// Instant du debut de la trame ou le changement a ete vu, depuis le debut
  /// de la prise.
  ///
  /// Il porte un biais systematique : le changement est constate a la fin de
  /// la fenetre d'analyse, pas a son debut. Ce biais est constant, donc la
  /// calibration de latence (lot A4) l'absorbe avec celle du materiel.
  final int timestampMs;

  /// Hauteur du pic de flux spectral. Sert a comparer deux attaques entre
  /// elles, pas a mesurer une nuance.
  final double strength;

  @override
  String toString() =>
      'Onset(${timestampMs}ms, force=${strength.toStringAsFixed(1)})';
}

/// Detecteur d'attaques par flux spectral.
///
/// **Pourquoi il existe.** YIN ne voit pas une note rejouee a la meme hauteur :
/// l'autocorrelation ne change pas d'un archet a l'autre. Sans detecteur
/// d'attaques distinct, deux croches sur la meme note passeraient pour une
/// blanche, et le rythme ne serait pas notable du tout.
///
/// **Le principe.** On compare le spectre de chaque trame au precedent et on
/// somme les cases qui ont **augmente**. Une attaque fait apparaitre d'un coup
/// beaucoup d'energie sur beaucoup de cases ; un son tenu, meme fort, n'en
/// fait apparaitre aucune. Ne compter que les hausses est ce qui distingue un
/// debut de note d'une fin de note.
///
/// **Sa propre decoupe.** Les trames de 2048 echantillons de la detection de
/// hauteur donneraient une resolution de 46 ms, sans commune mesure avec ce
/// qu'il faut pour noter un rythme. Ici la fenetre avance de 256 echantillons,
/// soit moins de 6 ms.
///
/// **Ce qu'il ne sait pas faire.** Une note deja en cours au tout premier
/// echantillon n'a pas d'attaque detectable : il n'y a pas de "avant" a quoi
/// la comparer. Sans consequence en pratique, le micro etant ouvert avant
/// qu'on joue.
class OnsetDetector {
  OnsetDetector({
    this.sampleRate = 44100,
    this.windowSize = 1024,
    this.hopSize = 256,
    this.thresholdRatio = 1.6,
    this.minFlux = 0.3,
    this.minRawFlux = 1,
    this.minIntervalMs = 50,
    this.medianWindow = 11,
  })  : assert(hopSize > 0 && hopSize <= windowSize, 'saut invalide'),
        assert(medianWindow > 0, 'la fenetre mediane doit etre non vide'),
        _fft = Fft(windowSize);

  final int sampleRate;

  /// Fenetre d'analyse. 1024 echantillons font 23 ms : assez pour que le
  /// spectre d'un violon ait un sens, assez court pour qu'une attaque ne se
  /// noie pas dans ce qui la precede.
  final int windowSize;

  /// De combien la fenetre avance a chaque analyse. C'est lui qui fixe la
  /// resolution temporelle : 256 echantillons font 5,8 ms.
  final int hopSize;

  /// Un pic doit depasser la mediane recente multipliee par ce facteur.
  ///
  /// **Un seuil relatif, pas absolu.** Un enfant qui joue doucement produit
  /// des attaques dix fois plus faibles que le meme enfant en forte. Un seuil
  /// fixe ne verrait que les secondes.
  final double thresholdRatio;

  /// Plancher sur le flux **normalise**, entre 0 et 1.
  ///
  /// Il repond a la question "est-ce vraiment une montee ?", independamment de
  /// la nuance : une attaque franche vaut environ 0,9, la fin d'une note 0,14.
  /// C'est ce critere qui rend une attaque piano aussi visible qu'une attaque
  /// forte.
  final double minFlux;

  /// Plancher sur le flux **brut**, celui qui depend du volume.
  ///
  /// Il repond a la question "est-ce audible ?". Le critere normalise seul ne
  /// suffit pas : dans une piece silencieuse, le souffle du micro fluctue au
  /// hasard et la moitie des cases monte a chaque trame, ce qui donne un flux
  /// normalise eleve sur du vide.
  final double minRawFlux;

  /// Deux attaques ne peuvent pas se suivre de plus pres.
  ///
  /// Une attaque de violon dure plusieurs dizaines de millisecondes et
  /// produirait plusieurs pics rapproches. 50 ms laissent passer des doubles
  /// croches a 200 a la noire, bien au-dela de ce qui se joue ici.
  final int minIntervalMs;

  /// Nombre de trames sur lesquelles la mediane est prise.
  final int medianWindow;

  final Fft _fft;

  final List<double> _attente = <double>[];

  /// Flux brut par trame : c'est lui qui porte le relief d'une attaque.
  final List<double> _bruts = <double>[];

  /// Flux rapporte a l'energie de la trame, entre 0 et 1.
  final List<double> _normalises = <double>[];
  Float64List? _spectrePrecedent;
  int _indexDuPremierFlux = 0;
  int? _dernierOnsetMs;

  /// Analyse un morceau de signal et rend les attaques qu'il revele.
  ///
  /// Les echantillons doivent se suivre sans trou : c'est un flux, pas des
  /// trames independantes.
  List<Onset> addSamples(Float32List samples) {
    _attente.addAll(samples);
    final List<Onset> onsets = <Onset>[];

    while (_attente.length >= windowSize) {
      final Float32List fenetre = Float32List(windowSize);
      for (int i = 0; i < windowSize; i++) {
        fenetre[i] = _attente[i];
      }
      _attente.removeRange(0, hopSize);
      onsets.addAll(_analyser(fenetre));
    }
    return onsets;
  }

  List<Onset> _analyser(Float32List fenetre) {
    final Float64List spectre = _fft.magnitudes(fenetre);
    final Float64List? precedent = _spectrePrecedent;
    _spectrePrecedent = spectre;

    if (precedent == null) {
      return const <Onset>[];
    }
    // Ne sommer que les hausses : une fin de note fait baisser toutes les
    // cases, et n'est pas une attaque.
    double brut = 0;
    double total = 0;
    for (int k = 0; k < spectre.length; k++) {
      final double delta = spectre[k] - precedent[k];
      if (delta > 0) {
        brut += delta;
      }
      total += spectre[k];
    }
    // **Rapporte a l'energie de la trame.** Un enfant qui joue piano produit
    // des attaques dix fois plus faibles que le meme enfant en forte : le
    // flux brut les classerait comme du bruit. Rapporte au total, une attaque
    // vaut 0,9 quelle que soit la nuance.
    return _pousser(brut, brut / (total + 1e-9));
  }

  /// Juge l'avant-derniere valeur de flux, qui est la premiere dont on
  /// connaisse les deux voisines.
  ///
  /// D'ou une trame de retard, soit 5,8 ms. C'est le prix d'un vrai maximum
  /// local : sans la valeur suivante, la montee d'une attaque declencherait
  /// plusieurs fois avant son sommet.
  List<Onset> _pousser(double brut, double normalise) {
    _bruts.add(brut);
    _normalises.add(normalise);
    final List<Onset> onsets = <Onset>[];
    final int i = _bruts.length - 2;

    // **Le pic se cherche sur le flux brut.** Le flux normalise vaut 1 des la
    // premiere trame ou un son apparait, si faible soit-il : la trame
    // precedente etant vide, toutes les cases montent. Ce maximum degenere
    // tomberait avant la vraie attaque, sur une bouffee d'energie minuscule.
    if (i >= 1 && _bruts[i] > _bruts[i - 1] && _bruts[i] >= _bruts[i + 1]) {
      if (_bruts[i] > _seuilEn(i) && _normalises[i] > minFlux) {
        // La trame numero n couvre les echantillons [n * hopSize, ...[ : son
        // instant se calcule, il ne s'accumule pas.
        final int absolu = _indexDuPremierFlux + i;
        final int ms = (absolu + 1) * hopSize * 1000 ~/ sampleRate;
        final int? dernier = _dernierOnsetMs;
        if (dernier == null || ms - dernier >= minIntervalMs) {
          onsets.add(Onset(timestampMs: ms, strength: _normalises[i]));
          _dernierOnsetMs = ms;
        }
      }
    }

    // On ne garde que ce dont la mediane a besoin : la memoire reste bornee
    // meme apres une heure de travail.
    final int aGarder = medianWindow + 3;
    while (_bruts.length > aGarder) {
      _bruts.removeAt(0);
      _normalises.removeAt(0);
      _indexDuPremierFlux++;
    }
    return onsets;
  }

  /// Seuil sur le flux brut : le plus exigeant des deux criteres.
  ///
  /// La mediane s'adapte a la nuance du passage ; le plancher absolu exige que
  /// la note soit audible. Une piece silencieuse a une mediane presque nulle,
  /// et sans plancher n'importe quel souffle la depasserait d'un facteur dix.
  double _seuilEn(int i) {
    final int debut = math.max(0, i - medianWindow);
    final List<double> fenetre = _bruts.sublist(debut, i + 1)..sort();
    final double mediane = fenetre[fenetre.length ~/ 2];
    return math.max(mediane * thresholdRatio, minRawFlux);
  }

  /// Oublie tout : a appeler entre deux prises.
  void reset() {
    _attente.clear();
    _bruts.clear();
    _normalises.clear();
    _spectrePrecedent = null;
    _indexDuPremierFlux = 0;
    _dernierOnsetMs = null;
  }
}
