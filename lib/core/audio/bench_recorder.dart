import 'dart:async';

/// Enregistre les prises du banc d'essai (jalon 5, lot P1).
///
/// **Un outil de developpement, pas une fonctionnalite.** L'application ne
/// garde aucun enregistrement (`docs/professeur.md`) ; celui-ci n'existe que
/// dans la version de debug, le temps de constituer le banc, et ses fichiers
/// quittent le telephone par `tool/prises.sh` qui les efface derriere lui.
///
/// Il passe par le meme micro que l'application, source comprise : un banc
/// enregistre autrement mesurerait un autre micro (`docs/banc-d-essai.md`).
abstract class BenchRecorder {
  Future<bool> hasPermission();

  /// Commence la prise [name], en WAV 16 bits mono 44 100 Hz.
  ///
  /// Un nom deja pris recoit un suffixe (`-2`, `-3`) : la prise 7 se capte
  /// plusieurs fois, et aucune ne doit en effacer une autre.
  Future<void> start(String name);

  /// Le niveau en dBFS, pendant la prise : 0 est la saturation.
  Stream<double> level();

  /// Termine la prise en cours, et la rend.
  Future<BenchTake?> stop();

  /// Les prises encore sur le telephone, de la plus ancienne a la plus
  /// recente.
  Future<List<BenchTake>> takes();

  Future<void> delete(String name);

  Future<void> dispose();
}

/// Fabrique de l'enregistreur. `null` hors debug : l'outil n'existe pas.
typedef BenchRecorderFactory = BenchRecorder Function();

/// Une prise posee sur le telephone.
class BenchTake {
  const BenchTake({required this.name, required this.bytes});

  /// Sans extension : c'est l'identifiant de la prise dans le banc.
  final String name;
  final int bytes;

  /// Deduite de la taille : 44 octets d'en-tete, puis 2 octets par
  /// echantillon a 44 100 Hz.
  Duration get duration => Duration(
        microseconds: ((bytes - 44).clamp(0, bytes) / 2 / 44100 * 1e6).round(),
      );
}

/// Le nom libre suivant pour [name], parmi [existants].
String nomLibre(String name, Iterable<String> existants) {
  final Set<String> pris = existants.toSet();
  if (!pris.contains(name)) {
    return name;
  }
  int n = 2;
  while (pris.contains('$name-$n')) {
    n++;
  }
  return '$name-$n';
}

/// Enregistreur factice : il pose des prises d'une seconde par appel.
class FakeBenchRecorder implements BenchRecorder {
  FakeBenchRecorder({this.permission = true});

  final bool permission;
  final List<BenchTake> _prises = <BenchTake>[];
  final StreamController<double> niveaux = StreamController<double>.broadcast();
  String? enCours;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start(String name) async {
    enCours = nomLibre(name, _prises.map((BenchTake t) => t.name));
  }

  @override
  Stream<double> level() => niveaux.stream;

  @override
  Future<BenchTake?> stop() async {
    final String? nom = enCours;
    if (nom == null) {
      return null;
    }
    enCours = null;
    final BenchTake prise = BenchTake(name: nom, bytes: 44 + 88200);
    _prises.add(prise);
    return prise;
  }

  @override
  Future<List<BenchTake>> takes() async => List<BenchTake>.of(_prises);

  @override
  Future<void> delete(String name) async =>
      _prises.removeWhere((BenchTake t) => t.name == name);

  @override
  Future<void> dispose() async {
    disposed = true;
    await niveaux.close();
  }
}
