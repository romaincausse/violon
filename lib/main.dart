import 'package:flutter/material.dart';

import 'core/music/demo_passage.dart';
import 'ui/screens/practice_screen.dart';

void main() {
  runApp(const ViolonApp());
}

class ViolonApp extends StatelessWidget {
  const ViolonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Violon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6D4C41),
        useMaterial3: true,
      ),
      home: PracticeScreen(passage: buildDemoPassage()),
    );
  }
}
