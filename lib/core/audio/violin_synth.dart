import 'dart:math' as math;
import 'dart:typed_data';

/// Une note tenue a l'archet, telle que [ViolinSynth] la fait sonner.
///
/// Ne connait ni la partition ni la note visee : c'est un son, pas une
/// intention. Ce qui a ete voulu est l'affaire de `SyntheticTake`, cote suivi.
class BowedNote {
  const BowedNote({
    required this.start,
    required this.duration,
    required this.midi,
    this.attack = true,
    this.vibratoCents = 0,
    this.amplitude = 0.3,
  });

  final Duration start;
  final Duration duration;

  /// Hauteur MIDI **fractionnaire** : 67,3 est un sol trop haut de trente
  /// cents. C'est ainsi qu'on fabrique une note fausse.
  final double midi;

  /// Faux dans une liaison : la note prolonge l'archet de la precedente, sans
  /// nouvelle attaque. Seule la hauteur change.
  final bool attack;

  /// Amplitude du vibrato, en cents de part et d'autre de [midi].
  final double vibratoCents;

  /// Amplitude de crete, de 0 a 1.
  final double amplitude;

  Duration get end => start + duration;
}

/// Un violon de synthese, assez credible pour mettre YIN et le detecteur
/// d'attaques dans les situations qu'ils rencontreront.
///
/// **Ce n'est pas un violon.** Il ignore la caisse, la piece, et le micro du
/// S22 a soixante-dix centimetres. Il sert a construire l'aligneur, jamais a
/// le juger : le critere du jalon 5 se mesure sur les prises reelles, et sur
/// elles seules.
///
/// Ce qu'il imite, parce que c'est ce qui piege les detecteurs :
///  - **une corde frottee est une dent de scie** : beaucoup d'harmoniques, et
///    pas en proportions regulieres -- la caisse en renforce certaines ;
///  - **l'attaque d'archet** monte en quelques dizaines de millisecondes, avec
///    un grattement bref, et non instantanement ;
///  - **une liaison ne coupe pas le son** : la hauteur glisse d'une note a
///    l'autre sous le meme archet, sans attaque ;
///  - **le vibrato** arrive apres l'attaque, pas avec elle ;
///  - **le bruit de fond** d'une piece calme, au niveau mesure sur le S22.
class ViolinSynth {
  ViolinSynth({
    this.sampleRate = 44100,
    this.a4 = 440,
    this.noiseRms = 0.005,
    this.seed = 0,
  }) : assert(sampleRate > 0, 'une frequence d echantillonnage est positive');

  final int sampleRate;

  /// Accord reel de l'instrument synthetise.
  final double a4;

  /// Bruit de fond, en amplitude efficace.
  ///
  /// **Mesure sur le S22, pas devine** : en `UNPROCESSED`, une piece calme
  /// tient entre 0,004 et 0,006 (voir `PcmTake`).
  final double noiseRms;

  final int seed;

  /// Nombre maximal d'harmoniques. Au-dela, l'energie est negligeable et le
  /// calcul double pour rien.
  static const int _maxHarmonics = 16;

  static const double _attackSeconds = 0.04;
  static const double _releaseSeconds = 0.03;
  static const double _scratchSeconds = 0.03;

  /// Duree du glissement de hauteur dans une liaison. Un doigt qui se pose ne
  /// saute pas instantanement d'une frequence a l'autre.
  static const double _glideSeconds = 0.025;

  static const double _vibratoHz = 5.5;

  /// Le vibrato ne commence pas avec la note : un violoniste pose le son,
  /// puis le fait vivre.
  static const double _vibratoDelaySeconds = 0.15;
  static const double _vibratoRampSeconds = 0.2;

