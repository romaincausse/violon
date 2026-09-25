import 'metronome_clock.dart';

/// Timbre d'un bourdon.
///
/// Une sinusoide pure est le pire choix possible ici : elle n'a pas
/// d'harmoniques, donc **presque pas de battements** avec la note de l'eleve,
/// et le battement est tout l'interet du bourdon. La dent de scie en a
/// beaucoup, comme une corde frottee.
enum DroneTimbre { sinus, dentDeScie, triangle }

/// Ce que l'application demande a un moteur de son.
///
/// **La seule frontiere de sortie audio**, symetrique de [PitchSource] en
/// entree : rien au-dessus ne connait le moteur. C'est aussi la seule couche a
/// reecrire pour porter sur iOS.
///
/// L'interface vit dans `lib/core/` et n'importe aucun paquet : elle decrit un
/// besoin, pas une implementation. Tout ce qui est au-dessus se teste donc avec
/// [FakeAudioEngine], sans appareil et sans haut-parleur.
///
/// **Ce qu'on ne lui demande pas.** Ni chargement de fichiers, ni effets, ni
/// spatialisation. Deux choses : tenir une note a une frequence exacte, et
/// poser un clic a un instant exact. Le moteur retenu sait faire bien plus
/// (ADR-012) ; cette interface est ce que le projet s'autorise a en utiliser.
abstract class AudioEngine {
  /// Ouvre le moteur. Idempotent : l'appeler deux fois ne fait rien de plus.
  Future<void> start();

  bool get isRunning;

  /// Tient une note jusqu'a ce qu'on l'arrete.
  ///
  /// [frequencyHz] est une frequence, pas une note : c'est ce qui permet de
  /// sonner au diapason reellement mesure sur les cordes a vide. Un bourdon a
  /// 440 contre un violon accorde a 442 ferait battre l'instrument contre la
  /// reference, ce qui est exactement l'inverse du but.
  Future<DroneVoice> startDrone({
    required double frequencyHz,
    double volume,
    DroneTimbre timbre,
  });

  /// Pose un clic **dans** [delay], compte a partir de maintenant.
  ///
  /// **Planifie, pas declenche.** C'est la difference que le projet exige : un
  /// `Timer` Dart qui joue un clic quand il se reveille derive de facon
  /// audible, parce que son reveil depend de la charge de l'interface. Ici
  /// l'instant est fige dans le moteur des la planification -- ce qui se passe
  /// ensuite du cote Dart ne peut plus le deplacer.
  ///
  /// Corollaire utile : un `Timer` qui se contente de **remplir la file a
  /// l'avance** reste permis, puisque sa gigue ne deplace aucun clic. Voir
  /// [MetronomeScheduler].
  Future<void> scheduleClick({
    required Duration delay,
    PulseAccent accent,
  });

  /// Coupe tout ce qui sonne, y compris les clics deja planifies.
  Future<void> stopAll();

  Future<void> dispose();
}

/// Un bourdon en train de sonner.
abstract class DroneVoice {
  /// Change la note sans couper le son : on cherche sa tonalite en glissant,
  /// pas en rallumant.
  Future<void> setFrequency(double frequencyHz);

  Future<void> setVolume(double volume);

  Future<void> stop();
}

/// Fabrique du moteur, injectable comme l'est celle de la source de hauteurs.
typedef AudioEngineFactory = AudioEngine Function();
