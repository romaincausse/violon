import 'dart:async';

import 'package:flutter/material.dart';

import 'core/music/demo_passage.dart';
import 'core/music/passage.dart';
import 'ui/screens/passage_editor_screen.dart';
import 'ui/screens/session_screen.dart';

void main() {
  runApp(const ViolonApp());
}

class ViolonApp extends StatefulWidget {
  const ViolonApp({super.key});

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
        ),
      ),
    );
  }
}