  /// Le signal de [notes] sur [length], entre -1 et 1.
  Float32List render(List<BowedNote> notes, {required Duration length}) {
    final int total = _samplesIn(length);
    final math.Random hasard = math.Random(seed);

    // Pistes de hauteur et d'amplitude, puis un seul oscillateur : la phase
    // reste continue d'une note liee a la suivante, comme sur une corde.
    final Float64List hauteur = Float64List(total);
    final Float64List amplitude = Float64List(total);
    final Float64List sortie = Float64List(total);

    final List<BowedNote> triees = List<BowedNote>.of(notes)
      ..sort((BowedNote a, BowedNote b) => a.start.compareTo(b.start));

    for (int i = 0; i < triees.length; i++) {
      final BowedNote note = triees[i];
      final BowedNote? avant = i > 0 ? triees[i - 1] : null;
      final BowedNote? apres = i + 1 < triees.length ? triees[i + 1] : null;
      final bool lieeAvant = avant != null && !note.attack;
      final bool lieeApres = apres != null && !apres.attack;

      final int debut = _samplesIn(note.start);
      final int fin = math.min(total, _samplesIn(note.end));
      final int longueur = fin - debut;
      for (int k = debut; k < fin; k++) {
        final double t = (k - debut) / sampleRate;
        final double reste = (fin - k) / sampleRate;

        double midi = note.midi;
        if (lieeAvant && t < _glideSeconds) {
          final double x = t / _glideSeconds;
          midi = avant.midi + (note.midi - avant.midi) * x * x * (3 - 2 * x);
        }
        if (note.vibratoCents > 0 && t > _vibratoDelaySeconds) {
          final double entree = math.min(
            1,
            (t - _vibratoDelaySeconds) / _vibratoRampSeconds,
          );
          midi += note.vibratoCents /
              100 *
              entree *
              math.sin(2 * math.pi * _vibratoHz * t);
        }

        double enveloppe = 1;
        if (!lieeAvant) {
          enveloppe = math.min(enveloppe, t / _attackSeconds);
        }
        if (!lieeApres) {
          enveloppe = math.min(enveloppe, reste / _releaseSeconds);
        }
        hauteur[k] = midi;
        amplitude[k] = note.amplitude * enveloppe;
      }

      if (!lieeAvant) {
        _gratter(sortie, debut, longueur, note.amplitude, hasard);
      }
    }

    _oscillateur(sortie, hauteur, amplitude, hasard);
    _bruitDeFond(sortie, hasard);

    return Float32List.fromList(<double>[
      for (final double v in sortie) v.clamp(-1.0, 1.0),
    ]);
  }

  void _oscillateur(
    Float64List sortie,
    Float64List hauteur,
    Float64List amplitude,
    math.Random hasard,
  ) {
    // Le timbre est tire une fois pour toute la prise : c'est le meme
    // instrument d'un bout a l'autre. La fondamentale garde son poids, les
    // autres harmoniques varient autour d'une dent de scie.
    final List<double> poids = <double>[
      for (int h = 1; h <= _maxHarmonics; h++)
        h == 1 ? 1.0 : (0.5 + hasard.nextDouble()) / h,
    ];
    final double norme =
        poids.fold<double>(0, (double a, double b) => a + b) / 2;

    double phase = 0;
    for (int k = 0; k < sortie.length; k++) {
      if (amplitude[k] <= 0) {
        continue;
      }
      final double frequence = a4 * math.pow(2, (hauteur[k] - 69) / 12);
      phase += 2 * math.pi * frequence / sampleRate;
      if (phase > 2 * math.pi) {
        phase -= 2 * math.pi;
      }
      // Rien au-dessus de la moitie de Nyquist : un harmonique replie
      // retomberait dans le grave et fabriquerait une hauteur qui n'existe pas.
      final int harmoniques = math.min(
        _maxHarmonics,
        (0.45 * sampleRate / frequence).floor(),
      );
      double v = 0;
      for (int h = 1; h <= harmoniques; h++) {
        v += poids[h - 1] * math.sin(h * phase);
      }
      sortie[k] += amplitude[k] * v / norme;
    }
  }

  /// Le grattement de l'archet qui mord la corde : un bruit bref, aigu, qui
  /// s'eteint en quelques dizaines de millisecondes.
  void _gratter(
    Float64List sortie,
    int debut,
    int longueur,
    double amplitude,
    math.Random hasard,
  ) {
    final int duree =
        math.min(longueur, (_scratchSeconds * sampleRate).round());
    double precedent = 0;
    for (int i = 0; i < duree; i++) {
      final double bruit = hasard.nextDouble() * 2 - 1;
      // Une difference premiere : le grattement est aigu, pas sourd.
      final double aigu = bruit - precedent;
      precedent = bruit;
      final double descente = math.exp(-5 * i / duree);
      sortie[debut + i] += 0.15 * amplitude * descente * aigu;
    }
  }

  void _bruitDeFond(Float64List sortie, math.Random hasard) {
    if (noiseRms <= 0) {
      return;
    }
    for (int k = 0; k < sortie.length; k++) {
      sortie[k] += noiseRms * _gaussienne(hasard);
    }
  }

  static double _gaussienne(math.Random hasard) {
    // Box-Muller. 1 - x plutot que x : nextDouble peut rendre zero, dont le
    // logarithme est infini.
    final double u = 1 - hasard.nextDouble();
    final double v = hasard.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  int _samplesIn(Duration d) => d.inMicroseconds * sampleRate ~/ 1000000;
}
