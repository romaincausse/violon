import 'dart:math' as math;
import 'dart:typed_data';

/// Les dernieres secondes jouees, gardees pour etre reecoutees.
///
/// **S'entendre est l'exercice le plus efficace qui soit**, et le plus
/// desagreable : on joue toujours moins juste qu'on ne le croyait. Le mode
/// libre est le seul endroit du projet ou il a sa place -- on n'y note rien,
/// donc s'y entendre n'est pas une sanction de plus.
///
/// **Rien a armer.** La prise tourne en permanence sur une fenetre glissante :
/// l'enfant joue, puis appuie une fois pour s'entendre. Un bouton
/// "enregistrer" couterait trois gestes, archet en main, et il oublierait de
/// l'appuyer avant la seule phrase qui valait la peine.
///
/// **Rien ne sort du telephone, et rien n'y reste.** La prise vit en memoire
/// et meurt avec l'ecran : pas de fichier, pas de dossier, pas de
/// permission de stockage.
class PcmTake {
  PcmTake({
    this.sampleRate = 44100,
    this.maxSeconds = 20,
    this.silenceThreshold = 0.012,
    this.keepMs = 250,
  })  : assert(sampleRate > 0, 'une frequence d echantillonnage est positive'),
        assert(maxSeconds > 0, 'une fenetre dure un temps positif');

  final int sampleRate;

  /// Duree gardee, en secondes.
  ///
  /// Vingt secondes font moins de deux megaoctets en 16 bits mono, et
  /// couvrent largement une phrase. Au-dela on garderait surtout du silence.
  final int maxSeconds;

  /// En dessous de cette amplitude efficace, on considere qu'on n'entend rien.
  ///
  /// Rapporte a la pleine echelle : 0,012 vaut environ -38 dB, bien en dessous
  /// d'un violon dans une piece et bien au-dessus du bruit d'une dalle.
  final double silenceThreshold;

  /// Silence garde de part et d'autre du son, en millisecondes.
  ///
  /// Couper au ras de la premiere attaque mange le debut du coup d'archet et
  /// fait commencer la relecture par un clic.
  final int keepMs;

  final List<({Uint8List octets, bool sonore})> _morceaux =
      <({Uint8List octets, bool sonore})>[];
  int _octets = 0;
  int _sonores = 0;

  int get _octetsMax => sampleRate * 2 * maxSeconds;

  bool get isEmpty => _octets == 0;

  /// A-t-on entendu quelque chose dans la fenetre ?
  ///
  /// **Tenu au fil de l'eau, pas calcule a la demande.** Le bouton s'allume
  /// ou s'eteint a chaque image : rebalayer deux megaoctets pour savoir s'il
  /// doit etre gris reviendrait a payer le silence tres cher. Le decoupage
  /// fin, lui, n'a lieu qu'au moment ou l'on appuie.
  bool get hasSound => _sonores > 0;

  /// Duree actuellement gardee.
  Duration get duration => Duration(
        milliseconds: (_octets / 2 / sampleRate * 1000).round(),
      );

  /// Ajoute des octets PCM 16 bits signes, petit-boutistes, mono.
  void add(Uint8List octets) {
    if (octets.isEmpty) {
      return;
    }
    final bool sonore = _sonore(octets);
    _morceaux.add((octets: octets, sonore: sonore));
    _octets += octets.length;
    if (sonore) {
      _sonores++;
    }
    // On jette par morceau entier plutot qu'a l'octet pres : une decoupe au
    // milieu d'un echantillon inverserait les deux octets d'un mot et
    // produirait un craquement.
    while (_octets - _morceaux.first.octets.length >= _octetsMax) {
      final ({Uint8List octets, bool sonore}) parti = _morceaux.removeAt(0);
      _octets -= parti.octets.length;
      if (parti.sonore) {
        _sonores--;
      }
    }
  }

  bool _sonore(Uint8List octets) {
    final int pairs = octets.length - (octets.length % 2);
    if (pairs == 0) {
      return false;
    }
    final Int16List e = Int16List.sublistView(octets, 0, pairs);
    return _efficace(e, 0, e.length) >= silenceThreshold;
  }

