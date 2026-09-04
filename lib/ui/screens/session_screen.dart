import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_estimate.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/follow/score_cursor.dart';
import '../../core/music/passage.dart';
import '../../core/music/score_note.dart';
import '../../core/scoring/live_tuning.dart';
import '../../platform/audio/default_pitch_source.dart';
import '../widgets/metronome_bar.dart';
import '../widgets/score_view.dart';
import '../widgets/tuning_colors.dart';

/// Construit la source de hauteurs. Injectable pour les tests et pour le
/// developpement de l'interface, ou l'on ne veut pas du vrai micro.
typedef PitchSourceFactory = Future<PitchSource> Function();

/// Ce que le micro a pu faire au dernier demarrage.
enum _MicState { arrete, ecoute, refuse, indisponible }

/// Ecran de travail : le passage, le curseur, et ce qu'on entend.
///
/// **Mode notation** au sens de l'ADR-008 : le micro est ouvert et
/// l'application n'emet aucun son. Le metronome est visuel, et il le reste.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    required this.passage,
    required this.onChangePassage,
    this.pitchSourceFactory = defaultPitchSource,
    super.key,
  });

  final Passage passage;

  /// Ouvre la saisie d'un autre passage.
  final VoidCallback onChangePassage;

  final PitchSourceFactory pitchSourceFactory;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  bool _running = false;
  Duration _elapsed = Duration.zero;

  final LiveTuning _tuning = LiveTuning();
  PitchSource? _source;
  StreamSubscription<PitchEstimate>? _abonnement;
  _MicState _mic = _MicState.arrete;

  ScoreCursor get _cursor => ScoreCursor(
        passage: widget.passage,
        tempoBpm: widget.passage.writtenTempoBpm,
      );

  void _onTick(Duration elapsed) {
    // La lecture s'arrete d'elle-meme sur la derniere note : on termine sur
    // la fin du passage, pas sur un bouton qu'il faudrait penser a presser.
    if (_cursor.isFinishedAt(elapsed)) {
      _stop();
      return;
    }
    setState(() => _elapsed = elapsed);
  }

  void _start() {
    setState(() {
      _elapsed = Duration.zero;
      _running = true;
      _tuning.reset();
    });
    _ticker.start();
    unawaited(_ouvrirLeMicro());
  }

  /// Ouvre le micro **sans bloquer le depart**.
  ///
  /// Le curseur part tout de suite : demander une permission peut prendre
  /// plusieurs secondes, et faire attendre l'enfant devant un ecran fige
  /// serait exactement la friction que le projet cherche a supprimer. Si le
  /// micro n'aboutit pas, le passage defile quand meme, sans coloration.
  Future<void> _ouvrirLeMicro() async {
    try {
      final PitchSource source = await widget.pitchSourceFactory();
      if (!mounted || !_running) {
        await source.dispose();
        return;
      }
      _source = source;
      _abonnement = source.pitches.listen(_onPitch);
      await source.start();
      if (mounted) {
        setState(() => _mic = _MicState.ecoute);
      }
    } on MicPermissionDenied {
      if (mounted) {
        setState(() => _mic = _MicState.refuse);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _mic = _MicState.indisponible);
      }
    }
  }

  /// Attribue ce qu'on entend a la note sur laquelle le curseur se trouve.
  ///
  /// L'attribution se fait a l'arrivee de la mesure, pas a son horodatage :
  /// la capture et le curseur ne demarrent pas exactement au meme instant, et
  /// tant que la latence n'est pas calibree (lot A4), prendre l'horodatage du
  /// micro donnerait une fausse precision. A 46 ms par trame, l'ecart ne se
  /// voit pas sur une coloration.
  void _onPitch(PitchEstimate estimate) {
    if (!_running) {
      return;
    }
    final ScoreNote? note = _cursor.noteAt(_elapsed);
    if (note == null) {
      return;
    }
    setState(() => _tuning.observe(note, estimate));
  }

  void _stop() {
    _ticker.stop();
    unawaited(_fermerLeMicro());
    setState(() {
      _running = false;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _fermerLeMicro() async {
    final PitchSource? source = _source;
    final StreamSubscription<PitchEstimate>? abonnement = _abonnement;
    _source = null;
    _abonnement = null;
    // Annuler sans attendre. Un abonnement cesse de livrer des l'appel ; la
    // promesse rendue, elle, n'est tenue qu'une fois le flux ferme. L'attendre
    // avant de fermer la source bloquait donc les deux : le micro restait
    // ouvert et l'ecran croyait encore ecouter.
    if (abonnement != null) {
      unawaited(abonnement.cancel());
    }
    await source?.dispose();
    if (mounted) {
      setState(() => _mic = _MicState.arrete);
    }
  }

  @override
  void didUpdateWidget(SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changer de passage arrete la lecture : ni le tempo ni les notes ne sont
    // les memes, et laisser courir l'ancienne induirait en erreur.
    if (widget.passage != oldWidget.passage && _running) {
      _stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_fermerLeMicro());
    super.dispose();
  }

  Color? _couleurDe(ScoreNote note) =>
      TuningColors.of(_tuning.verdictFor(note.id));

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Passage passage = widget.passage;

    return Scaffold(
      appBar: AppBar(
        title: Text(passage.title),
        actions: <Widget>[
          IconButton(
            onPressed: widget.onChangePassage,
            icon: const Icon(Icons.edit_note),
            tooltip: 'Changer de passage',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          // Cle explicite : le test de mise en page mesure ce contenu, pas
          // le SafeArea lui-meme, qui occupe toute la hauteur et dont seul
          // l'enfant est decale.
          key: const Key('session-content'),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    passage.measureCount == 1
                        ? 'Mesure ${passage.firstMeasure}'
                        : 'Mesures ${passage.firstMeasure} '
                            'a ${passage.lastMeasure}',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${passage.writtenTempoBpm} bpm',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 20),
              MetronomeBar(
                tempoBpm: passage.writtenTempoBpm,
                running: _running,
              ),
              Expanded(
                child: Center(
                  child: ScoreView(
                    passage: passage,
                    cursorTick: _running ? _cursor.tickAt(_elapsed) : null,
                    colorOf: _couleurDe,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _BandeauMicro(etat: _mic),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _running ? _stop : _start,
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? 'Arreter' : 'Jouer le passage'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une ligne discrete sous la portee : la legende des couleurs quand on
/// ecoute, la raison quand on n'ecoute pas.
class _BandeauMicro extends StatelessWidget {
  const _BandeauMicro({required this.etat});

  final _MicState etat;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    return switch (etat) {
      _MicState.arrete => const SizedBox(height: 20),
      _MicState.ecoute => const _Legende(),
      _MicState.refuse => SizedBox(
          height: 20,
          child: Text(
            'Micro refuse : le passage defile sans notation.',
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
      _MicState.indisponible => SizedBox(
          height: 20,
          child: Text(
            'Micro indisponible : le passage defile sans notation.',
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
    };
  }
}

/// Trois couleurs, trois mots. Une seule fois, en petit.
class _Legende extends StatelessWidget {
  const _Legende();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final TuningVerdict v in <TuningVerdict>[
            TuningVerdict.low,
            TuningVerdict.inTune,
            TuningVerdict.high,
          ]) ...<Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: TuningColors.of(v),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(TuningColors.label(v), style: style),
            const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }
}
