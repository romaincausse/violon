import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pcm_take.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/audio/take_player.dart';
import '../../core/store/document_saver.dart';
import '../../core/store/take_sharer.dart';
import '../widgets/keep_screen_awake.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Jouer pour quelqu'un (lot V7, ADR-018).
///
/// **La seule exception a "rien n'est conserve", et c'est l'enfant qui la
/// declenche.** Il joue ce qu'il veut, on enregistre, il se reecoute, et
/// c'est lui qui decide qui l'entend : par le partage du telephone, ou dans
/// un fichier qu'il choisit. Rien n'est note ici, et rien ne reste : la prise
/// vit en memoire le temps de l'ecran et meurt avec lui.
///
/// **Le micro n'ecoute pas pendant qu'on se reecoute** (ADR-008) : ici il ne
/// sert qu'a enregistrer, et il est ferme des que la prise est finie.
class ConcertScreen extends StatefulWidget {
  const ConcertScreen({
    required this.pitchSourceFactory,
    required this.takePlayerFactory,
    this.sharer,
    this.saver,
    this.title,
    this.clock = DateTime.now,
    super.key,
  });

  final PitchSourceFactory pitchSourceFactory;
  final TakePlayerFactory takePlayerFactory;

  /// Pour envoyer la prise. `null` : le bouton n'existe pas.
  final TakeSharer? sharer;

  /// Pour la ranger dans un fichier. `null` : le bouton n'existe pas.
  final DocumentSaver? saver;

  /// Le morceau du moment, pour nommer le fichier. Il joue ce qu'il veut.
  final String? title;

  /// L'horloge, pour dater le fichier ; injectable pour les tests.
  final DateTime Function() clock;

  /// Au-dela, la prise s'arrete seule : un concert n'est pas une repetition.
  static const int maxSeconds = 300;

  static const Key jouerKey = Key('concert-jouer');
  static const Key reecouterKey = Key('concert-reecouter');
  static const Key envoyerKey = Key('concert-envoyer');
  static const Key garderKey = Key('concert-garder');
  static const Key recommencerKey = Key('concert-recommencer');
  static const Key etatKey = Key('concert-etat');

  @override
  State<ConcertScreen> createState() => _ConcertScreenState();
}

enum _Etat { pret, enregistre, fini }

class _ConcertScreenState extends State<ConcertScreen> {
  _Etat _etat = _Etat.pret;
  String? _message;
  PitchSource? _source;
  StreamSubscription<Uint8List>? _octets;
  final PcmTake _prise = PcmTake(maxSeconds: ConcertScreen.maxSeconds);
  Uint8List? _wav;
  late final TakePlayer _liseur = widget.takePlayerFactory();
  bool _relecture = false;

  /// Le temps qui passe, pour l'afficher : un minuteur d'affichage, pas de
  /// son -- la prise, elle, est datee par ses octets.
  final Stopwatch _chrono = Stopwatch();
  Timer? _tic;

