import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/vibrato_meter.dart';
import '../../core/follow/performance_features.dart';
import '../widgets/keep_screen_awake.dart';
import '../widgets/tuning_colors.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Le vibrato (lot K13) : deux, trois, quatre oscillations par temps, sur un
/// pouls qu'on voit, puis libre.
///
/// **Le pouls est visuel** : le micro ecoute, et l'application emet ou
/// ecoute, jamais les deux (ADR-008). Un metronome sonore rentrerait dans le
/// micro et se mesurerait avec le vibrato.
///
/// **Des donnees, pas un verdict** : la vitesse, la largeur, si c'est
/// regulier. Le record est la plus longue note vibree regulierement.
class VibratoScreen extends StatefulWidget {
  const VibratoScreen({
    required this.pitchSourceFactory,
    this.bestMs = 0,
    this.onBest,
    super.key,
  });

  final PitchSourceFactory pitchSourceFactory;
  final int bestMs;
  final ValueChanged<int>? onBest;

  static const Key commencerKey = Key('vibrato-commencer');
  static const Key vitesseKey = Key('vibrato-vitesse');
  static const Key largeurKey = Key('vibrato-largeur');
  static const Key serieKey = Key('vibrato-serie');
  static const Key recordKey = Key('vibrato-record');
  static const Key pouls = Key('vibrato-pouls');
  static Key cibleKey(int? parTemps) => Key('vibrato-cible-${parTemps ?? 0}');

  /// Au-dela de cet ecart a la cible, on dit "un peu vite" ou "un peu lent".
  static const double tolerance = 0.15;

  @override
  State<VibratoScreen> createState() => _VibratoScreenState();
}

class _VibratoScreenState extends State<VibratoScreen>
    with SingleTickerProviderStateMixin {
  /// Oscillations par temps visees, ou `null` : libre.
  int? _cible = 2;
  int _bpm = 60;
  late VibratoMeter _mesure = VibratoMeter(bestMs: widget.bestMs);
  late int _record = widget.bestMs;

  PitchSource? _micro;
  StreamSubscription<FeatureFrame>? _trames;
  Timer? _tic;
  bool _ecoute = false;

  /// Le pouls : une animation, pas un son. Elle ne declenche rien.
  late final AnimationController _pouls = AnimationController(vsync: this);

  Duration get _temps => Duration(microseconds: 60000000 ~/ _bpm);

  Future<void> _basculer() async {
    if (_ecoute) {
      await _arreter();
      return;
    }
    setState(() {
      _ecoute = true;
      _mesure = VibratoMeter(bestMs: _record);
    });
    if (_cible != null) {
      _pouls
        ..duration = _temps
        ..repeat();
    }
    try {
      final PitchSource micro = await widget.pitchSourceFactory();
      if (!mounted || !_ecoute) {
        await micro.dispose();
        return;
      }
      _micro = micro;
      _trames = micro.features.listen(_onTrame);
      await micro.start();
    } on MicPermissionDenied {
      _pouls.stop();
      setState(() => _ecoute = false);
      return;
    }
    // Une veille d'affichage : quarante trames par seconde, dix dessins.
    _tic = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onTrame(FeatureFrame f) {
    _mesure.hear(f);
    _noter();
  }

  void _noter() {
    if (_mesure.bestMs > _record) {
      _record = _mesure.bestMs;
      widget.onBest?.call(_record);
    }
  }

  Future<void> _arreter() async {
    _tic?.cancel();
    _tic = null;
    _pouls.stop();
    final PitchSource? m = _micro;
    _micro = null;
    unawaited(_trames?.cancel());
    _trames = null;
    _mesure.rest();
    _noter();
    if (mounted) {
      setState(() => _ecoute = false);
    }
    await m?.dispose();
  }

  @override
  void dispose() {
    _tic?.cancel();
    _pouls.dispose();
    unawaited(_trames?.cancel());
    unawaited(_micro?.dispose());
    super.dispose();
  }

  String _vitesse(VibratoReading? r) {
    if (r == null) {
      return _ecoute ? 'Tiens une note, et vibre' : '';
    }
    final int? c = _cible;
    if (c == null) {
      return '${r.rateHz.toStringAsFixed(1)} par seconde';
    }
    return '${r.perBeat(_bpm).toStringAsFixed(1)} par temps';
  }

  /// Ce que dit la vitesse, rapportee a la cible.
  (String, Color?) _avis(VibratoReading? r) {
    final int? c = _cible;
    if (r == null || c == null) {
      return ('', null);
    }
    final double ecart = r.perBeat(_bpm) / c - 1;
    if (ecart.abs() <= VibratoScreen.tolerance) {
      return ('Pile', TuningColors.inTune);
    }
    return ecart > 0 ? ('Un peu vite', null) : ('Un peu lent', null);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VibratoReading? r = _ecoute ? _mesure.current : null;
    final (String avis, Color? couleur) = _avis(r);
    return KeepScreenAwake(
      actif: _ecoute,
      child: Scaffold(
        appBar: AppBar(title: const Text('Le vibrato')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: <Widget>[
                    for (final int? c in <int?>[2, 3, 4, null])
                      ChoiceChip(
                        key: VibratoScreen.cibleKey(c),
                        label: Text(c == null ? 'Libre' : '$c par temps'),
                        selected: _cible == c,
                        onSelected:
                            _ecoute ? null : (_) => setState(() => _cible = c),
                      ),
                  ],
                ),
                if (_cible != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      IconButton(
                        onPressed: !_ecoute && _bpm > 40
                            ? () => setState(() => _bpm -= 4)
                            : null,
                        icon: const Icon(Icons.remove),
                        tooltip: 'Plus lent',
                      ),
                      Text('$_bpm a la noire',
                          style: theme.textTheme.titleMedium),
                      IconButton(
                        onPressed: !_ecoute && _bpm < 92
                            ? () => setState(() => _bpm += 4)
                            : null,
                        icon: const Icon(Icons.add),
                        tooltip: 'Plus vite',
                      ),
                    ],
                  ),
                const Spacer(),
                if (_cible != null)
                  Center(
                    child: AnimatedBuilder(
                      key: VibratoScreen.pouls,
                      animation: _pouls,
                      builder: (BuildContext c, Widget? _) {
                        // Plein sur le temps, puis il pali : l'oeil sait
                        // ou tombe le temps sans compter.
                        final double v = _ecoute ? 1 - _pouls.value : 0.15;
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.15 + 0.85 * v),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  _vitesse(r),
                  key: VibratoScreen.vitesseKey,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                Text(
                  avis,
                  style: theme.textTheme.titleMedium?.copyWith(color: couleur),
                  textAlign: TextAlign.center,
                ),
                Text(
                  r == null
                      ? ''
                      : '${r.amplitudeCents.round()} cents de part et '
                          'd autre${r.regular ? ', regulier' : ''}',
                  key: VibratoScreen.largeurKey,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${(_ecoute ? _mesure.regularMs / 1000 : 0).toStringAsFixed(1)} s '
                  'vibrees regulierement',
                  key: VibratoScreen.serieKey,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                Text(
                  _record == 0
                      ? 'Pas encore de record'
                      : 'Record : ${(_record / 1000).toStringAsFixed(1)} s',
                  key: VibratoScreen.recordKey,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton.icon(
                  key: VibratoScreen.commencerKey,
                  onPressed: () => unawaited(_basculer()),
                  icon: Icon(_ecoute ? Icons.stop : Icons.mic),
                  label: Text(_ecoute ? 'Arreter' : 'Commencer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
