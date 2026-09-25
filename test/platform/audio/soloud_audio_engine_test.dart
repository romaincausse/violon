import 'package:flutter_test/flutter_test.dart';
import 'package:violon/platform/audio/soloud_audio_engine.dart';

void main() {
  group('SoloudAudioEngine', () {
    test('un moteur jamais demarre ne touche pas la bibliotheque native',
        () async {
      // Ce test n'a l'air de rien et il en attrape un vrai : construire
      // `SoLoud` charge un `.so` absent de la machine virtuelle de test. Tant
      // que ce moteur n'a pas eu a sonner, il ne doit donc rien resoudre --
      // sinon tout test de widget qui monte l'application echoue, et
      // l'application reveille le haut-parleur au lancement.
      final SoloudAudioEngine moteur = SoloudAudioEngine();
      expect(moteur.isRunning, isFalse);
      await moteur.stopAll();
      await moteur.dispose();
      expect(moteur.isRunning, isFalse);
    });

    test('la frequence d echantillonnage est fixee, pas devinee', () {
      // SoLoud garde la sienne privee : un clic planifie a partir d'une
      // frequence supposee tomberait a cote.
      expect(SoloudAudioEngine.sampleRate, 44100);
    });
  });
}
