import 'dart:async';
import 'dart:typed_data';

/// Rejoue ce qui vient d'etre joue.
///
/// **La troisieme frontiere avec le materiel audio**, apres [AudioCapture] en
/// entree et `AudioEngine` en sortie. Elle existe a part parce que
/// `AudioEngine` refuse volontairement de charger quoi que ce soit (ADR-012) :
/// il tient une note et pose un clic, et lui demander de lire un tampon
/// l'ouvrirait a tout le reste. Une interface de plus coute moins cher qu'une
/// interface qui ne veut plus rien dire.
///
/// L'interface vit dans `lib/core/` et n'importe aucun paquet : elle decrit un
/// besoin, pas une implementation.
abstract class TakePlayer {
  /// Joue [wav] et rend la main **quand le son est fini**.
  ///
  /// C'est ce que l'appelant attend pour rouvrir le micro : l'application
  /// emet ou ecoute, jamais les deux (ADR-008).
  Future<void> play(Uint8List wav);

  /// Coupe la relecture en cours, s'il y en a une.
  Future<void> stop();

  Future<void> dispose();
}

/// Fabrique du liseur, injectable comme celles du micro et du moteur.
typedef TakePlayerFactory = TakePlayer Function();

/// Liseur factice : il note ce qu'on lui a demande, et ne sonne pas.
class FakeTakePlayer implements TakePlayer {
  final List<Uint8List> joues = <Uint8List>[];
  int arrets = 0;
  bool disposed = false;

  /// Ce qui retient la lecture en cours, pour qu'un test puisse observer
  /// l'ecran **pendant** qu'on se reecoute.
  Completer<void>? _enCours;

  bool get enTrainDeJouer => _enCours != null && !_enCours!.isCompleted;

  /// Laisse la lecture se terminer.
  void terminer() {
    _enCours?.complete();
    _enCours = null;
  }

  @override
  Future<void> play(Uint8List wav) {
    joues.add(wav);
    final Completer<void> attente = Completer<void>();
    _enCours = attente;
    return attente.future;
  }

  @override
  Future<void> stop() async {
    arrets++;
    terminer();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    terminer();
  }
}
