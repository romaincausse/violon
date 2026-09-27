import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/audio/pcm_take.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/audio/take_player.dart';
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
///
/// **C'est aussi le seul ecran ou l'on peut s'entendre.** S'ecouter jouer est
/// l'exercice le plus efficace qui soit, et le plus desagreable : on joue
/// toujours moins juste qu'on ne le croyait. Sa place est ici, ou rien n'est
/// note -- ailleurs, ce serait une sanction de plus.
class FreePlayScreen extends StatefulWidget {
  const FreePlayScreen({
    required this.pitchSourceFactory,
    required this.takePlayerFactory,
    this.a4,
    super.key,
  });

  final PitchSourceFactory pitchSourceFactory;

  /// Fabrique du liseur de prise.
  final TakePlayerFactory takePlayerFactory;

  /// Diapason mesure par l'accordeur, s'il l'a ete.
  final double? a4;

  static const Key noteKey = Key('libre-note');
  static const Key centsKey = Key('libre-cents');
  static const Key reecouteKey = Key('libre-reecoute');

  @override
  State<FreePlayScreen> createState() => _FreePlayScreenState();
}

class _FreePlayScreenState extends State<FreePlayScreen> {
  PitchSource? _source;
  StreamSubscription<SmoothedPitch>? _abonnement;
  StreamSubscription<Uint8List>? _octets;
  final TuningTrace _trace = TuningTrace();
  SmoothedPitch? _dernier;
  double _ecart = 0;

  /// Les dernieres secondes jouees, gardees pour etre reecoutees.
  final PcmTake _prise = PcmTake();

  late final TakePlayer _liseur = widget.takePlayerFactory();

  /// Vrai pendant qu'on se reecoute.
  ///
  /// **Le micro est alors ferme.** L'application emet ou elle ecoute, jamais
  /// les deux (ADR-008) : laisser le micro ouvert lui ferait reentendre la
  /// relecture, et le retour en direct se mettrait a commenter le
  /// haut-parleur.
  bool _relecture = false;

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
      // Les memes octets partent vers l'analyse et vers la prise : un seul
      // micro, deux usages.
      _octets = source.audio.listen(_garder);
      await source.start();
    } catch (_) {
      // Le mode libre n'a rien a annoncer : sans micro, l'ecran reste muet
      // plutot que d'afficher une erreur qu'on ne peut pas corriger d'ici.
    }
  }

  /// Garde les octets, et ne redessine qu'au moment ou le bouton change d'etat.
  ///
  /// **Pas a chaque trame.** Vingt fois par seconde, un `setState` pour une
  /// information qui ne bouge qu'une fois par phrase serait payer cher un
  /// bouton gris. Et pas non plus sur l'arrivee d'une hauteur : un coup
  /// d'archet peut s'entendre sans que YIN en tire une note, et le bouton
  /// resterait eteint sur du son bien reel.
  void _garder(Uint8List octets) {
    final bool avant = _prise.hasSound;
    _prise.add(octets);
    if (mounted && _prise.hasSound != avant) {
      setState(() {});
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

  /// Rejoue ce qu'on vient de jouer.
  ///
  /// **Le micro se ferme d'abord et se rouvre apres**, et l'ecran attend que
  /// le son soit fini pour le rouvrir : c'est l'ADR-008 applique a la lettre.
  ///
  /// La prise se vide ensuite. "Ce que tu viens de jouer" veut dire depuis la
  /// derniere ecoute ; sans cet oubli, la fois suivante rejouerait la
  /// precedente collee devant.
  Future<void> _seReecouter() async {
    final Uint8List? wav = _prise.wav();
    if (wav == null || _relecture) {
      return;
    }
    setState(() => _relecture = true);
    await _source?.stop();
    try {
      await _liseur.play(wav);
    } finally {
      _prise.reset();
      if (mounted) {
        setState(() => _relecture = false);
        await _source?.start();
      }
    }
  }

  @override
  void dispose() {
    final PitchSource? source = _source;
    final StreamSubscription<SmoothedPitch>? abonnement = _abonnement;
    final StreamSubscription<Uint8List>? octets = _octets;
    _source = null;
    _abonnement = null;
    _octets = null;
    if (abonnement != null) {
      unawaited(abonnement.cancel());
    }
    if (octets != null) {
      unawaited(octets.cancel());
    }
    unawaited(_liseur.dispose());
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
            // Meme gouttiere que la seance : la largeur se paie en secondes
            // lisibles sur le ruban.
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
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
                  _relecture
                      ? 'tu t ecoutes'
                      : p == null
                          ? 'joue ce que tu veux'
                          : '${_ecart >= 0 ? '+' : ''}${_ecart.round()} cents',
                  key: FreePlayScreen.centsKey,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: p == null || _relecture ? null : _couleur(),
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                TuningRibbon(trace: _trace, height: 96),
                const SizedBox(height: 16),
                _boutonDeRelecture(),
                const SizedBox(height: 12),
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

  /// Un seul bouton, qui dit ce qu'il fera.
  ///
  /// **Rien a armer avant de jouer.** La prise tourne en permanence : un
  /// bouton "enregistrer" couterait trois gestes, archet en main, et il
  /// oublierait de l'appuyer avant la seule phrase qui valait la peine.
  Widget _boutonDeRelecture() {
    if (_relecture) {
      return FilledButton.icon(
        key: FreePlayScreen.reecouteKey,
        onPressed: () => unawaited(_liseur.stop()),
        icon: const Icon(Icons.stop),
        label: const Text('Arreter'),
      );
    }
    return FilledButton.tonalIcon(
      key: FreePlayScreen.reecouteKey,
      onPressed: _prise.hasSound ? () => unawaited(_seReecouter()) : null,
      icon: const Icon(Icons.replay),
      label: const Text('Se reecouter'),
    );
  }

  Color _couleur() {
    if (_ecart.abs() <= 10) {
      return TuningColors.inTune;
    }
    return _ecart < 0 ? TuningColors.low : TuningColors.high;
  }
}
