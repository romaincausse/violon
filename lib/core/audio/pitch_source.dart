import 'pitch_estimate.dart';

/// Frontiere entre l'application et le materiel audio.
///
/// C'est la SEULE couche a reecrire pour porter l'application sur iOS, et
/// la seule a remplacer pour developper l'interface sous Flutter Web ou
/// pour ecrire des tests deterministes. Rien au-dessus ne doit connaitre
/// le micro.
abstract class PitchSource {
  /// Flux de hauteurs detectees. Les silences ne produisent rien.
  Stream<PitchEstimate> get pitches;

  /// Latence entree/sortie mesuree lors de la calibration, en millisecondes.
  /// Necessaire pour noter le rythme : sans elle, tout parait en retard.
  int get latencyMs;

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
