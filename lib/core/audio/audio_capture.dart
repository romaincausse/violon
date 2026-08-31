import 'dart:typed_data';

/// Source physique du micro, cote Android.
///
/// Le choix n'est pas un detail de configuration : c'est la contrainte
/// numero un du projet. Le mode par defaut applique un gain automatique et
/// une reduction de bruit calibres pour la parole. Sur un son tenu de violon,
/// le gain pompe et la reduction de bruit prend le vibrato pour du souffle :
/// la hauteur detectee devient instable.
enum MicSource {
  /// Signal brut, sans traitement. Ce qu'on veut.
  unprocessed,

  /// Repli : moins traite que le mode par defaut, disponible partout.
  voiceRecognition,
}

/// Capture d'octets audio bruts.
///
/// Deliberement plus bas niveau que [PitchSource] : cette interface ne connait
/// que des octets, pas des hauteurs. C'est le seul endroit qu'un portage iOS
/// ou un remplacement de paquet doit reecrire ; tout le traitement du signal
/// vit au-dessus, en Dart pur, et se teste sans micro.
abstract class AudioCapture {
  /// L'utilisateur a-t-il accorde l'acces au micro ? Peut ouvrir la boite de
  /// dialogue systeme.
  Future<bool> hasPermission();

  /// Ouvre le micro et rend un flux d'octets PCM 16 bits signes,
  /// petit-boutiste, mono.
  ///
  /// Leve une exception si la source demandee est refusee par l'appareil.
  Future<Stream<Uint8List>> start({
    required int sampleRate,
    required MicSource source,
  });

  Future<void> stop();

  Future<void> dispose();
}
