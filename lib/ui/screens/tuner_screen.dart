import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/scoring/a4_estimator.dart';
import '../../core/scoring/open_string_fifths.dart';
import '../../core/scoring/tuner.dart';
import '../widgets/tuner_gauge.dart';
import '../widgets/tuning_colors.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Accorder avant de jouer.
///
/// C'est la premiere chose qu'on fait en ouvrant un etui, et ca ne demande ni
/// partition ni passage. L'ecran s'ouvre, le micro ecoute, on tourne les
/// chevilles.
class TunerScreen extends StatefulWidget {
  const TunerScreen({
    required this.pitchSourceFactory,
    required this.a4,
    required this.onA4Changed,
    super.key,
  });

  final PitchSourceFactory pitchSourceFactory;

  /// Diapason de reference en cours.
  final double a4;

  /// Appele quand l'utilisateur adopte l'accord reel de son instrument.
  final ValueChanged<double> onA4Changed;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  PitchSource? _source;
  StreamSubscription<SmoothedPitch>? _abonnement;
  TunerReading? _lecture;
  double? _diapasonMesure;
  String? _probleme;

  late Tuner _accordeur = Tuner(a4: widget.a4);
  late A4Estimator _diapason = A4Estimator(tuner: _accordeur);

  @override
  void initState() {
    super.initState();
    unawaited(_ouvrirLeMicro());
  }

  Future<void> _ouvrirLeMicro() async {
    try {
      final PitchSource source = await widget.pitchSourceFactory();
      if (!mounted) {
        await source.dispose();
        return;
      }
      _source = source;
      _abonnement = source.smoothedPitches.listen(_onPitch);
      await source.start();
    } on MicPermissionDenied {
      _direLeProbleme('Micro refuse : impossible d\'accorder.');
    } catch (_) {
      _direLeProbleme('Micro indisponible : impossible d\'accorder.');
    }
  }

  void _direLeProbleme(String message) {
    if (mounted) {
      setState(() => _probleme = message);
    }
  }

  void _onPitch(SmoothedPitch pitch) {
    if (!mounted) {
      return;
    }
    setState(() {
      final TunerReading? lecture = _accordeur.read(pitch);
      _lecture = lecture;
      _diapasonMesure = _diapason.add(pitch) ?? _diapasonMesure;
      // On ne retient qu'une corde tenue : une hauteur qui glisse pendant que
      // l'archet se pose donnerait une quinte fantaisiste.
      if (lecture != null && lecture.steady) {
        _cordesMesurees[lecture.stringMidi] = lecture.frequencyHz;
      }
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

  /// Derniere frequence tenue sur chaque corde a vide.
  ///
  /// C'est ce qui permet de rendre les **quintes**, alors que le detecteur
  /// est monophonique et n'entend pas une double corde : on mesure les cordes
  /// l'une apres l'autre, et on rend l'intervalle.
  final Map<int, double> _cordesMesurees = <int, double>{};

  void _adopterLeDiapason() {
    final double? mesure = _diapasonMesure;
    if (mesure == null) {
      return;
    }
    widget.onA4Changed(mesure);
    setState(() {
      _accordeur = Tuner(a4: mesure);
      _diapason = A4Estimator(tuner: _accordeur);
      _diapasonMesure = null;
      // Les cordes ont ete mesurees contre l'ancienne reference : les garder
      // donnerait des quintes fausses d'un bout a l'autre.
      _cordesMesurees.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TunerReading? lecture = _lecture;

    return Scaffold(
      appBar: AppBar(title: const Text('Accorder')),
      body: SafeArea(
        child: Padding(
          key: const Key('tuner-content'),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StringRow(
                cordes: PitchUtils.violinOpenStrings,
                active: lecture?.stringMidi,
              ),
              const Spacer(),
              Text(
                lecture == null ? '--' : lecture.stringName,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                _texteDesCents(lecture),
                key: const Key('tuner-cents'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TunerGauge(reading: lecture),
              const SizedBox(height: 16),
              _Quintes(quintes: OpenStringFifths.from(_cordesMesurees)),
              const Spacer(),
              if (_probleme != null)
                Text(
                  _probleme!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              _LigneDuDiapason(
                reference: widget.a4,
                mesure: _diapasonMesure,
                onAdopter: _adopterLeDiapason,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Le chiffre ne s'affiche que quand la hauteur tient : pendant un demarrage
  /// d'archet il danserait sans rien dire d'utile.
  static String _texteDesCents(TunerReading? lecture) {
    if (lecture == null) {
      return 'Joue une corde a vide';
    }
    if (!lecture.steady) {
      return '...';
    }
    final int cents = lecture.centsOffset.round();
    if (lecture.inTune) {
      return 'juste';
    }
    return cents > 0 ? '+$cents cents' : '$cents cents';
  }
}

/// Le diapason de reference, et la possibilite d'adopter celui de
/// l'instrument.
/// Les trois quintes du violon, une fois les cordes entendues.
///
/// **Un violoniste accorde par quintes, pas note par note.** On tire deux
/// cordes voisines ensemble et on ecoute les battements : c'est ce qu'on lui
/// enseigne. Le detecteur etant monophonique, on mesure les cordes l'une
/// apres l'autre et on rend l'intervalle -- meme question, moyens differents.
///
/// La reference est la quinte **juste**, pas la temperee : un violon
/// s'accorde sur le rapport 3:2, et juger contre les 700 cents du piano
/// declarerait fausses trois cordes accordees exactement comme il faut.
class _Quintes extends StatelessWidget {
  const _Quintes({required this.quintes});

  final List<StringFifth> quintes;

  static const Key quintesKey = Key('tuner-quintes');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (quintes.isEmpty) {
      return Text(
        'Joue deux cordes voisines pour verifier tes quintes.',
        key: quintesKey,
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      );
    }
    return Row(
      key: quintesKey,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (final StringFifth q in quintes)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(q.name, style: theme.textTheme.labelSmall),
              Text(
                OpenStringFifths.isInTune(q)
                    ? 'juste'
                    : q.tooWide
                        ? 'large'
                        : 'etroite',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: OpenStringFifths.isInTune(q)
                      ? TuningColors.inTune
                      : q.tooWide
                          ? TuningColors.high
                          : TuningColors.low,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _LigneDuDiapason extends StatelessWidget {
  const _LigneDuDiapason({
    required this.reference,
    required this.mesure,
    required this.onAdopter,
  });

  final double reference;
  final double? mesure;
  final VoidCallback onAdopter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? m = mesure;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            'Diapason ${reference.round()} Hz',
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (m != null && (m - reference).abs() >= 0.5)
          TextButton(
            onPressed: onAdopter,
            child: Text('Adopter ${m.round()} Hz'),
          ),
      ],
    );
  }
}
