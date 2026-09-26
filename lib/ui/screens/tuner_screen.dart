import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/scoring/a4_estimator.dart';
import '../../core/scoring/open_string_fifths.dart';
import '../../core/scoring/tuner.dart';
import '../../core/scoring/tuning_advice.dart';
import '../widgets/tuner_gauge.dart';
import '../widgets/tuning_colors.dart';
import 'session_screen.dart' show PitchSourceFactory;
import '../widgets/keep_screen_awake.dart';

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

  /// La traduction de la mesure en geste.
  ///
  /// Il n'a aucun etat : les seuils lui suffisent, et l'ecart lui vient de
  /// l'accordeur -- donc du diapason en cours, mesure ou de reference.
  static const TuningCoach _coach = TuningCoach();

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
    final TunerReading? lecture = _lecture;
    final TuningAdvice conseil = _coach.advise(lecture);
    final bool paysage =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return KeepScreenAwake(
      child: Scaffold(
        appBar: AppBar(title: const Text('Accorder')),
        body: SafeArea(
          child: Padding(
            key: const Key('tuner-content'),
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: paysage ? 8 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StringRow(
                  cordes: PitchUtils.violinOpenStrings,
                  active: lecture?.stringMidi,
                ),
                if (paysage)
                  // **Deux colonnes, et non une pile.** En paysage il reste
                  // moins de trois cent trente points de haut : la consigne,
                  // la jauge et les quintes ne tiennent pas l'une sous
                  // l'autre. La largeur, elle, ne manque pas.
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Expanded(child: _laConsigne(conseil, lecture)),
                        const SizedBox(width: 24),
                        Expanded(child: _laMesure(lecture)),
                      ],
                    ),
                  )
                else ...<Widget>[
                  const Spacer(),
                  _laConsigne(conseil, lecture),
                  const SizedBox(height: 16),
                  _laMesure(lecture),
                  const Spacer(),
                ],
                if (_probleme != null)
                  Text(
                    _probleme!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
  }

  /// Quelle corde, et quoi en faire.
  Widget _laConsigne(TuningAdvice conseil, TunerReading? lecture) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          lecture == null ? '--' : lecture.stringName,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        _Consigne(conseil: conseil),
        SizedBox(
          // Hauteur reservee : sans elle, tout le bloc sauterait de vingt
          // points des que l'archet se pose.
          height: 20,
          child: Text(
            _texteDesCents(lecture),
            key: const Key('tuner-cents'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// De combien, et ou en sont les quintes.
  Widget _laMesure(TunerReading? lecture) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TunerGauge(reading: lecture),
          const SizedBox(height: 16),
          _Quintes(quintes: OpenStringFifths.from(_cordesMesurees)),
        ],
      );

  /// La mesure, et rien d'autre.
  ///
  /// **Ce qu'il faut faire se lit au-dessus** ; cette ligne-ci ne porte que
  /// le chiffre, y compris quand la corde est juste -- "juste" sous une
  /// consigne qui dit deja "Juste" ne serait qu'un doublon, la ou "+2 cents"
  /// dit a quel point on a bien vise. Rien ne s'affiche tant que la hauteur
  /// ne tient pas : pendant un demarrage d'archet le chiffre danserait sans
  /// rien dire d'utile.
  static String _texteDesCents(TunerReading? lecture) {
    if (lecture == null || !lecture.steady) {
      return '';
    }
    final int cents = lecture.centsOffset.round();
    final String unite = cents.abs() <= 1 ? 'cent' : 'cents';
    return cents > 0 ? '+$cents $unite' : '$cents $unite';
  }
}

/// Ce qu'il faut faire de ses mains, en une phrase.
///
/// **C'est le lot O6 tout entier.** L'accordeur mesurait et affichait sans
/// jamais dire quoi faire ; il manquait quelle cheville, dans quel sens, et
/// quand s'arreter. Les deux premiers sont dans la phrase, le troisieme est
/// dans le fait que la phrase change toute seule -- la cheville, puis le
/// tendeur, puis plus rien.
///
/// **Aucun hertz ici.** L'ecart vient du diapason en cours, celui de
/// l'instrument s'il a ete adopte : dire "monte a 440" contredirait le
/// chiffre affiche juste en dessous.
class _Consigne extends StatelessWidget {
  const _Consigne({required this.conseil});

  final TuningAdvice conseil;

  static const Key consigneKey = Key('tuner-consigne');
  static const Key rappelKey = Key('tuner-rappel');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      // Une hauteur reservee, pas imposee : la consigne qui apparait ne doit
      // pousser la jauge ni vers le bas ni hors de l'ecran, et une phrase qui
      // passe a la ligne sur un ecran etroit doit pouvoir le faire.
      constraints: const BoxConstraints(minHeight: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            phrase(conseil),
            key: consigneKey,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 20,
              color: couleur(conseil) ?? theme.colorScheme.onSurface,
            ),
          ),
          if (conseil.action == TuningAction.peg)
            Text(
              // La faute que tout le monde fait a onze ans : tourner sans
              // enfoncer, et la cheville revient en arriere toute seule.
              'Enfonce la cheville en tournant, sinon elle glisse.',
              key: rappelKey,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  /// La phrase dite a l'enfant.
  static String phrase(TuningAdvice conseil) => switch (conseil.action) {
        TuningAction.play => 'Joue une corde a vide',
        TuningAction.hold => 'Tiens la note',
        TuningAction.stop => 'Juste. Ne touche plus a rien.',
        TuningAction.fineTuner =>
          '${_verbe(conseil)} le tendeur du ${_corde(conseil)}',
        TuningAction.peg =>
          '${_verbe(conseil)} la cheville du ${_corde(conseil)}',
      };

  /// Le sens, dans la couleur qui le dit deja ailleurs.
  ///
  /// Trop bas est bleu, trop haut est orange, juste est vert -- les memes
  /// trois couleurs que la partition et le ruban. Une consigne qui prendrait
  /// une quatrieme couleur pour dire la meme chose serait une couleur de
  /// plus a apprendre.
  static Color? couleur(TuningAdvice conseil) => switch (conseil.action) {
        TuningAction.stop => TuningColors.inTune,
        TuningAction.fineTuner ||
        TuningAction.peg =>
          conseil.turn == TuningTurn.tighten
              ? TuningColors.low
              : TuningColors.high,
        TuningAction.play || TuningAction.hold => null,
      };

  static String _verbe(TuningAdvice conseil) =>
      conseil.turn == TuningTurn.tighten ? 'Serre' : 'Desserre';

  /// "Sol3" designe une hauteur ; "sol" designe une corde, et c'est d'une
  /// corde qu'on parle quand on dit quelle cheville tourner.
  static String _corde(TuningAdvice conseil) =>
      PitchUtils.noteName(conseil.stringMidi!)
          .replaceAll(RegExp(r'\d'), '')
          .toLowerCase();
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
