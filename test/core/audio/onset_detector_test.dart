import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/onset_detector.dart';

const int sampleRate = 44100;

/// Synthetise une note : attaque franche, puis decroissance, comme un coup
/// d'archet. C'est l'enveloppe qui fait l'attaque, pas la hauteur.
void ecrireNote(
  List<double> sortie,
  int debutEchantillon,
  int dureeEchantillons,
  double frequenceHz, {
  double amplitude = 0.3,
}) {
  for (int i = 0; i < dureeEchantillons; i++) {
    final int n = debutEchantillon + i;
    if (n >= sortie.length) {
      return;
    }
    // Montee tres rapide sur 2 ms, decroissance lente, et surtout une
    // extinction de 5 ms a la fin : couper le son net produit un clic large
    // bande que le detecteur prend a juste titre pour une attaque. Ce serait
    // un defaut du signal de test, pas du detecteur.
    final double montee = math.min(1, i / (sampleRate * 0.002));
    final double descente = math.exp(-i / (sampleRate * 0.35));
    final double extinction =
        math.min(1, (dureeEchantillons - i) / (sampleRate * 0.005));
    sortie[n] += amplitude *
        montee *
        descente *
        extinction *
        math.sin(2 * math.pi * frequenceHz * n / sampleRate);
  }
}

Float32List signalDe(List<double> echantillons) =>
    Float32List.fromList(echantillons);

int msVersEchantillons(int ms) => ms * sampleRate ~/ 1000;

