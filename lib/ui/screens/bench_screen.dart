import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/bench_recorder.dart';
import '../widgets/keep_screen_awake.dart';

/// Une prise de la grille du banc (`docs/banc-d-essai.md`).
class BenchSlot {
  const BenchSlot(this.id, this.consigne);

  /// Le nom du fichier, identique a celui des metadonnees dans le banc.
  final String id;
  final String consigne;
}

/// Enregistrer les prises du banc d'essai. **Version de debug seulement.**
///
/// Pense pour le parent, telephone pose sur le pupitre : on choisit la prise,
/// on lit la consigne a l'enfant, un appui pour commencer, un pour finir.
class BenchScreen extends StatefulWidget {
  const BenchScreen({required this.recorder, super.key});

  final BenchRecorder recorder;

  static const Key enregistrerKey = Key('banc-enregistrer');
  static Key priseKey(String id) => Key('banc-prise-$id');
  static Key effacerKey(String name) => Key('banc-effacer-$name');

  static const List<BenchSlot> grille = <BenchSlot>[
    BenchSlot('01-gamme-detache', 'Gamme de sol, detache, tempo regulier'),
    BenchSlot('02-gamme-liee',
        'Gamme de sol, liee par deux en montant, par quatre en descendant'),
    BenchSlot('03-stars-notes-repetees', 'Into the Stars, mesures 1 a 4'),
    BenchSlot('04-stars-fluide', 'Into the Stars, du debut, sans consigne'),
    BenchSlot('05-stars-arret-reprise',
        'Into the Stars : s arreter et reprendre la mesure difficile'),
    BenchSlot('06-stars-saut-arriere',
        'Into the Stars : reprendre deux fois au debut de la phrase (m. 15)'),
    BenchSlot('07-piece-b-seance', 'Piece B, vraie seance, sans consigne'),
    BenchSlot('08-piece-b-lent', 'Piece B, tres lent, comme pour dechiffrer'),
    BenchSlot('09-piece-b-erreurs',
        'Piece B : une note fausse, une sautee, une ajoutee, expres'),
    BenchSlot('10-stars-vibrato',
        'Into the Stars, notes longues avec vibrato (m. 21-22, 29)'),
    BenchSlot(
        '11-stars-bruit', 'Comme la 04, avec une voix ou la tele en fond'),
    BenchSlot('12-doubles-cordes', 'Un passage en doubles cordes'),
  ];

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  String _prise = BenchScreen.grille.first.id;
  List<BenchTake> _faites = const <BenchTake>[];
  bool _enregistre = false;
  double _niveau = -160;
  double _crete = -160;
  final Stopwatch _chrono = Stopwatch();
  Timer? _minuteur;
  StreamSubscription<double>? _ecoute;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    unawaited(_relire());
  }

  Future<void> _relire() async {
    final List<BenchTake> faites = await widget.recorder.takes();
    if (mounted) {
      setState(() => _faites = faites);
    }
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    unawaited(_ecoute?.cancel());
    if (_enregistre) {
      unawaited(widget.recorder.stop());
    }
    unawaited(widget.recorder.dispose());
    super.dispose();
  }

  Future<void> _basculer() async {
    if (_enregistre) {
      _minuteur?.cancel();
      unawaited(_ecoute?.cancel());
      _chrono.stop();
      await widget.recorder.stop();
      setState(() => _enregistre = false);
      await _relire();
      return;
    }
    if (!await widget.recorder.hasPermission()) {
      setState(() => _erreur = 'Le micro n est pas autorise.');
      return;
    }
    await widget.recorder.start(_prise);
    _ecoute = widget.recorder.level().listen((double db) {
      setState(() {
        _niveau = db;
        if (db > _crete) {
          _crete = db;
        }
      });
    });
    _chrono
      ..reset()
      ..start();
    _minuteur = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
    setState(() {
      _enregistre = true;
      _erreur = null;
      _crete = -160;
    });
  }

  static String _duree(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BenchSlot slot =
        BenchScreen.grille.firstWhere((BenchSlot s) => s.id == _prise);
    final Set<String> faites = <String>{
      for (final BenchTake t in _faites) t.name.replaceAll(RegExp(r'-\d$'), ''),
    };
    return KeepScreenAwake(
      actif: _enregistre,
      child: Scaffold(
        appBar: AppBar(title: const Text('Banc d essai')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Text(
                      'Version de debug seulement. WAV 44,1 kHz mono, micro '
                      'non traite. Les prises restent dans l application '
                      'jusqu a tool/prises.sh, qui les rapatrie et les efface.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    for (final BenchSlot s in BenchScreen.grille)
                      ListTile(
                        key: BenchScreen.priseKey(s.id),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        selected: _prise == s.id,
                        leading: Icon(_prise == s.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                        onTap: _enregistre
                            ? null
                            : () => setState(() => _prise = s.id),
                        title: Text(s.id),
                        subtitle: Text(s.consigne),
                        trailing: faites.contains(s.id)
                            ? const Icon(Icons.check, size: 20)
                            : null,
                      ),
                    if (_faites.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Text('Sur le telephone',
                          style: theme.textTheme.titleSmall),
                      for (final BenchTake t in _faites)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.name),
                          subtitle: Text(_duree(t.duration)),
                          trailing: IconButton(
                            key: BenchScreen.effacerKey(t.name),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Effacer',
                            onPressed: _enregistre
                                ? null
                                : () async {
                                    await widget.recorder.delete(t.name);
                                    await _relire();
                                  },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(slot.consigne, style: theme.textTheme.titleSmall),
                    if (_enregistre) ...<Widget>[
                      const SizedBox(height: 8),
                      // Le niveau sert a placer le telephone : trop bas, les
                      // attaques se noient ; au plafond, la prise sature.
                      LinearProgressIndicator(
                        value: ((_niveau + 60) / 60).clamp(0, 1),
                        color: _crete > -1 ? theme.colorScheme.error : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_duree(_chrono.elapsed)}   crete '
                        '${_crete.toStringAsFixed(0)} dBFS'
                        '${_crete > -1 ? ' - sature, eloigner' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (_erreur != null)
                      Text(_erreur!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: BenchScreen.enregistrerKey,
                      onPressed: () => unawaited(_basculer()),
                      icon: Icon(
                          _enregistre ? Icons.stop : Icons.fiber_manual_record),
                      label: Text(_enregistre ? 'Terminer' : 'Enregistrer'),
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
