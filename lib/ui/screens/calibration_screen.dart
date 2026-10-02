import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/onset_detector.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/play/audio_engine.dart';
import '../../core/play/latency_calibration.dart';
import '../../core/play/metronome_clock.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Mesurer la latence du telephone (lot J2) : six clics, et le micro qui les
/// entend.
///
/// **Elle ne sert ni a la justesse ni au rythme** : elle sert a ce que
/// l'application emet pendant que l'eleve joue, l'accompagnement qui le suit
/// (J5). Un reglage qu'on fait une fois, telephone pose, piece silencieuse.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    required this.engine,
    required this.pitchSourceFactory,
    required this.onMeasured,
    this.current,
    super.key,
  });

  final AudioEngine engine;
  final PitchSourceFactory pitchSourceFactory;
  final ValueChanged<int> onMeasured;

  /// La derniere latence mesuree, s'il y en a une.
  final int? current;

  static const Key mesurerKey = Key('mesurer-la-latence');
  static const Key resultatKey = Key('latence-mesuree');

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  bool _enCours = false;
  String? _message;
  late int? _latence = widget.current;

  PitchSource? _source;
  StreamSubscription<Uint8List>? _octets;
  final OnsetDetector _attaques = OnsetDetector();
  final List<int> _entendus = <int>[];
  int _echantillons = 0;
  int? _pont;
  final List<int> _clics = <int>[];
  int? _octetOrphelin;

  @override
  void dispose() {
    unawaited(_fermer());
    super.dispose();
  }

  Future<void> _mesurer() async {
    setState(() {
      _enCours = true;
      _message = 'Silence... six clics vont sonner.';
    });
    _entendus.clear();
    _clics.clear();
    _echantillons = 0;
    _pont = null;
    _attaques.reset();
    try {
      final PitchSource source = await widget.pitchSourceFactory();
      _source = source;
      _octets = source.audio.listen(_recevoir);
      await source.start();
    } on MicPermissionDenied {
      _finir('Le micro est refuse : impossible de mesurer.');
      return;
    }
    // Laisser le pont s'etablir sur le premier paquet du micro.
    for (int k = 0; k < 40 && _pont == null; k++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    if (_pont == null || !mounted) {
      _finir('Le micro ne donne rien : impossible de mesurer.');
      return;
    }
    final Duration maintenant = await widget.engine.now();
    final int depart = maintenant.inMilliseconds + 600;
    for (int k = 0; k < LatencyCalibration.clicks; k++) {
      final int t = depart + k * LatencyCalibration.intervalMs;
      _clics.add(t);
      await widget.engine.scheduleClickAt(
        at: Duration(milliseconds: t),
        accent: PulseAccent.downbeat,
      );
    }
    await Future<void>.delayed(
      const Duration(
        milliseconds: 600 +
            LatencyCalibration.clicks * LatencyCalibration.intervalMs +
            LatencyCalibration.maxLatencyMs,
      ),
    );
    final LatencyEstimate? e = LatencyCalibration.estimate(
      clicksEngineMs: _clics,
      onsetsMicMs: _entendus,
      micToEngineMs: _pont!,
    );
    if (e == null) {
      _finir('Mesure pas assez nette : le bruit de la piece ou le volume. '
          'Monte le son et recommence.');
      return;
    }
    widget.onMeasured(e.latencyMs);
    setState(() => _latence = e.latencyMs);
    _finir('${e.matched} clics entendus sur ${LatencyCalibration.clicks}, '
        'a ${e.spreadMs} ms pres.');
  }

  /// Les octets du micro : on les compte pour dater, et on cherche les
  /// attaques.
  void _recevoir(Uint8List octets) {
    final List<double> v = <double>[];
    int i = 0;
    if (_octetOrphelin != null && octets.isNotEmpty) {
      v.add(_echantillon(_octetOrphelin!, octets[0]));
      _octetOrphelin = null;
      i = 1;
    }
    for (; i + 1 < octets.length; i += 2) {
      v.add(_echantillon(octets[i], octets[i + 1]));
    }
    if (i < octets.length) {
      _octetOrphelin = octets[i];
    }
    _echantillons += v.length;
    // Le pont : a la fin de ce paquet, l'horloge du moteur marque ceci.
    if (_pont == null) {
      final int finDuPaquetMs = _echantillons * 1000 ~/ 44100;
      unawaited(widget.engine.now().then((Duration d) {
        _pont ??= d.inMilliseconds - finDuPaquetMs;
      }));
    }
    for (final Onset o in _attaques.addSamples(Float32List.fromList(v))) {
      _entendus.add(o.timestampMs);
    }
  }

  static double _echantillon(int faible, int fort) {
    final int x = faible | (fort << 8);
    return (x >= 0x8000 ? x - 0x10000 : x) / 32768;
  }

  void _finir(String message) {
    unawaited(_fermer());
    if (mounted) {
      setState(() {
        _enCours = false;
        _message = message;
      });
    }
  }

  Future<void> _fermer() async {
    final PitchSource? s = _source;
    _source = null;
    unawaited(_octets?.cancel());
    _octets = null;
    await s?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? l = _latence;
    return Scaffold(
      appBar: AppBar(title: const Text('Latence')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Pose le telephone comme pour jouer, dans une piece calme, le '
                'volume assez fort. L application joue six clics et mesure '
                'combien de temps son micro met a les entendre.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                l == null ? 'Pas encore mesuree' : 'Latence : $l ms',
                key: CalibrationScreen.resultatKey,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (_message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              FilledButton.icon(
                key: CalibrationScreen.mesurerKey,
                onPressed: _enCours ? null : () => unawaited(_mesurer()),
                icon: const Icon(Icons.timer_outlined),
                label: Text(_enCours ? 'Mesure en cours' : 'Mesurer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
