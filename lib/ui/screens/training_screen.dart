import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/exercises/exercise.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/play/audio_engine.dart';
import '../../core/play/drone.dart';
import '../../core/play/metronome_clock.dart';
import '../../core/play/metronome_scheduler.dart';
import '../widgets/score_view.dart';

/// Travailler un exercice, avec le bourdon et le metronome.
///
/// **Ici l'application joue, et ne note rien** (ADR-008) : le micro reste
/// ferme, il n'y a ni score, ni curseur, ni couleur. C'est la moitie de la
/// seance que l'ADR-008 rendait jusqu'ici impossible, et c'est la plus utile
/// des deux -- un professeur fait travailler la gamme au bourdon bien avant de
/// la faire passer.
///
/// La distinction que ca installe :
///
/// | | |
/// |---|---|
/// | **Travailler** | Bourdon, metronome. L'application emet. Rien n'est note. |
/// | **Passer** | Silence. Elle ecoute, elle note, elle designe quoi rejouer. |
///
/// On travaille avec l'oreille, on se controle ensuite. Faire l'inverse --
/// noter avant d'avoir travaille -- est exactement ce qui degoute un enfant de
/// ses gammes.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    required this.exercise,
    required this.tempoBpm,
    required this.engine,
    this.a4 = PitchUtils.defaultA4,
    super.key,
  });

  final Exercise exercise;
  final int tempoBpm;
  final AudioEngine engine;
  final double a4;

  static const Key bourdonKey = Key('entrainement-bourdon');
  static const Key metronomeKey = Key('entrainement-metronome');

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  bool _bourdon = false;
  bool _metronome = false;
  final List<DroneVoice> _voix = <DroneVoice>[];
  MetronomeScheduler? _planificateur;

  MetronomeClock get _horloge => MetronomeClock(tempoBpm: widget.tempoBpm);

  /// La tonalite du bourdon, deduite de l'exercice.
  Drone? get _tonique {
    final int? classe = widget.exercise.tonicPitchClass;
    return classe == null ? null : Drone(pitchClass: classe, a4: widget.a4);
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Le son ne survit pas a l'ecran : sinon il continuerait pendant une prise
    // notee, et l'application emettrait en ecoutant.
    unawaited(widget.engine.stopAll());
    super.dispose();
  }

  void _onTick(Duration elapsed) {
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

  Future<void> _basculerLeBourdon(bool allume) async {
    final Drone? tonique = _tonique;
    if (tonique == null) {
      return;
    }
    setState(() => _bourdon = allume);
    if (!allume) {
      final List<DroneVoice> aArreter = List<DroneVoice>.of(_voix);
      _voix.clear();
      for (final DroneVoice voix in aArreter) {
        await voix.stop();
      }
      return;
    }
    await widget.engine.start();
    for (final double hz in tonique.frequencies) {
      if (!mounted || !_bourdon) {
        return;
      }
      _voix.add(await widget.engine.startDrone(frequencyHz: hz, volume: 0.25));
    }
  }

  Future<void> _basculerLeMetronome(bool allume) async {
    if (!allume) {
      _ticker.stop();
      setState(() {
        _metronome = false;
        _planificateur = null;
      });
      // Les clics deja poses d'avance doivent etre annules, mais pas le
      // bourdon : on coupe donc les voix et on les relance.
      await widget.engine.stopAll();
      _voix.clear();
      if (_bourdon) {
        await _basculerLeBourdon(true);
      }
      return;
    }
    await widget.engine.start();
    if (!mounted) {
      return;
    }
    setState(() {
      _metronome = true;
      _planificateur = MetronomeScheduler(clock: _horloge);
    });
    _ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Drone? tonique = _tonique;
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.titre)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Text(
              '${widget.exercise.detail} - ${widget.tempoBpm} bpm',
              style: theme.textTheme.bodyMedium,
            ),
            if (widget.exercise.conseil != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                widget.exercise.conseil!,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            // La partition, sans curseur : rien ne defile, c'est l'eleve qui
            // mene. Le suiveur viendra au jalon 6 ; en attendant, un curseur
            // d'horloge contredirait l'ADR-009.
            SizedBox(
              height: 220,
              child: ScoreView(
                  passage: widget.exercise.toPassage(
                tempoBpm: widget.tempoBpm,
              )),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              key: TrainingScreen.bourdonKey,
              contentPadding: EdgeInsets.zero,
              value: _bourdon,
              onChanged: tonique == null
                  ? null
                  : (bool v) => unawaited(_basculerLeBourdon(v)),
              title: Text(
                tonique == null ? 'Bourdon' : 'Bourdon sur ${tonique.label}',
              ),
              subtitle: Text(
                tonique == null
                    // Dire pourquoi, plutot que de griser sans explication.
                    ? 'Pas de tonique : le motif traverse les quatre cordes'
                    : 'La tonique de l exercice, quinte comprise',
              ),
            ),
            SwitchListTile(
              key: TrainingScreen.metronomeKey,
              contentPadding: EdgeInsets.zero,
              value: _metronome,
              onChanged: (bool v) => unawaited(_basculerLeMetronome(v)),
              title: Text('Metronome a ${widget.tempoBpm}'),
              subtitle: const Text('Le premier temps sonne plus aigu'),
            ),
            const SizedBox(height: 16),
            Text(
              'Rien n est note ici : l application joue, elle n ecoute pas. '
              'Quand tu veux te controler, passe l exercice.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
