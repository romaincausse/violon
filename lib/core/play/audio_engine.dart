import 'instrument.dart';
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
/// **Ce qu'on ne lui demande pas.** Ni effets, ni spatialisation. Tenir une
/// note a une frequence exacte, poser un clic a un instant exact (ADR-012) --
/// et, depuis l'accompagnement (ADR-015), faire sonner un instrument
/// enregistre, a une frequence exacte et a un instant exact sur sa propre
/// horloge. Le moteur retenu sait faire bien plus ; cette interface est ce
/// que le projet s'autorise a en utiliser.
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
  ///
  /// [instrument] remplace le timbre synthetique par un instrument enregistre
  /// qui tient la note (violon, violoncelle, orgue...). `null` : le timbre.
  Future<DroneVoice> startDrone({
    required double frequencyHz,
    double volume,
    DroneTimbre timbre,
    String? instrument,
  });

  /// Les instruments enregistres que ce moteur sait faire sonner.
  Future<InstrumentLibrary> instruments();

  /// Charge les echantillons de [instrument] avant qu'on en ait besoin.
  ///
  /// **A faire avant de planifier**, pas pendant : un echantillon qui se
  /// charge au moment ou sa note doit sonner la ferait sonner en retard.
  Future<void> prepareInstrument(String instrument);

  /// L'instant present sur l'horloge du moteur.
  ///
  /// C'est l'horloge du son lui-meme, pas celle de Dart : tout ce qui se
  /// planifie a partir d'elle tombe a l'echantillon pres, quoi que fasse
  /// l'interface entre-temps.
  Future<Duration> now();

  /// Fait sonner une note de [instrument] a l'instant [at] de l'horloge du
  /// moteur (voir [now]), pendant [duration].
  ///
  /// [frequencyHz] est une frequence, comme pour le bourdon : l'accompagnement
  /// sonne au diapason mesure, sinon il ferait battre le violon contre lui.
  Future<void> scheduleNote({
    required String instrument,
    required Duration at,
    required double frequencyHz,
    required Duration duration,
    double volume,
  });

  /// Pose un clic a l'instant [at] de l'horloge du moteur : le decompte de
  /// l'accompagnement, sur la meme horloge que ses notes.
  Future<void> scheduleClickAt({
    required Duration at,
    PulseAccent accent,
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
