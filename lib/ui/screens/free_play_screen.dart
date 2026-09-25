import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/scoring/tuning_trace.dart';
import '../widgets/tuning_colors.dart';
import '../widgets/tuning_ribbon.dart';
import 'session_screen.dart' show PitchSourceFactory;
import '../widgets/keep_screen_awake.dart';

/// Elle ecoute, et ne demande rien.
///
/// **Aucune partition, aucun score, aucun jugement.** Pour s'echauffer, pour
/// chercher une note, pour jouer d'oreille -- et surtout pour que l'enfant
/// apprenne a lui faire confiance **avant** de la laisser le noter. Un outil
/// qu'on ne croit pas ne sert a rien, quelle que soit sa justesse.
///
/// L'ecart est mesure a la note temperee la plus proche, faute de tonalite.
/// C'est acceptable ici precisement parce qu'on ne note pas : on montre ce
/// qu'on entend, on ne dit pas que c'est faux.
class FreePlayScreen extends StatefulWidget {
  const FreePlayScreen({required this.pitchSourceFactory, this.a4, super.key});

  final PitchSourceFactory pitchSourceFactory;

  /// Diapason mesure par l'accordeur, s'il l'a ete.
  final double? a4;

  static const Key noteKey = Key('libre-note');
  static const Key centsKey = Key('libre-cents');

  @override
  State<FreePlayScreen> createState() => _FreePlayScreenState();
}

class _FreePlayScreenState extends State<FreePlayScreen> {
  PitchSource? _source;
  StreamSubscription<SmoothedPitch>? _abonnement;
  final TuningTrace _trace = TuningTrace();
  SmoothedPitch? _dernier;
  double _ecart = 0;

  double get _a4 => widget.a4 ?? PitchUtils.defaultA4;

  @override
  void initState() {
    super.initState();
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
      // Le mode libre n'a rien a annoncer : sans micro, l'ecran reste muet
      // plutot que d'afficher une erreur qu'on ne peut pas corriger d'ici.
    }
  }

  void _onPitch(SmoothedPitch pitch) {
    if (!mounted) {
      return;
    }
    final int proche = PitchUtils.nearestMidiNote(pitch.frequencyHz, a4: _a4);
    final double cents = PitchUtils.centsBetween(
      pitch.frequencyHz,
      PitchUtils.midiToFrequency(proche, a4: _a4),
    );
    setState(() {
      _dernier = pitch;
      _ecart = cents;
      _trace.add(pitch.timestampMs, cents);
    });
  }

  @override
  void dispose() {
    final PitchSource? source = _source;
    final StreamSubscription<SmoothedPitch>? abonnement = _abonnement;
    _source = null;
    _abonnement = null;
    if (abonnement != null) {
      unawaited(abonnement.cancel());
    }
    unawaited(source?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SmoothedPitch? p = _dernier;
    final int? midi =
        p == null ? null : PitchUtils.nearestMidiNote(p.frequencyHz, a4: _a4);
    return KeepScreenAwake(
      child: Scaffold(
        appBar: AppBar(title: const Text('Jouer librement')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(),
                Text(
                  midi == null ? '--' : PitchUtils.noteName(midi),
                  key: FreePlayScreen.noteKey,
                  style: theme.textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                Text(
                  p == null
                      ? 'joue ce que tu veux'
                      : '${_ecart >= 0 ? '+' : ''}${_ecart.round()} cents',
                  key: FreePlayScreen.centsKey,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: p == null ? null : _couleur(),
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                TuningRibbon(trace: _trace, height: 96),
                const SizedBox(height: 16),
                Text(
                  'Rien n est note ici.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _couleur() {
    if (_ecart.abs() <= 10) {
      return TuningColors.inTune;
    }
    return _ecart < 0 ? TuningColors.low : TuningColors.high;
  }
}
