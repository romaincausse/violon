import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/play/audio_engine.dart';
import '../../core/play/metronome_clock.dart';
import '../../core/play/metronome_scheduler.dart';
import '../widgets/metronome_bar.dart';
import '../widgets/keep_screen_awake.dart';

/// Le metronome sonore.
///
/// **Le seul metronome de l'application qui fasse du bruit, et il vit hors de
/// la notation** (ADR-008) : le haut-parleur est a dix centimetres du micro,
/// donc une application qui ecoute n'emet pas. Pendant une prise notee, le
/// metronome reste visuel -- c'est `MetronomeBar` dans l'ecran de seance.
///
/// **Le clic n'est jamais declenche par l'interface.** A chaque image, l'ecran
/// demande au [MetronomeScheduler] ce qui reste a poser dans la seconde et
/// demie qui vient, et le moteur fige l'instant de chaque clic. Si l'interface
/// bloque un quart de seconde, les clics deja poses sonnent quand meme, a
/// l'heure. Voir `AudioEngine.scheduleClick`.
class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({required this.engine, this.tempoBpm = 80, super.key});

  final AudioEngine engine;

  /// Tempo d'ouverture.
  final int tempoBpm;

  static const Key jouerKey = Key('metronome-jouer');
  static const Key tempoKey = Key('metronome-tempo');
  static const Key mesureKey = Key('metronome-mesure');

  static Key subdivisionKey(int n) => Key('metronome-subdivision-$n');

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late int _tempo = widget.tempoBpm;
  int _subdivision = 1;
  int _tempsParMesure = 4;
  bool _marche = false;
  Duration _ecoule = Duration.zero;

  MetronomeClock get _horloge => MetronomeClock(
        tempoBpm: _tempo,
        beatsPerMeasure: _tempsParMesure,
        subdivision: _subdivision,
      );

  MetronomeScheduler? _planificateur;

  @override
  void dispose() {
    _ticker.dispose();
    // Le son ne survit pas a l'ecran, clics deja planifies compris.
    unawaited(widget.engine.stopAll());
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    setState(() => _ecoule = elapsed);
    final MetronomeScheduler? planificateur = _planificateur;
    if (planificateur == null) {
      return;
    }
    for (final ScheduledPulse pulsation in planificateur.due(elapsed)) {
      unawaited(
        widget.engine.scheduleClick(
          delay: MetronomeScheduler.delayFor(pulsation, elapsed),
          accent: pulsation.accent,
        ),
      );
    }
  }

  Future<void> _basculer() async {
    if (_marche) {
      _arreter();
      return;
    }
    await widget.engine.start();
    if (!mounted) {
      return;
    }
    setState(() {
      _marche = true;
      _ecoule = Duration.zero;
      _planificateur = MetronomeScheduler(clock: _horloge);
    });
    _ticker.start();
  }

  void _arreter() {
    _ticker.stop();
    // Les clics deja poses doivent etre annules, sinon la seconde et demie
    // planifiee d'avance continue de sonner apres l'arret.
    unawaited(widget.engine.stopAll());
    setState(() {
      _marche = false;
      _ecoule = Duration.zero;
      _planificateur = null;
    });
  }

  /// Un reglage change : on repart de zero plutot que de chercher sa place
  /// dans une grille qui n'est plus la meme.
  void _reglage(VoidCallback changement) {
    final bool marchait = _marche;
    if (marchait) {
      _arreter();
    }
    setState(changement);
    if (marchait) {
      unawaited(_basculer());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return KeepScreenAwake(
      actif: _marche,
      child: Scaffold(
        appBar: AppBar(title: const Text('Metronome')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('$_tempo', style: theme.textTheme.displaySmall),
                  Text('a la noire', style: theme.textTheme.bodyMedium),
                ],
              ),
              Slider(
                key: MetronomeScreen.tempoKey,
                value: _tempo.toDouble(),
                min: 40,
                max: 208,
                divisions: 168,
                label: '$_tempo',
                onChanged: (double v) => _reglage(() => _tempo = v.round()),
              ),
              const SizedBox(height: 8),
              MetronomeBar(
                tempoBpm: _tempo,
                running: _marche,
                beatsPerMeasure: _tempsParMesure,
                subdivision: _subdivision,
                key: ValueKey<String>('$_tempo-$_subdivision-$_tempsParMesure'),
              ),
              const SizedBox(height: 4),
              Text(
                _marche
                    ? 'Temps ${_horloge.beatInMeasureAt(_ecoule)} '
                        'sur $_tempsParMesure'
                    : 'Arrete',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('Subdivision', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final (int n, String nom) in <(int, String)>[
                    (1, 'Noires'),
                    (2, 'Croches'),
                    (3, 'Triolets'),
                    (4, 'Doubles'),
                  ])
                    ChoiceChip(
                      key: MetronomeScreen.subdivisionKey(n),
                      label: Text(nom),
                      selected: _subdivision == n,
                      onSelected: (bool choisi) {
                        if (choisi) {
                          _reglage(() => _subdivision = n);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Temps par mesure', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                key: MetronomeScreen.mesureKey,
                spacing: 8,
                children: <Widget>[
                  for (final int n in <int>[2, 3, 4, 6])
                    ChoiceChip(
                      label: Text('$n'),
                      selected: _tempsParMesure == n,
                      onSelected: (bool choisi) {
                        if (choisi) {
                          _reglage(() => _tempsParMesure = n);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: MetronomeScreen.jouerKey,
                onPressed: () => unawaited(_basculer()),
                icon: Icon(_marche ? Icons.stop : Icons.play_arrow),
                label: Text(_marche ? 'Arreter' : 'Faire sonner'),
              ),
              const SizedBox(height: 24),
              Text(
                'Le premier temps sonne plus aigu, pas plus fort.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
