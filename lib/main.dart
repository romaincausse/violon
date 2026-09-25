import 'package:flutter/material.dart';

import 'core/music/demo_passage.dart';
import 'core/music/passage.dart';
import 'core/music/pitch_utils.dart';
import 'core/play/audio_engine.dart';
import 'platform/audio/default_pitch_source.dart';
import 'platform/audio/soloud_audio_engine.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/session_screen.dart' show PitchSourceFactory;

void main() {
  runApp(const ViolonApp());
}

class ViolonApp extends StatefulWidget {
  const ViolonApp({
    this.pitchSourceFactory = defaultPitchSource,
    this.audioEngineFactory = defaultAudioEngine,
    super.key,
  });

  /// Fabrique de la source de hauteurs, traversee jusqu'aux ecrans qui
  /// ecoutent.
  ///
  /// Injectable pour la meme raison qu'ailleurs : un test de widget n'a pas
  /// de micro, et faire tourner la vraie chaine audio a chaque `pumpWidget`
  /// lancerait un isolate pour rien.
  final PitchSourceFactory pitchSourceFactory;

  /// Fabrique du moteur de son, injectable pour la meme raison : un test de
  /// widget n'a pas de haut-parleur.
  final AudioEngineFactory audioEngineFactory;

  @override
  State<ViolonApp> createState() => _ViolonAppState();
}

class _ViolonAppState extends State<ViolonApp> {
  /// Le passage de demonstration sert de point de depart.
  ///
  /// **Dix secondes, c'est la duree au-dela de laquelle un enfant repose le
  /// violon.** Imposer une saisie a chaque lancement mettrait la friction
  /// exactement la ou le projet cherche a en enlever : on ouvre, on joue.
  ///
  /// Tant que la persistance n'existe pas (lot H1), c'est la demo qui sert de
  /// point de depart plutot que le travail de la veille.
  Passage _passage = buildDemoPassage();

  /// Diapason de reference, adopte depuis l'accordeur.
  ///
  /// Tant que la persistance n'existe pas (lot H1), il ne survit pas a la
  /// fermeture : mieux vaut le remesurer que de le sauvegarder a moitie.
  double _a4 = PitchUtils.defaultA4;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Violon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6D4C41),
        useMaterial3: true,
      ),
      // Aucun ecran d'accueil : l'application s'ouvre sur le travail en cours.
      home: HomeShell(
        pitchSourceFactory: widget.pitchSourceFactory,
        audioEngineFactory: widget.audioEngineFactory,
        passage: _passage,
        a4: _a4,
        onPassageChanged: (Passage p) => setState(() => _passage = p),
        onA4Changed: (double a4) => setState(() => _a4 = a4),
      ),
    );
  }
}
