import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/reading_drill.dart';
import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/music/score_note.dart';
import '../widgets/keep_screen_awake.dart';
import '../widgets/score_view.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Lire les notes, en les jouant (lot L1).
///
/// Une note gravee, et l'eleve la joue : c'est le solfege sur le violon, pas
/// sur un clavier. **Deux minutes, et un chiffre qui monte** -- combien de
/// notes lues -- sans jamais dire combien ont ete cherchees. Rien n'est note
/// ni garde : chercher est le but.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    required this.pitchSourceFactory,
    required this.pool,
    this.keyFifths,
    this.a4 = PitchUtils.defaultA4,
    this.seed = 1,
    this.duration = const Duration(minutes: 2),
    super.key,
  });

  final PitchSourceFactory pitchSourceFactory;

  /// Les notes a lire : celles du morceau du moment, le plus souvent.
  final List<int> pool;

  /// La tonalite, pour les alterations a la cle.
  final int? keyFifths;
  final double a4;
  final int seed;
  final Duration duration;

  static const Key compteKey = Key('lecture-compte');
  static const Key resteKey = Key('lecture-reste');
  static const Key bilanKey = Key('lecture-bilan');
  static const Key recommencerKey = Key('lecture-recommencer');

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen>
    with SingleTickerProviderStateMixin {
  late ReadingDrill _lecture =
      ReadingDrill(pool: widget.pool, seed: widget.seed);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _depuis = Duration.zero;
  bool _fini = false;

  PitchSource? _source;
  StreamSubscription<SmoothedPitch>? _abonnement;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    unawaited(_ouvrir());
  }

  Future<void> _ouvrir() async {
    try {
      final PitchSource source = await widget.pitchSourceFactory();
      if (!mounted) {
        await source.dispose();
        return;
      }
      _source = source;
      _abonnement = source.smoothedPitches.listen(_onPitch);
      await source.start();
    } catch (_) {
      // Sans micro, la note reste affichee : on peut toujours la lire.
    }
  }

  void _onTick(Duration ecoule) {
    if (_fini) {
      return;
    }
    if (ecoule >= widget.duration) {
      setState(() => _fini = true);
      unawaited(_source?.stop());
      return;
    }
    // Une fois par seconde suffit pour le temps qui reste.
    if (ecoule.inSeconds != _depuis.inSeconds) {
      setState(() => _depuis = ecoule);
    }
  }

  void _onPitch(SmoothedPitch p) {
    if (_fini || !mounted) {
      return;
    }
    final double midi =
        PitchUtils.frequencyToMidi(p.frequencyHz, a4: widget.a4);
    if (_lecture.hear(midi, p.timestampMs) == ReadingEvent.read) {
      setState(() {});
    }
  }

  void _recommencer() {
    setState(() {
      _lecture = ReadingDrill(pool: widget.pool, seed: widget.seed + 1);
      _fini = false;
      _depuis = Duration.zero;
    });
    _ticker
      ..stop()
      ..start();
    unawaited(_source?.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_abonnement?.cancel());
    unawaited(_source?.dispose());
    super.dispose();
  }

  Passage get _partition => Passage(
        title: 'lecture',
        notes: <ScoreNote>[
          ScoreNote(
            id: 'lue-${_lecture.read}',
            midi: _lecture.target,
            onsetTicks: 0,
            durationTicks: 480,
            measure: 1,
          ),
        ],
        ticksPerBeat: 480,
        writtenTempoBpm: 60,
        keyFifths: widget.keyFifths,
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration reste = widget.duration - _depuis;
    final int s = reste.inSeconds.clamp(0, widget.duration.inSeconds);
    return KeepScreenAwake(
      actif: !_fini,
      child: Scaffold(
        appBar: AppBar(title: const Text('Lire les notes')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _fini ? 'Deux minutes, c est fini.' : 'Lis, et joue.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (!_fini)
                  SizedBox(
                    height: 160,
                    child: ScoreView(
                      passage: _partition,
                      spaceSize: 14,
                    ),
                  ),
                const Spacer(),
                if (_fini)
                  Text(
                    '${_lecture.read} note${_lecture.read > 1 ? 's' : ''} '
                    'lue${_lecture.read > 1 ? 's' : ''} en deux minutes.',
                    key: ReadingScreen.bilanKey,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  )
                else ...<Widget>[
                  Text(
                    '${_lecture.read} lue${_lecture.read > 1 ? 's' : ''}',
                    key: ReadingScreen.compteKey,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                    key: ReadingScreen.resteKey,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                if (_fini)
                  FilledButton.tonal(
                    key: ReadingScreen.recommencerKey,
                    onPressed: _recommencer,
                    child: const Text('Encore deux minutes'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
