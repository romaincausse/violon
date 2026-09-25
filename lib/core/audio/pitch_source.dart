import 'pitch_estimate.dart';
import 'pitch_smoother.dart';

/// Frontiere entre l'application et le materiel audio.
///
/// C'est la SEULE couche a reecrire pour porter l'application sur iOS, et
/// la seule a remplacer pour developper l'interface sous Flutter Web ou
/// pour ecrire des tests deterministes. Rien au-dessus ne doit connaitre
/// le micro.
abstract class PitchSource {
  /// Flux de hauteurs detectees. Les silences ne produisent rien.
  Stream<PitchEstimate> get pitches;

  /// Le meme flux, avec ce que le lissage a appris au passage : amplitude de
  /// l'oscillation, et vibrato reconnu ou non.
  ///
  /// **Fait partie de la frontiere, et pas d'une implementation.** Tout ce qui
  /// juge un accord en a besoin -- l'accordeur comme la surveillance de
  /// derive -- parce qu'une hauteur qui oscille ne mesure rien. L'exposer ici
  /// evite a l'interface de tester le type reel de la source, ce qui rendait
  /// l'accordeur muet des qu'on developpait avec une source factice.
  Stream<SmoothedPitch> get smoothedPitches;

  /// Latence entree/sortie mesuree lors de la calibration, en millisecondes.
  /// Necessaire pour noter le rythme : sans elle, tout parait en retard.
  int get latencyMs;

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