void main() {
  group('OnsetDetector', () {
    test('le silence ne produit aucune attaque', () {
      final OnsetDetector d = OnsetDetector();
      expect(d.addSamples(Float32List(sampleRate)), isEmpty);
    });

    test('un souffle faible ne produit aucune attaque', () {
      // Le seuil est relatif a la mediane recente : sans plancher absolu, le
      // bruit d'une piece calme la depasserait d'un facteur dix.
      final math.Random hasard = math.Random(1789);
      final Float32List bruit = Float32List(sampleRate);
      for (int i = 0; i < bruit.length; i++) {
        bruit[i] = (hasard.nextDouble() * 2 - 1) * 0.0005;
      }
      expect(OnsetDetector().addSamples(bruit), isEmpty);
    });

    test('une note isolee produit exactement une attaque', () {
      final List<double> signal = List<double>.filled(sampleRate, 0);
      ecrireNote(signal, msVersEchantillons(200), msVersEchantillons(400), 440);

      final List<Onset> onsets = OnsetDetector().addSamples(signalDe(signal));
      expect(onsets, hasLength(1));
      expect(onsets.single.timestampMs, closeTo(200, 30));
    });

    test('un son tenu ne declenche qu au debut', () {
      // Une note qui dure fort ne doit pas produire une attaque par trame :
      // c'est la hausse du spectre qui compte, pas son niveau.
      // Le son commence apres un peu de silence : une note deja en cours au
      // premier echantillon n'a pas d'attaque detectable, faute de "avant"
      // a quoi la comparer.
      final List<double> signal = List<double>.filled(sampleRate * 2, 0);
      const int debut = sampleRate ~/ 10;
      for (int i = debut; i < signal.length; i++) {
        final double montee = math.min(1, (i - debut) / (sampleRate * 0.002));
        signal[i] = 0.3 * montee * math.sin(2 * math.pi * 440 * i / sampleRate);
      }
      expect(OnsetDetector().addSamples(signalDe(signal)), hasLength(1));
    });

    test('deux notes de hauteurs differentes font deux attaques', () {
      final List<double> signal = List<double>.filled(sampleRate * 2, 0);
      ecrireNote(signal, msVersEchantillons(100), msVersEchantillons(400), 440);
      ecrireNote(signal, msVersEchantillons(600), msVersEchantillons(400), 523);

      final List<Onset> onsets = OnsetDetector().addSamples(signalDe(signal));
      expect(onsets, hasLength(2));
      expect(onsets[0].timestampMs, closeTo(100, 30));
      expect(onsets[1].timestampMs, closeTo(600, 30));
    });

    test('deux notes de LA MEME hauteur font deux attaques', () {
      // La raison d'etre du lot. YIN ne voit rien ici : l'autocorrelation est
      // identique d'un archet a l'autre. Sans ce detecteur, deux croches sur
      // la meme note passeraient pour une blanche.
      final List<double> signal = List<double>.filled(sampleRate * 2, 0);
      ecrireNote(signal, msVersEchantillons(100), msVersEchantillons(400), 440);
      ecrireNote(signal, msVersEchantillons(600), msVersEchantillons(400), 440);

      final List<Onset> onsets = OnsetDetector().addSamples(signalDe(signal));
      expect(onsets, hasLength(2));
      expect(onsets[1].timestampMs - onsets[0].timestampMs, closeTo(500, 40));
    });

    test('une note rearticulee sans silence fait deux attaques', () {
      // Le cas dur : la seconde note commence pendant que la premiere resonne
      // encore. C'est ce que fait un violon a l'archet, sans lever le doigt.
      final List<double> signal = List<double>.filled(sampleRate * 2, 0);
      ecrireNote(signal, msVersEchantillons(100), msVersEchantillons(900), 440);
      ecrireNote(signal, msVersEchantillons(450), msVersEchantillons(900), 440);

      final List<Onset> onsets = OnsetDetector().addSamples(signalDe(signal));
      expect(onsets, hasLength(2));
      expect(onsets[1].timestampMs, closeTo(450, 40));
    });

    test('une seule attaque ne compte pas double', () {
      // Une attaque de violon s'etale sur plusieurs trames et produit des
      // pics rapproches. L'intervalle minimal les fond en une seule.
      final List<double> signal = List<double>.filled(sampleRate, 0);
      ecrireNote(signal, msVersEchantillons(200), msVersEchantillons(600), 440);

      final List<Onset> onsets =
          OnsetDetector(minIntervalMs: 50).addSamples(signalDe(signal));
      expect(onsets, hasLength(1));
    });

    test('le decoupage du flux ne change pas le resultat', () {
      // Le micro livre des paquets de taille arbitraire. Le detecteur doit
      // voir un flux continu, pas des trames independantes.
      final List<double> signal = List<double>.filled(sampleRate * 2, 0);
      ecrireNote(signal, msVersEchantillons(100), msVersEchantillons(400), 440);
      ecrireNote(signal, msVersEchantillons(700), msVersEchantillons(400), 440);

      final List<Onset> dUnBloc = OnsetDetector().addSamples(signalDe(signal));

      final OnsetDetector morceaux = OnsetDetector();
      final List<Onset> parPaquets = <Onset>[];
      int i = 0;
      int taille = 333; // Une taille volontairement mal alignee.
      while (i < signal.length) {
        final int fin = math.min(i + taille, signal.length);
        parPaquets.addAll(
          morceaux.addSamples(signalDe(signal.sublist(i, fin))),
        );
        i = fin;
        taille = taille == 333 ? 1777 : 333;
      }

      expect(
        parPaquets.map((Onset o) => o.timestampMs).toList(),
        dUnBloc.map((Onset o) => o.timestampMs).toList(),
      );
    });

    test('une attaque douce est vue autant qu une attaque forte', () {
      // Le seuil est relatif : un enfant qui joue piano produit des attaques
      // dix fois plus faibles, et elles doivent compter autant.
      List<Onset> detecter(double amplitude) {
        final List<double> signal = List<double>.filled(sampleRate, 0);
        ecrireNote(
          signal,
          msVersEchantillons(200),
          msVersEchantillons(600),
          440,
          amplitude: amplitude,
        );
        return OnsetDetector().addSamples(signalDe(signal));
      }

      expect(detecter(0.4), hasLength(1));
      expect(detecter(0.04), hasLength(1));
    });

    test('remettre a zero oublie la prise precedente', () {
      final List<double> signal = List<double>.filled(sampleRate, 0);
      ecrireNote(signal, msVersEchantillons(200), msVersEchantillons(400), 440);

      final OnsetDetector d = OnsetDetector();
      final List<Onset> premiere = d.addSamples(signalDe(signal));
      d.reset();
      final List<Onset> seconde = d.addSamples(signalDe(signal));

      expect(seconde.map((Onset o) => o.timestampMs),
          premiere.map((Onset o) => o.timestampMs));
    });

    test('la resolution vaut moins de six millisecondes', () {
      // C'est tout l'interet d'une decoupe propre : les trames de 2048 de la
      // detection de hauteur donneraient 46 ms, sans commune mesure avec ce
      // qu'il faut pour noter un rythme.
      final OnsetDetector d = OnsetDetector();
      expect(d.hopSize * 1000 / d.sampleRate, lessThan(6));
    });
  });
}
