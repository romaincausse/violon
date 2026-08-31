import 'dart:typed_data';

/// Decoupe un flux d'octets PCM en trames de taille fixe.
///
/// Le micro livre les octets par paquets de taille arbitraire, decidee par le
/// systeme : 1764 octets ici, 4096 la, parfois un nombre impair. YIN, lui,
/// veut exactement 2048 echantillons a chaque fois. C'est cette classe qui
/// fait le pont, et c'est la seule partie de la chaine audio qu'on peut
/// tester sans micro.
///
/// **Le temps se calcule, il ne s'accumule pas.** L'horodatage d'une trame se
/// deduit du nombre total d'echantillons deja produits : additionner une
/// duree de trame a chaque tour deriverait, exactement comme un metronome
/// bati sur un `Timer`.
class PcmFramer {
  PcmFramer({this.frameSize = 2048, this.sampleRate = 44100})
      : assert(frameSize > 0, 'frameSize doit etre > 0'),
        assert(sampleRate > 0, 'sampleRate doit etre > 0');

  /// Taille d'une trame, en echantillons. 2048 a 44,1 kHz, soit 46 ms :
  /// assez long pour que YIN voie deux periodes d'un sol3, assez court pour
  /// que le retour visuel reste vivant.
  final int frameSize;

  final int sampleRate;

  /// Reste d'un paquet precedent : un demi-echantillon a cheval sur deux
  /// paquets, ou une trame incomplete.
  final List<double> _attente = <double>[];
  int? _octetOrphelin;
  int _echantillonsEmis = 0;

  /// Echantillons produits depuis le dernier [reset].
  int get emittedSamples => _echantillonsEmis;

  /// Echantillons en attente, insuffisants pour completer une trame.
  int get pendingSamples => _attente.length;

  /// Ajoute un paquet d'octets PCM 16 bits signes, petit-boutiste, mono, et
  /// rend les trames completes qu'il permet de former.
  ///
  /// Un paquet peut en produire zero, une, ou plusieurs.
  List<PcmFrame> addBytes(Uint8List bytes) {
    int i = 0;
    // Un paquet peut se terminer au milieu d'un echantillon. On garde alors
    // l'octet de poids faible pour le recoller au paquet suivant : le jeter
    // decalerait tout le reste du flux d'un octet, et le signal deviendrait
    // du bruit.
    if (_octetOrphelin != null && bytes.isNotEmpty) {
      _attente.add(_versDouble(_octetOrphelin!, bytes[0]));
      _octetOrphelin = null;
      i = 1;
    }
    for (; i + 1 < bytes.length; i += 2) {
      _attente.add(_versDouble(bytes[i], bytes[i + 1]));
    }
    if (i < bytes.length) {
      _octetOrphelin = bytes[i];
    }

    final List<PcmFrame> trames = <PcmFrame>[];
    while (_attente.length >= frameSize) {
      final Float32List trame = Float32List(frameSize);
      for (int k = 0; k < frameSize; k++) {
        trame[k] = _attente[k];
      }
      _attente.removeRange(0, frameSize);
      trames.add(
        PcmFrame(
          samples: trame,
          // L'horodatage est celui du **debut** de la trame.
          timestampMs: _echantillonsEmis * 1000 ~/ sampleRate,
        ),
      );
      _echantillonsEmis += frameSize;
    }
    return trames;
  }

  /// Oublie tout : a appeler entre deux prises.
  void reset() {
    _attente.clear();
    _octetOrphelin = null;
    _echantillonsEmis = 0;
  }

  /// Deux octets petit-boutistes vers un flottant dans [-1, 1].
  ///
  /// La division est par 32768 et non 32767 : c'est la valeur absolue du
  /// minimum d'un entier 16 bits signe, donc la seule qui ne puisse pas
  /// deborder.
  static double _versDouble(int faible, int fort) {
    final int brut = (fort << 8) | faible;
    final int signe = brut >= 0x8000 ? brut - 0x10000 : brut;
    return signe / 32768.0;
  }
}

/// Une trame prete pour l'analyse.
class PcmFrame {
  const PcmFrame({required this.samples, required this.timestampMs});

  final Float32List samples;

  /// Instant du premier echantillon de la trame, depuis le debut de la prise.
  final int timestampMs;
}
