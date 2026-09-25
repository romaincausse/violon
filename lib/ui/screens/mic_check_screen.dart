import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/music/pitch_utils.dart';
import '../widgets/tuning_colors.dart';
import 'session_screen.dart' show PitchSourceFactory;
import '../widgets/keep_screen_awake.dart';

/// "Est-ce qu'elle m'entend bien ?"
///
/// **C'est le premier soupcon de l'utilisateur** quand un score le surprend,
/// et le probleme numero un de toutes les applications d'ecoute. Y repondre
/// sans deviner demande de montrer ce que la machine entend vraiment : la
/// hauteur detectee, la confiance, la source audio obtenue, et les trames
/// perdues.
///
/// Double usage : il rassure l'eleve, et il sert de banc de diagnostic quand
/// quelque chose cloche sur un appareil qu'on n'a pas sous la main.
class MicCheckScreen extends StatefulWidget {
  const MicCheckScreen({required this.pitchSourceFactory, super.key});

  final PitchSourceFactory pitchSourceFactory;

  static const Key noteKey = Key('micro-note');
  static const Key sourceKey = Key('micro-source');
  static const Key droppedKey = Key('micro-trames-perdues');
  static const Key confidenceKey = Key('micro-confiance');

  @override
  State<MicCheckScreen> createState() => _MicCheckScreenState();
}

class _MicCheckScreenState extends State<MicCheckScreen> {
  PitchSource? _source;
  StreamSubscription<SmoothedPitch>? _abonnement;
  SmoothedPitch? _dernier;
  String _sourceLabel = 'ouverture...';
  int _perdues = 0;
  Object? _echec;

  /// Combien de mesures fiables ont ete vues depuis l'ouverture.
  ///
  /// Un compteur qui monte pendant qu'on joue est la preuve la plus simple
  /// que la chaine fonctionne : plus convaincante qu'un niveau qui bouge,
  /// lequel bouge aussi avec le bruit de la piece.
  int _mesures = 0;

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
      if (mounted) {
        setState(() => _sourceLabel = source.sourceLabel);
      }
    } catch (erreur) {
      if (mounted) {
        setState(() => _echec = erreur);
      }
    }
  }

  void _onPitch(SmoothedPitch pitch) {
    if (!mounted) {
      return;
    }
    setState(() {
      _dernier = pitch;
      _mesures++;
      _sourceLabel = _source?.sourceLabel ?? _sourceLabel;
      _perdues = _source?.droppedFrames ?? 0;
    });
  }

  @override
  void dispose() {
    final PitchSource? source = _source;
    final StreamSubscription<SmoothedPitch>? abonnement = _abonnement;
    _source = null;
    _abonnement = null;
    // Annuler sans attendre : la promesse d'un `cancel` n'est tenue qu'une
    // fois le flux ferme, et l'attendre ici bloquerait la fermeture.
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
    return KeepScreenAwake(
      child: Scaffold(
        appBar: AppBar(title: const Text('Est-ce qu elle m entend ?')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _echec != null
                ? Center(
                    child: Text(
                      'Micro indisponible. Verifie que l autorisation est '
                      'accordee dans les reglages du telephone.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Joue une note, n importe laquelle.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        p == null
                            ? '--'
                            : PitchUtils.noteName(p.estimate.nearestMidi),
                        key: MicCheckScreen.noteKey,
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: p == null
                              ? theme.colorScheme.outline
                              : TuningColors.inTune,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        p == null
                            ? 'rien entendu pour l instant'
                            : '${p.frequencyHz.toStringAsFixed(1)} Hz',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      _Ligne(
                        cle: MicCheckScreen.sourceKey,
                        titre: 'Source audio',
                        valeur: _sourceLabel,
                      ),
                      _Ligne(
                        cle: MicCheckScreen.confidenceKey,
                        titre: 'Mesures recues',
                        valeur: '$_mesures',
                      ),
                      _Ligne(
                        cle: MicCheckScreen.droppedKey,
                        titre: 'Trames perdues',
                        valeur: '$_perdues',
                      ),
                      if (p != null)
                        _Ligne(
                          titre: 'Stabilite',
                          valeur: p.vibrato
                              ? 'vibrato reconnu'
                              : '${p.excursionCents.round()} cents',
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.titre, required this.valeur, this.cle});

  final String titre;
  final String valeur;
  final Key? cle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              titre,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            valeur,
            key: cle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
