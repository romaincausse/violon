import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/play/audio_engine.dart';
import '../../core/store/game_records.dart';
import 'echo_screen.dart';
import 'long_tone_screen.dart';
import 'pulse_screen.dart';
import 'vibrato_screen.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Les jeux (jalon 14) : cinq facons de jouer du violon pour le plaisir de
/// battre son propre record.
///
/// **Pas de mascotte, pas de confettis** (CLAUDE.md) : un record, un
/// chiffre, et il ne redescend jamais. Chaque jeu travaille une chose que la
/// seance travaille aussi -- l'oreille, le son file, la pulsation -- sous une
/// forme qui donne envie d'y revenir.
class GamesScreen extends StatefulWidget {
  const GamesScreen({
    required this.passage,
    required this.engine,
    required this.pitchSourceFactory,
    this.store,
    this.a4 = PitchUtils.defaultA4,
    super.key,
  });

  /// Le morceau du moment : ses notes nourrissent l'echo et la note tenue.
  final Passage passage;
  final AudioEngine engine;
  final PitchSourceFactory pitchSourceFactory;

  /// Ou garder les records. `null` : ils vivent le temps de l'ecran.
  final GameStore? store;
  final double a4;

  static const Key echoKey = Key('jeu-echo');
  static const Key tenueKey = Key('jeu-note-tenue');
  static const Key pulsationKey = Key('jeu-tempo-cache');
  static const Key cordesKey = Key('jeu-cordes-a-vide');
  static const Key vibratoKey = Key('jeu-vibrato');

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameRecords _records = GameRecords.vide;

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  Future<void> _charger() async {
    final GameStore? s = widget.store;
    if (s == null) {
      return;
    }
    final GameRecords r = await s.load();
    if (mounted) {
      setState(() => _records = r);
    }
  }

  /// Un record ne baisse jamais : on fusionne, puis on range.
  void _retenir({
    int? echo,
    int? longToneMs,
    int? pulse,
    int? evenBowMs,
    int? vibratoMs,
  }) {
    setState(() {
      _records = _records.merge(
        echo: echo,
        longToneMs: longToneMs,
        pulse: pulse,
        evenBowMs: evenBowMs,
        vibratoMs: vibratoMs,
      );
    });
    final GameStore? s = widget.store;
    if (s != null) {
      unawaited(s.save(_records).catchError((Object _) {}));
    }
  }

  /// Les notes du morceau, ou la premiere position en sol majeur s'il en a
  /// trop peu.
  List<int> get _notes {
    final List<int> du = <int>{
      for (final n in widget.passage.notes)
        if (n.midi >= 55 && n.midi <= 88) n.midi,
    }.toList()
      ..sort();
    return du.length >= 4
        ? du
        : const <int>[55, 57, 59, 60, 62, 64, 66, 67, 69, 71, 72, 74];
  }

  Future<void> _ouvrir(WidgetBuilder b) =>
      Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: b));

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double tenue = _records.longToneBestMs / 1000;
    final double archet = _records.evenBowBestMs / 1000;
    final double vibre = _records.vibratoBestMs / 1000;
    return Scaffold(
      appBar: AppBar(title: const Text('Jeux')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Un record a battre, et il ne redescend jamais.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _Carte(
              key: GamesScreen.echoKey,
              icone: Icons.hearing,
              titre: 'L echo',
              detail: 'Elle joue un motif, tu le rejoues. Il s allonge '
                  'a chaque fois.',
              record: _records.echoBest == 0
                  ? 'Pas encore de record'
                  : 'Record : ${_records.echoBest} notes',
              onTap: () => _ouvrir(
                (BuildContext c) => EchoScreen(
                  pool: _notes,
                  engine: widget.engine,
                  pitchSourceFactory: widget.pitchSourceFactory,
                  a4: widget.a4,
                  best: _records.echoBest,
                  onBest: (int n) => _retenir(echo: n),
                ),
              ),
            ),
            _Carte(
              key: GamesScreen.tenueKey,
              icone: Icons.linear_scale,
              titre: 'Tiens la note',
              detail: 'Une note, juste a dix cents pres, le plus longtemps '
                  'possible.',
              record: _records.longToneBestMs == 0
                  ? 'Pas encore de record'
                  : 'Record : ${tenue.toStringAsFixed(1)} s',
              onTap: () => _ouvrir(
                (BuildContext c) => LongToneScreen(
                  notes: _notes,
                  pitchSourceFactory: widget.pitchSourceFactory,
                  a4: widget.a4,
                  bestMs: _records.longToneBestMs,
                  onBest: (int ms) => _retenir(longToneMs: ms),
                  evenBowBestMs: _records.evenBowBestMs,
                  onEvenBowBest: (int ms) => _retenir(evenBowMs: ms),
                ),
              ),
            ),
            _Carte(
              key: GamesScreen.cordesKey,
              icone: Icons.graphic_eq,
              titre: 'Cordes a vide',
              detail: 'Un archet entier, lent : seul le son compte, egal du '
                  'debut a la fin.',
              record: _records.evenBowBestMs == 0
                  ? 'Pas encore de record'
                  : 'Record : ${archet.toStringAsFixed(1)} s',
              onTap: () => _ouvrir(
                (BuildContext c) => LongToneScreen(
                  notes: const <int>[],
                  openStrings: true,
                  pitchSourceFactory: widget.pitchSourceFactory,
                  a4: widget.a4,
                  evenBowBestMs: _records.evenBowBestMs,
                  onEvenBowBest: (int ms) => _retenir(evenBowMs: ms),
                ),
              ),
            ),
            _Carte(
              key: GamesScreen.vibratoKey,
              icone: Icons.waves,
              titre: 'Le vibrato',
              detail: 'Deux, trois, quatre oscillations par temps, sur un '
                  'pouls qu on voit : la plus longue note vibree regulierement.',
              record: _records.vibratoBestMs == 0
                  ? 'Pas encore de record'
                  : 'Record : ${vibre.toStringAsFixed(1)} s',
              onTap: () => _ouvrir(
                (BuildContext c) => VibratoScreen(
                  pitchSourceFactory: widget.pitchSourceFactory,
                  bestMs: _records.vibratoBestMs,
                  onBest: (int ms) => _retenir(vibratoMs: ms),
                ),
              ),
            ),
            _Carte(
              key: GamesScreen.pulsationKey,
              icone: Icons.timer_outlined,
              titre: 'Le tempo cache',
              detail: 'Quatre clics, puis le silence : continue seul huit '
                  'temps.',
              record: _records.pulseBest == 0
                  ? 'Pas encore de record'
                  : 'Record : ${_records.pulseBest} sur 100',
              onTap: () => _ouvrir(
                (BuildContext c) => PulseScreen(
                  bpm: widget.passage.pulseBpm,
                  engine: widget.engine,
                  pitchSourceFactory: widget.pitchSourceFactory,
                  best: _records.pulseBest,
                  onBest: (int s) => _retenir(pulse: s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({
    required this.icone,
    required this.titre,
    required this.detail,
    required this.record,
    required this.onTap,
    super.key,
  });

  final IconData icone;
  final String titre;
  final String detail;
  final String record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(icone, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(titre, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(detail, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      record,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
