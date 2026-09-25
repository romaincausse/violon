import 'dart:async';

import 'package:flutter/material.dart';

import 'core/exercises/exercise.dart';
import 'core/exercises/exercise_catalog.dart';
import 'core/exercises/exercise_progress.dart';
import 'core/music/demo_passage.dart';
import 'core/music/passage.dart';
import 'core/music/pitch_utils.dart';
import 'core/play/audio_engine.dart';
import 'core/store/session_store.dart';
import 'platform/audio/default_pitch_source.dart';
import 'platform/audio/soloud_audio_engine.dart';
import 'platform/store/prefs_session_store.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/session_screen.dart' show PitchSourceFactory;

void main() {
  runApp(const ViolonApp());
}

typedef SessionStoreFactory = SessionStore Function();

class ViolonApp extends StatefulWidget {
  const ViolonApp({
    this.pitchSourceFactory = defaultPitchSource,
    this.audioEngineFactory = defaultAudioEngine,
    this.sessionStoreFactory = defaultSessionStore,
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

  /// Fabrique de la memoire, injectable pour la meme raison : un test de
  /// widget n'ecrit nulle part.
  final SessionStoreFactory sessionStoreFactory;

  @override
  State<ViolonApp> createState() => _ViolonAppState();
}

class _ViolonAppState extends State<ViolonApp> {
  late final SessionStore _memoire = widget.sessionStoreFactory();

  /// **Un seul ecrivain.** La progression vit dans la coquille de navigation,
  /// le diapason et le passage ici : si les deux rangeaient de leur cote, la
  /// derniere ecriture effacerait ce que l'autre venait d'ajouter. La coquille
  /// signale donc ses changements, et c'est cet etat-ci qui est range.
  RememberedSession _range = RememberedSession.vide;

  /// Faux tant qu'on n'a pas relu la memoire.
  ///
  /// On attend plutot que d'afficher la demo puis de la remplacer : une
  /// application qui change d'avis sous les yeux de l'enfant pendant qu'il
  /// tend la main vers le bouton est pire qu'une application qui met trente
  /// millisecondes a s'ouvrir.
  bool _relue = false;

  Passage _passage = buildDemoPassage();
  double _a4 = PitchUtils.defaultA4;
  Exercise? _exercice;
  List<ExerciseBest> _records = const <ExerciseBest>[];

  @override
  void initState() {
    super.initState();
    _relire();
  }

  Future<void> _relire() async {
    final RememberedSession lue = await _memoire.load();
    if (!mounted) {
      return;
    }
    final Exercise? exercice =
        lue.exerciseId == null ? null : ExerciseCatalog.byId(lue.exerciseId!);
    setState(() {
      _range = lue;
      _relue = true;
      _records = lue.bests;
      if (lue.a4 != null) {
        _a4 = lue.a4!;
      }
      _exercice = exercice;
      // Reprendre le travail de la veille, au tempo atteint : c'est la moitie
      // manquante de "demarrer en dix secondes" (lot L1).
      if (exercice != null) {
        _passage = exercice.toPassage(tempoBpm: lue.tempoBpm);
      }
    });
  }

  void _ranger({
    double? a4,
    Object? exerciseId = _inchange,
    int? tempoBpm,
    List<ExerciseBest>? bests,
  }) {
    _range = RememberedSession(
      a4: a4 ?? _range.a4,
      exerciseId: identical(exerciseId, _inchange)
          ? _range.exerciseId
          : exerciseId as String?,
      tempoBpm: identical(exerciseId, _inchange) ? _range.tempoBpm : tempoBpm,
      bests: bests ?? _range.bests,
    );
    unawaited(_memoire.save(_range));
  }

  /// Sentinelle : distingue "on ne touche pas a l'exercice" de "il n'y en a
  /// plus", que `null` seul ne saurait pas dire.
  static const Object _inchange = Object();

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
      home: !_relue
          ? const Scaffold(body: SizedBox.shrink())
          : HomeShell(
              pitchSourceFactory: widget.pitchSourceFactory,
              audioEngineFactory: widget.audioEngineFactory,
              passage: _passage,
              a4: _a4,
              initialBests: _records,
              initialExercise: _exercice,
              onPassageChanged: (Passage p) => setState(() => _passage = p),
              onA4Changed: (double a4) {
                setState(() => _a4 = a4);
                _ranger(a4: a4);
              },
              onRemember:
                  (List<ExerciseBest> bests, Exercise? exercice, int? tempo) {
                _exercice = exercice;
                _ranger(
                  bests: bests,
                  exerciseId: exercice?.id,
                  tempoBpm: tempo,
                );
              },
            ),
    );
  }
}