  Future<void> _commencer() async {
    _prise.reset();
    _wav = null;
    setState(() {
      _message = null;
      _etat = _Etat.enregistre;
    });
    try {
      final PitchSource source = await widget.pitchSourceFactory();
      if (!mounted) {
        await source.dispose();
        return;
      }
      _source = source;
      _octets = source.audio.listen(_prise.add);
      await source.start();
    } on MicPermissionDenied {
      _revenir('Le micro est refuse : impossible d enregistrer.');
      return;
    }
    _chrono
      ..reset()
      ..start();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_chrono.elapsed.inSeconds >= ConcertScreen.maxSeconds) {
        unawaited(_finir());
        return;
      }
      setState(() {});
    });
  }

  Future<void> _finir() async {
    _tic?.cancel();
    _tic = null;
    _chrono.stop();
    await _fermerLeMicro();
    final Uint8List? wav = _prise.wav();
    if (wav == null) {
      _revenir('Je n ai rien entendu. On recommence quand tu veux.');
      return;
    }
    if (mounted) {
      setState(() {
        _wav = wav;
        _etat = _Etat.fini;
      });
    }
  }

  void _revenir(String message) {
    if (mounted) {
      setState(() {
        _etat = _Etat.pret;
        _message = message;
      });
    }
  }

  Future<void> _fermerLeMicro() async {
    final PitchSource? s = _source;
    _source = null;
    unawaited(_octets?.cancel());
    _octets = null;
    await s?.dispose();
  }

  Future<void> _reecouter() async {
    final Uint8List? wav = _wav;
    if (wav == null || _relecture) {
      return;
    }
    setState(() => _relecture = true);
    try {
      await _liseur.play(wav);
    } finally {
      if (mounted) {
        setState(() => _relecture = false);
      }
    }
  }

  Future<void> _envoyer() async {
    final Uint8List? wav = _wav;
    final TakeSharer? s = widget.sharer;
    if (wav == null || s == null) {
      return;
    }
    final bool ok = await s.share(_nom(), wav);
    if (mounted) {
      setState(() => _message = ok
          ? 'A toi de choisir a qui l envoyer.'
          : 'Le partage n a pas pu s ouvrir.');
    }
  }

  Future<void> _garder() async {
    final Uint8List? wav = _wav;
    final DocumentSaver? s = widget.saver;
    if (wav == null || s == null) {
      return;
    }
    final bool ok = await s.save(_nom(), wav, mimeType: 'audio/wav');
    if (mounted) {
      setState(() => _message = ok ? 'Rangee.' : 'Pas rangee.');
    }
  }

  void _recommencer() {
    _prise.reset();
    setState(() {
      _wav = null;
      _message = null;
      _etat = _Etat.pret;
    });
  }

  /// `concert-into-the-stars-2026-10-02.wav` : lisible par celui qui le
  /// recoit, sans accent ni espace pour le systeme qui le range.
  String _nom() {
    final DateTime d = widget.clock();
    final String date = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final String titre = (widget.title ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return titre.isEmpty ? 'concert-$date.wav' : 'concert-$titre-$date.wav';
  }

  String _duree(Duration d) {
    final int s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tic?.cancel();
    unawaited(_fermerLeMicro());
    unawaited(_liseur.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return KeepScreenAwake(
      actif: _etat == _Etat.enregistre,
      child: Scaffold(
        appBar: AppBar(title: const Text('Concert')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Tu joues, on enregistre, et c est toi qui decides qui '
                  'l entend. Rien n est note ici, et l application ne garde '
                  'rien.',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  switch (_etat) {
                    _Etat.pret => 'Quand tu veux.',
                    _Etat.enregistre =>
                      'Je t ecoute... ${_duree(_chrono.elapsed)}',
                    _Etat.fini => _relecture
                        ? 'Tu t ecoutes.'
                        : 'Ta prise : ${_duree(_prise.duration)}',
                  },
                  key: ConcertScreen.etatKey,
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
                ..._boutons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _boutons() {
    switch (_etat) {
      case _Etat.pret:
        return <Widget>[
          FilledButton.icon(
            key: ConcertScreen.jouerKey,
            onPressed: () => unawaited(_commencer()),
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Je joue'),
          ),
        ];
      case _Etat.enregistre:
        return <Widget>[
          FilledButton.icon(
            key: ConcertScreen.jouerKey,
            onPressed: () => unawaited(_finir()),
            icon: const Icon(Icons.stop),
            label: const Text('C est fini'),
          ),
        ];
      case _Etat.fini:
        return <Widget>[
          FilledButton.tonalIcon(
            key: ConcertScreen.reecouterKey,
            onPressed: _relecture
                ? () => unawaited(_liseur.stop())
                : () => unawaited(_reecouter()),
            icon: Icon(_relecture ? Icons.stop : Icons.replay),
            label: Text(_relecture ? 'Arreter' : 'Me reecouter'),
          ),
          const SizedBox(height: 8),
          if (widget.sharer != null)
            FilledButton.icon(
              key: ConcertScreen.envoyerKey,
              onPressed: _relecture ? null : () => unawaited(_envoyer()),
              icon: const Icon(Icons.send),
              label: const Text('L envoyer a quelqu un'),
            ),
          if (widget.saver != null) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: ConcertScreen.garderKey,
              onPressed: _relecture ? null : () => unawaited(_garder()),
              icon: const Icon(Icons.save_alt),
              label: const Text('La garder dans un fichier'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            key: ConcertScreen.recommencerKey,
            onPressed: _relecture ? null : _recommencer,
            child: const Text('Recommencer'),
          ),
        ];
    }
  }
}
