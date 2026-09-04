import 'dart:async';

import 'package:flutter/material.dart';

import 'core/music/demo_passage.dart';
import 'core/music/passage.dart';
import 'core/music/pitch_utils.dart';
import 'platform/audio/default_pitch_source.dart';
import 'ui/screens/passage_editor_screen.dart';
import 'ui/screens/session_screen.dart';
import 'ui/screens/tuner_screen.dart';

void main() {
  runApp(const ViolonApp());
}

class ViolonApp extends StatefulWidget {
  const ViolonApp({this.pitchSourceFactory = defaultPitchSource, super.key});

  /// Fabrique de la source de hauteurs, traversee jusqu'a l'ecran de travail.
  ///
  /// Injectable pour la meme raison qu'ailleurs : un test de widget n'a pas
  /// de micro, et faire tourner la vraie chaine audio a chaque `pumpWidget`
  /// lancerait un isolate pour rien.
  final PitchSourceFactory pitchSourceFactory;

  @override
  State<ViolonApp> createState() => _ViolonAppState();
}

class _ViolonAppState extends State<ViolonApp> {
  /// Le passage de demonstration sert de point de depart.
  ///
  /// Tant que la persistance n'existe pas (lot P4), imposer la saisie a chaque
  /// lancement rendrait l'application penible : on ouvre, on joue. Le passage
  /// saisi remplace la demo pour la duree de la session.
  Passage _passage = buildDemoPassage();

  /// Diapason de reference, adopte depuis l'accordeur.
  ///
  /// Tant que la persistance n'existe pas (lot H1), il ne survit pas a la
  /// fermeture : mieux vaut le remesurer que de le sauvegarder a moitie.
  double _a4 = PitchUtils.defaultA4;

  Future<void> _editPassage(BuildContext context) async {
    final Passage? entered = await Navigator.of(context).push<Passage>(
      MaterialPageRoute<Passage>(
        builder: (BuildContext context) => const PassageEditorScreen(),
      ),
    );
    if (entered != null) {
      setState(() => _passage = entered);
    }
  }

  Future<void> _openTuner(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TunerScreen(
          pitchSourceFactory: widget.pitchSourceFactory,
          a4: _a4,
          onA4Changed: (double a4) => setState(() => _a4 = a4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Violon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6D4C41),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (BuildContext context) => SessionScreen(
          passage: _passage,
          onChangePassage: () => unawaited(_editPassage(context)),
          onTune: () => unawaited(_openTuner(context)),
          a4: _a4,
          pitchSourceFactory: widget.pitchSourceFactory,
        ),
      ),
    );
  }
}
