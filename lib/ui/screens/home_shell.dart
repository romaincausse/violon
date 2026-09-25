import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import 'free_play_screen.dart';
import 'mic_check_screen.dart';
import 'passage_editor_screen.dart';
import 'session_screen.dart';
import 'tuner_screen.dart';

/// La coquille de navigation.
///
/// **L'application n'a pas d'accueil.** Elle s'ouvre sur le travail en cours,
/// et un seul appui lance la prise. Un ecran d'accueil couterait un appui par
/// seance, tous les soirs, pour une information que l'enfant connait deja --
/// et dix secondes sont la duree au-dela de laquelle il repose le violon.
///
/// **Des destinations, et un tiroir d'outils.** Un onglet remplace l'ecran ;
/// un outil se pose par-dessus. L'accordeur se prend violon en main, au
/// milieu d'une seance : l'ouvrir ne doit rien faire perdre.
///
/// Raisonnement complet dans `docs/navigation.md`.
class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.pitchSourceFactory,
    required this.passage,
    required this.a4,
    required this.onPassageChanged,
    required this.onA4Changed,
    super.key,
  });

  final PitchSourceFactory pitchSourceFactory;
  final Passage passage;
  final double a4;
  final ValueChanged<Passage> onPassageChanged;
  final ValueChanged<double> onA4Changed;

  static const Key outilsKey = Key('ouvrir-les-outils');
  static const Key navKey = Key('navigation');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// L'application s'ouvre sur *Jouer*, jamais sur un menu.
  int _destination = 0;

  Future<void> _ouvrirLesOutils() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Accorder'),
              subtitle: const Text('Les quatre cordes, et les quintes'),
              onTap: () => _ouvrir(
                context,
                (BuildContext c) => TunerScreen(
                  pitchSourceFactory: widget.pitchSourceFactory,
                  a4: widget.a4,
                  onA4Changed: widget.onA4Changed,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: const Text('Jouer librement'),
              subtitle: const Text('Elle ecoute, elle ne note rien'),
              onTap: () => _ouvrir(
                context,
                (BuildContext c) => FreePlayScreen(
                  pitchSourceFactory: widget.pitchSourceFactory,
                  a4: widget.a4,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Est-ce qu elle m entend ?'),
              subtitle: const Text('Verifier le micro'),
              onTap: () => _ouvrir(
                context,
                (BuildContext c) => MicCheckScreen(
                  pitchSourceFactory: widget.pitchSourceFactory,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Referme le tiroir, puis ouvre l'ecran : sans quoi il resterait derriere.
  void _ouvrir(BuildContext sheetContext, WidgetBuilder builder) {
    Navigator.of(sheetContext).pop();
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: builder),
      ),
    );
  }

  Future<void> _saisirUnPassage() async {
    final Passage? saisi = await Navigator.of(context).push<Passage>(
      MaterialPageRoute<Passage>(
        builder: (BuildContext context) => const PassageEditorScreen(),
      ),
    );
    if (saisi != null) {
      widget.onPassageChanged(saisi);
      // On revient jouer : saisir un passage, c'est vouloir le travailler.
      setState(() => _destination = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _destination == 0
          ? SessionScreen(
              passage: widget.passage,
              a4: widget.a4,
              pitchSourceFactory: widget.pitchSourceFactory,
              onChangePassage: () => unawaited(_saisirUnPassage()),
              // Accorder est la premiere chose de chaque seance : elle
              // merite son raccourci, en plus du tiroir.
              onTune: () => unawaited(
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext c) => TunerScreen(
                      pitchSourceFactory: widget.pitchSourceFactory,
                      a4: widget.a4,
                      onA4Changed: widget.onA4Changed,
                    ),
                  ),
                ),
              ),
            )
          : _Repertoire(
              passage: widget.passage,
              a4: widget.a4,
              onSaisir: () => unawaited(_saisirUnPassage()),
            ),
      bottomNavigationBar: NavigationBar(
        key: HomeShell.navKey,
        selectedIndex: _destination,
        onDestinationSelected: (int i) {
          // Le dernier bouton n'est pas une destination : c'est le tiroir.
          if (i == 2) {
            unawaited(_ouvrirLesOutils());
            return;
          }
          setState(() => _destination = i);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.play_arrow), label: 'Jouer'),
          NavigationDestination(
            icon: Icon(Icons.library_music),
            label: 'Repertoire',
          ),
          NavigationDestination(
            key: HomeShell.outilsKey,
            icon: Icon(Icons.handyman),
            label: 'Outils',
          ),
        ],
      ),
    );
  }
}

/// Ce qu'on peut choisir de travailler.
///
/// **Encore maigre, et c'est normal.** Les gammes et les exercices arrivent au
/// jalon 3, les devoirs du professeur au jalon 10. La troisieme destination
/// prevue par `docs/navigation.md` -- *Progres* -- attend la persistance (lot
/// H1) : un onglet vide serait pire que pas d'onglet du tout.
class _Repertoire extends StatelessWidget {
  const _Repertoire({
    required this.passage,
    required this.a4,
    required this.onSaisir,
  });

  final Passage passage;
  final double a4;
  final VoidCallback onSaisir;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Repertoire')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: ListTile(
                title: Text(passage.title),
                subtitle: Text(
                  passage.measureCount == 1
                      ? 'Mesure ${passage.firstMeasure} - '
                          '${passage.writtenTempoBpm} bpm'
                      : 'Mesures ${passage.firstMeasure} a '
                          '${passage.lastMeasure} - '
                          '${passage.writtenTempoBpm} bpm',
                ),
                trailing: const Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: onSaisir,
              icon: const Icon(Icons.edit_note),
              label: const Text('Saisir un passage'),
            ),
            const SizedBox(height: 24),
            Text(
              a4 == PitchUtils.defaultA4
                  ? 'Diapason : 440 Hz (par defaut)'
                  : 'Diapason mesure : ${a4.toStringAsFixed(1)} Hz',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Les gammes et les exercices arrivent au jalon suivant.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
