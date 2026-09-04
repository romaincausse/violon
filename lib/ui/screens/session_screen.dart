import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_estimate.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/follow/score_cursor.dart';
import '../../core/music/passage.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/music/score_note.dart';
import '../../core/scoring/live_tuning.dart';
import '../../platform/audio/default_pitch_source.dart';
import '../widgets/metronome_bar.dart';
import '../widgets/score_view.dart';
import '../widgets/tuning_colors.dart';

/// Construit la source de hauteurs. Injectable pour les tests et pour le
/// developpement de l'interface, ou l'on ne veut pas du vrai micro.
typedef PitchSourceFactory = Future<PitchSource> Function();

/// Ce que le micro a pu faire au dernier demarrage.
enum _MicState { arrete, ecoute, refuse, indisponible }

/// Nombre de systemes que l'ecran peut porter sans que les notes retrecissent
/// jusqu'a l'illisible.
///
/// En portrait, la hauteur est la ressource abondante : quatre lignes tiennent
/// largement. En paysage c'est l'inverse -- beaucoup de largeur, peu de
/// hauteur -- donc deux lignes larges valent mieux que quatre lignes ecrasees.
int maxSystemsFor(Orientation orientation) =>
    orientation == Orientation.portrait ? 4 : 2;

/// Ecran de travail : le passage, le curseur, et ce qu'on entend.
///
/// **Mode notation** au sens de l'ADR-008 : le micro est ouvert et
/// l'application n'emet aucun son. Le metronome est visuel, et il le reste.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    required this.passage,
    required this.onChangePassage,
    required this.onTune,
    this.a4 = PitchUtils.defaultA4,
    this.pitchSourceFactory = defaultPitchSource,
    super.key,
  });

  final Passage passage;

  /// Ouvre la saisie d'un autre passage.
  final VoidCallback onChangePassage;

  /// Ouvre l'accordeur.
  final VoidCallback onTune;

  /// Diapason de reference, mesure par l'accordeur ou laisse a 440.
  ///
  /// C'est lui qui rend la justesse **relative** : juger les doigts contre
  /// une reference absolue punirait l'enfant pour l'accord de son instrument.
  final double a4;

  final PitchSourceFactory pitchSourceFactory;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  bool _running = false;
  Duration _elapsed = Duration.zero;

  late LiveTuning _tuning = LiveTuning(a4: widget.a4);
  ScoreDisplayMode _mode = ScoreDisplayMode.systems;
  double _zoom = 1;

  /// Doigts poses sur la partition, par identifiant de pointeur.
  final Map<int, Offset> _doigts = <int, Offset>{};

  /// Ecart entre les deux doigts au debut du pincement, et zoom a cet
  /// instant. On repart de la valeur d'avant le geste : multiplier le zoom
  /// courant a chaque image le ferait exploser des le premier mouvement.
  double? _ecartInitial;
  double _zoomAuDebutDuGeste = 1;
  PitchSource? _source;
  StreamSubscription<PitchEstimate>? _abonnement;
  _MicState _mic = _MicState.arrete;

  ScoreCursor get _cursor => ScoreCursor(
        passage: widget.passage,
        tempoBpm: widget.passage.writtenTempoBpm,
      );

  void _onTick(Duration elapsed) {
    // La lecture s'arrete d'elle-meme sur la derniere note : on termine sur
    // la fin du passage, pas sur un bouton qu'il faudrait penser a presser.
    if (_cursor.isFinishedAt(elapsed)) {
      _stop();
      return;
    }
    setState(() => _elapsed = elapsed);
  }

  void _start() {
    setState(() {
      _elapsed = Duration.zero;
      _running = true;
      _tuning.reset();
    });
    _ticker.start();
    unawaited(_ouvrirLeMicro());
  }

  /// Ouvre le micro **sans bloquer le depart**.
  ///
  /// Le curseur part tout de suite : demander une permission peut prendre
  /// plusieurs secondes, et faire attendre l'enfant devant un ecran fige
  /// serait exactement la friction que le projet cherche a supprimer. Si le
  /// micro n'aboutit pas, le passage defile quand meme, sans coloration.
  Future<void> _ouvrirLeMicro() async {
    try {
      final PitchSource source = await widget.pitchSourceFactory();
      if (!mounted || !_running) {
        await source.dispose();
        return;
      }
      _source = source;
      _abonnement = source.pitches.listen(_onPitch);
      await source.start();
      if (mounted) {
        setState(() => _mic = _MicState.ecoute);
      }
    } on MicPermissionDenied {
      if (mounted) {
        setState(() => _mic = _MicState.refuse);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _mic = _MicState.indisponible);
      }
    }
  }

  /// Attribue ce qu'on entend a la note sur laquelle le curseur se trouve.
  ///
  /// L'attribution se fait a l'arrivee de la mesure, pas a son horodatage :
  /// la capture et le curseur ne demarrent pas exactement au meme instant, et
  /// tant que la latence n'est pas calibree (lot A4), prendre l'horodatage du
  /// micro donnerait une fausse precision. A 46 ms par trame, l'ecart ne se
  /// voit pas sur une coloration.
  void _onPitch(PitchEstimate estimate) {
    if (!_running) {
      return;
    }
    final ScoreNote? note = _cursor.noteAt(_elapsed);
    if (note == null) {
      return;
    }
    setState(
      () => _tuning.observe(
        note,
        estimate,
        sinceNoteStartMs: _depuisLeDebutDeLaNote(note),
      ),
    );
  }

  /// Depuis combien de temps la note en cours a commence, en millisecondes.
  ///
  /// Sert a ecarter l'attaque : pendant qu'un archet se pose, la hauteur
  /// glisse sur des dizaines de cents avant de se fixer.
  int _depuisLeDebutDeLaNote(ScoreNote note) {
    final int ticks = _cursor.tickAt(_elapsed) - note.onsetTicks;
    return ticks *
        60 *
        1000 ~/
        (widget.passage.writtenTempoBpm * widget.passage.ticksPerBeat);
  }

  void _stop() {
    _ticker.stop();
    unawaited(_fermerLeMicro());
    setState(() {
      _running = false;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _fermerLeMicro() async {
    final PitchSource? source = _source;
    final StreamSubscription<PitchEstimate>? abonnement = _abonnement;
    _source = null;
    _abonnement = null;
    // Annuler sans attendre. Un abonnement cesse de livrer des l'appel ; la
    // promesse rendue, elle, n'est tenue qu'une fois le flux ferme. L'attendre
    // avant de fermer la source bloquait donc les deux : le micro restait
    // ouvert et l'ecran croyait encore ecouter.
    if (abonnement != null) {
      unawaited(abonnement.cancel());
    }
    await source?.dispose();
    if (mounted) {
      setState(() => _mic = _MicState.arrete);
    }
  }

  @override
  void didUpdateWidget(SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changer de passage arrete la lecture : ni le tempo ni les notes ne sont
    // les memes, et laisser courir l'ancienne induirait en erreur.
    if (widget.passage != oldWidget.passage && _running) {
      _stop();
    }
    // Un nouveau diapason change tous les verdicts : les couleurs deja
    // affichees ont ete calculees contre l'ancien.
    if (widget.a4 != oldWidget.a4) {
      setState(() => _tuning = LiveTuning(a4: widget.a4));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_fermerLeMicro());
    super.dispose();
  }

  Color? _couleurDe(ScoreNote note) =>
      TuningColors.of(_tuning.verdictFor(note.id));

  void _changerDeMode() {
    setState(() {
      _mode = _mode == ScoreDisplayMode.systems
          ? ScoreDisplayMode.scrolling
          : ScoreDisplayMode.systems;
    });
  }

  void _doigtPose(PointerDownEvent event) {
    _doigts[event.pointer] = event.position;
    _ouvrirLePincement();
  }

  void _doigtBouge(PointerMoveEvent event) {
    if (!_doigts.containsKey(event.pointer)) {
      return;
    }
    _doigts[event.pointer] = event.position;
    final double? initial = _ecartInitial;
    if (_doigts.length < 2 || initial == null || initial <= 0) {
      return; // Un seul doigt fait defiler, il ne zoome pas.
    }
    setState(() {
      _zoom = (_zoomAuDebutDuGeste * _ecartCourant() / initial)
          .clamp(ScoreView.minZoom, ScoreView.maxZoom);
    });
  }

  void _doigtLeve(PointerEvent event) {
    _doigts.remove(event.pointer);
    // Le pincement recommencera a zero si un deuxieme doigt revient : sans
    // ca, l'ecart de reference serait celui d'un geste deja termine.
    _ecartInitial = null;
  }

  void _ouvrirLePincement() {
    if (_doigts.length != 2) {
      return;
    }
    _ecartInitial = _ecartCourant();
    _zoomAuDebutDuGeste = _zoom;
  }

  double _ecartCourant() {
    final List<Offset> deux = _doigts.values.take(2).toList();
    return (deux[0] - deux[1]).distance;
  }

  @override
  Widget build(BuildContext context) {
    final Passage passage = widget.passage;
    final Orientation orientation = MediaQuery.orientationOf(context);
    final bool paysage = orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(passage.title),
        actions: <Widget>[
          IconButton(
            onPressed: widget.onTune,
            icon: const Icon(Icons.tune),
            tooltip: 'Accorder',
          ),
          IconButton(
            onPressed: _changerDeMode,
            icon: Icon(
              _mode == ScoreDisplayMode.systems
                  ? Icons.view_headline
                  : Icons.swap_horiz,
            ),
            tooltip: _mode == ScoreDisplayMode.systems
                ? 'Passer au defilement'
                : 'Passer a plusieurs lignes',
          ),
          IconButton(
            onPressed: widget.onChangePassage,
            icon: const Icon(Icons.edit_note),
            tooltip: 'Changer de passage',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          // Cle explicite : le test de mise en page mesure ce contenu, pas
          // le SafeArea lui-meme, qui occupe toute la hauteur et dont seul
          // l'enfant est decale.
          key: const Key('session-content'),
          padding: EdgeInsets.all(paysage ? 12 : 24),
          child: paysage ? _enPaysage(orientation) : _enPortrait(orientation),
        ),
      ),
    );
  }

  /// En portrait, la hauteur est abondante : tout s'empile.
  Widget _enPortrait(Orientation orientation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _entete(),
        const SizedBox(height: 24),
        const SizedBox(height: 20),
        _metronome(),
        Expanded(child: _partition(orientation)),
        const SizedBox(height: 8),
        _BandeauMicro(etat: _mic),
        const SizedBox(height: 16),
        _bouton(),
      ],
    );
  }

  /// En paysage, la hauteur est la ressource rare : la partition la prend
  /// toute, et les commandes passent sur le cote, ou la place ne manque pas.
  ///
  /// Empiler comme en portrait ne laisserait pas de quoi afficher deux
  /// systemes, ce qui est justement l'interet de tourner l'ecran.
  Widget _enPaysage(Orientation orientation) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: _partition(orientation)),
        const SizedBox(width: 16),
        SizedBox(
          width: _largeurDesCommandes,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _entete(vertical: true),
              const SizedBox(height: 16),
              _metronome(),
              const SizedBox(height: 16),
              _BandeauMicro(etat: _mic),
              const SizedBox(height: 16),
              _bouton(),
            ],
          ),
        ),
      ],
    );
  }

  static const double _largeurDesCommandes = 200;

  Widget _entete({bool vertical = false}) {
    final ThemeData theme = Theme.of(context);
    final Passage passage = widget.passage;
    final Text mesures = Text(
      passage.measureCount == 1
          ? 'Mesure ${passage.firstMeasure}'
          : 'Mesures ${passage.firstMeasure} a ${passage.lastMeasure}',
      style: theme.textTheme.titleMedium,
      overflow: TextOverflow.ellipsis,
    );
    final Text tempo = Text(
      '${passage.writtenTempoBpm} bpm',
      style: theme.textTheme.titleMedium,
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[mesures, const SizedBox(height: 4), tempo],
      );
    }
    // Le numero de mesure cede la place au tempo plutot que de deborder :
    // "Mesures 100 a 104" est plus long que "Mesures 12 a 13", et le tempo
    // doit rester lisible dans tous les cas.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[Flexible(child: mesures), tempo],
    );
  }

  Widget _metronome() => MetronomeBar(
        tempoBpm: widget.passage.writtenTempoBpm,
        running: _running,
      );

  Widget _bouton() => FilledButton.tonalIcon(
        onPressed: _running ? _stop : _start,
        icon: Icon(_running ? Icons.stop : Icons.play_arrow),
        label: Text(_running ? 'Arreter' : 'Jouer le passage'),
      );

  Widget _partition(Orientation orientation) {
    // Des evenements bruts, et non un `GestureDetector`. Un detecteur de
    // pincement entre dans l'arene des gestes et y rafle le glissement a un
    // doigt : le mode defilement ne defilerait plus. Un `Listener` observe
    // sans rien reclamer.
    return Listener(
      onPointerDown: _doigtPose,
      onPointerMove: _doigtBouge,
      onPointerUp: _doigtLeve,
      onPointerCancel: _doigtLeve,
      child: ScoreView(
        passage: widget.passage,
        cursorTick: _running ? _cursor.tickAt(_elapsed) : null,
        colorOf: _couleurDe,
        mode: _mode,
        zoom: _zoom,
        maxSystems: maxSystemsFor(orientation),
      ),
    );
  }
}