  void reset() {
    _morceaux.clear();
    _octets = 0;
    _sonores = 0;
  }

  /// Ce qui vient d'etre joue, en WAV, silences de bord retires.
  ///
  /// Rend `null` si la fenetre ne contient aucun son : il n'y a alors rien a
  /// reecouter, et mieux vaut le dire que jouer vingt secondes de rien.
  Uint8List? wav() {
    if (isEmpty) {
      return null;
    }
    final Int16List echantillons = _echantillons();
    final (int, int)? bornes = _bornesDuSon(echantillons);
    if (bornes == null) {
      return null;
    }
    final (int debut, int fin) = bornes;
    return _enveloppeWav(
      Int16List.sublistView(echantillons, debut, fin),
    );
  }

  Int16List _echantillons() {
    final Uint8List plat = Uint8List(_octets);
    int ou = 0;
    for (final ({Uint8List octets, bool sonore}) morceau in _morceaux) {
      plat.setRange(ou, ou + morceau.octets.length, morceau.octets);
      ou += morceau.octets.length;
    }
    // `sublistView` exige un decalage pair ; un flux d'octets PCM 16 bits
    // l'est toujours, mais une trame tronquee par le materiel ne le serait
    // pas.
    final int pairs = plat.length - (plat.length % 2);
    return Int16List.sublistView(plat, 0, pairs);
  }

  /// Premier et dernier echantillon a garder, ou `null` si tout est silence.
  (int, int)? _bornesDuSon(Int16List echantillons) {
    const int fenetre = 1024;
    int? premier;
    int? dernier;
    for (int i = 0; i + fenetre <= echantillons.length; i += fenetre) {
      if (_efficace(echantillons, i, fenetre) < silenceThreshold) {
        continue;
      }
      premier ??= i;
      dernier = i + fenetre;
    }
    if (premier == null || dernier == null) {
      return null;
    }
    final int marge = sampleRate * keepMs ~/ 1000;
    return (
      math.max(0, premier - marge),
      math.min(echantillons.length, dernier + marge),
    );
  }

  double _efficace(Int16List echantillons, int depuis, int combien) {
    double somme = 0;
    for (int i = depuis; i < depuis + combien; i++) {
      final double v = echantillons[i] / 32768;
      somme += v * v;
    }
    return math.sqrt(somme / combien);
  }

  /// Habille le PCM des quarante-quatre octets d'en-tete d'un WAV.
  ///
  /// **Un conteneur, pas un encodage.** Le moteur de son sait lire un WAV
  /// depuis la memoire ; il ne sait pas lire du PCM nu. Ces quarante-quatre
  /// octets sont donc tout ce qui separe ce qu'on a capture de ce qu'on peut
  /// rejouer -- et ils s'ecrivent en Dart pur, sans rien ajouter au
  /// `pubspec`.
  Uint8List _enveloppeWav(Int16List echantillons) {
    const int entete = 44;
    final int donnees = echantillons.length * 2;
    final ByteData sortie = ByteData(entete + donnees);

    void texte(int ou, String quatre) {
      for (int i = 0; i < 4; i++) {
        sortie.setUint8(ou + i, quatre.codeUnitAt(i));
      }
    }

    texte(0, 'RIFF');
    sortie.setUint32(4, 36 + donnees, Endian.little);
    texte(8, 'WAVE');
    texte(12, 'fmt ');
    sortie.setUint32(16, 16, Endian.little); // taille du bloc fmt
    sortie.setUint16(20, 1, Endian.little); // PCM
    sortie.setUint16(22, 1, Endian.little); // mono
    sortie.setUint32(24, sampleRate, Endian.little);
    sortie.setUint32(28, sampleRate * 2, Endian.little); // octets par seconde
    sortie.setUint16(32, 2, Endian.little); // octets par bloc
    sortie.setUint16(34, 16, Endian.little); // bits par echantillon
    texte(36, 'data');
    sortie.setUint32(40, donnees, Endian.little);
    for (int i = 0; i < echantillons.length; i++) {
      sortie.setInt16(entete + i * 2, echantillons[i], Endian.little);
    }
    return sortie.buffer.asUint8List();
  }
}