/// Une ligne discrete sous la portee : la legende des couleurs quand on
/// ecoute, la raison quand on n'ecoute pas.
///
/// Sa hauteur est libre, mais jamais nulle : reserver la place evite que la
/// partition sursaute quand le micro change d'etat.
class _BandeauMicro extends StatelessWidget {
  const _BandeauMicro({required this.etat});

  final _MicState etat;

  static const double _hauteurMinimale = 20;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _hauteurMinimale),
      child: switch (etat) {
        _MicState.arrete => const SizedBox.shrink(),
        _MicState.ecoute => const _Legende(),
        _MicState.refuse => Text(
            'Micro refuse : le passage defile sans notation.',
            style: style,
            textAlign: TextAlign.center,
          ),
        _MicState.indisponible => Text(
            'Micro indisponible : le passage defile sans notation.',
            style: style,
            textAlign: TextAlign.center,
          ),
      },
    );
  }
}

/// Trois couleurs, trois mots. Une seule fois, en petit.
///
/// En `Wrap` et non en `Row` : la colonne de commandes du mode paysage ne fait
/// que deux cents pixels, et une ligne rigide y deborderait.
class _Legende extends StatelessWidget {
  const _Legende();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: <Widget>[
        for (final TuningVerdict v in <TuningVerdict>[
          TuningVerdict.low,
          TuningVerdict.inTune,
          TuningVerdict.high,
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: TuningColors.of(v),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(TuningColors.label(v), style: style),
            ],
          ),
      ],
    );
  }
}
