import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/audio/microphone_pitch_source.dart';
import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/follow/score_cursor.dart';
import '../../core/music/passage.dart';
import '../../core/play/count_in.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/music/score_note.dart';
import '../../core/scoring/live_tuning.dart';
import '../../core/scoring/measure_scores.dart';
import '../../core/scoring/tuning_trace.dart';
import '../../core/scoring/string_drift_monitor.dart';
import '../../core/scoring/tuner.dart';
import '../../platform/audio/default_pitch_source.dart';
import '../widgets/measure_halo.dart';
import '../widgets/measure_strip.dart';
import '../widgets/metronome_bar.dart';
import '../widgets/tuning_ribbon.dart';
import '../widgets/score_view.dart';
import '../widgets/tuning_colors.dart';
import '../widgets/keep_screen_awake.dart';

/// Ce que l'ecran montre pendant qu'il joue.
///
/// **Le bon affichage depend de ce qu'il sait deja du passage**, et pas d'une
/// preference esthetique. Depuis l'ADR-009 il lit sa partition papier ; la
/// partition a l'ecran n'est donc utile que lorsqu'elle n'a plus rien a lui
/// apprendre.
enum DisplayProfile {
  /// Il dechiffre. L'ecran ne montre que le retour : ruban et mesures.
  ///
  /// La partition a l'ecran serait une seconde partition a suivre, en plus
  /// petit et moins bien gravee que celle de son pupitre. Elle encombre.
  decouverte,

  /// Il connait le passage. La partition prend tout son sens ici.
  ///
  /// Curseur et coloration note par note : c'est le seul moment ou regarder
  /// l'ecran ne lui coute pas sa lecture.
  parCoeur,

  /// Trois informations, en grand, lisibles a soixante-dix centimetres.
  ///
  /// Ni partition, ni metronome, ni legende : ou il en est, comment ca va, et
  /// le bouton. Pour jouer sans rien avoir a chercher.
  pupitre,
}

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

/// Ce qu'un passage note a produit, une fois joue jusqu'au bout.
///
/// Rendu a l'appelant plutot qu'affiche : c'est lui qui sait si le passage
/// etait un exercice du catalogue, et qui tient la progression.
class SessionResult {
  const SessionResult({
    required this.score,
    required this.coverage,
    required this.tempoBpm,
  });

  /// Note d'ensemble du passage, de 0 a 100.
  final int score;

  /// Part des notes du passage reellement entendues, entre 0 et 1.
  ///
  /// Le score ne compte que ce qui a ete entendu : sans cette part, quatre
  /// notes justes sur vingt-neuf vaudraient cent.
  final double coverage;

  /// Tempo auquel le passage etait ecrit.
  final int tempoBpm;
}

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
    this.onResult,
    this.onFullScreen,
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

  /// Appele quand le passage a ete joue **jusqu'au bout**, avec un score.
  ///
  /// **Seulement au bout, jamais sur un arret manuel.** Un passage interrompu
  /// apres trois notes justes rendrait un score de cent sur trois notes : de
  /// quoi declarer un exercice acquis en l'abandonnant, ce qui est exactement
  /// l'inverse du travail.
  final ValueChanged<SessionResult>? onResult;

  /// Previent la coquille qu'on entre ou qu'on sort du plein ecran.
  ///
  /// La barre de navigation ne nous appartient pas : elle est a `HomeShell`,
  /// qui seule peut la retirer. Sans ce signal, le plein ecran garderait
  /// quatre-vingts points de decor en bas de la dalle.
  final ValueChanged<bool>? onFullScreen;

  /// Bouton de changement de profil d'affichage, pour les tests.
  static const Key profilKey = Key('profil-affichage');

  /// Entree du plein ecran, pour les tests.
  static const Key pleinEcranKey = Key('plein-ecran');

  /// Sortie du plein ecran, pour les tests.
  static const Key sortiePleinEcranKey = Key('sortie-plein-ecran');

  /// Reglage de subdivision du metronome, pour les tests.
  static const Key subdivisionKey = Key('subdivision-metronome');

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  bool _running = false;

  /// Temps depuis l'appui sur le bouton, decompte compris.
  Duration _depuisLeDepart = Duration.zero;

  /// Le decompte avant la prise.
  ///
  /// **Bete, et bloquant sans lui** : on ne peut pas commencer un passage
  /// note sans savoir quand partir, et sans decompte la premiere note est
  /// toujours en retard -- une note ratee par la faute de l'application.
  CountIn get _decompte => CountIn(tempoBpm: widget.passage.writtenTempoBpm);

  bool get _enDecompte => _running && !_decompte.isFinishedAt(_depuisLeDepart);

  /// Temps ecoule **dans le passage**. Zero tant que le decompte tourne.
  ///
  /// Soustrait du temps absolu plutot que remis a zero : rien n'est cumule,
  /// donc rien ne derive, exactement comme dans `MetronomeClock`.
  Duration get _elapsed =>
      _enDecompte ? Duration.zero : _depuisLeDepart - _decompte.duration;

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
  StreamSubscription<SmoothedPitch>? _abonnement;
  _MicState _mic = _MicState.arrete;

  /// Surveille l'accord de l'instrument pendant qu'on joue.
  ///
  /// Chaque corde a vide du passage mesure gratuitement l'accord reel. Sans
  /// ca, un violon qui descend de quinze cents en cours de seance fait
  /// reprocher a l'enfant, pendant une demi-heure, une faute qui appartient
  /// a l'instrument.
  late StringDriftMonitor _accord =
      StringDriftMonitor(tuner: Tuner(a4: widget.a4));

  /// Derive a annoncer, tant qu'elle n'a pas ete lue.
  StringDrift? _derive;

  DisplayProfile _profil = DisplayProfile.parCoeur;

  /// Pulsations par temps du metronome visuel.
  int _subdivision = 1;

  /// Derniere mesure vue par le curseur, pour reperer qu'on en a change.
  int? _mesureVue;

  /// Change a chaque mesure reussie : c'est ce qui declenche le halo.
  int _mesuresReussies = 0;

  /// Les dernieres secondes de justesse, telles quelles.
  ///
  /// Le score dit qu'une note vaut quatre-vingt-dix ; le trace dit si elle a
  /// ete posee juste ou attaquee basse puis rattrapee. C'est ce second geste
  /// qu'un professeur corrige.
  final TuningTrace _trace = TuningTrace();

  ScoreCursor get _cursor => ScoreCursor(
        passage: widget.passage,
        tempoBpm: widget.passage.writtenTempoBpm,
      );

  void _onTick(Duration elapsed) {
    // Pendant le decompte, le curseur n'a pas commence : le comparer a la fin
    // du passage l'arreterait avant meme d'avoir demarre.
    if (!_decompte.isFinishedAt(elapsed)) {
      setState(() => _depuisLeDepart = elapsed);
      return;
    }
    // La lecture s'arrete d'elle-meme sur la derniere note : on termine sur
    // la fin du passage, pas sur un bouton qu'il faudrait penser a presser.
    if (_cursor.isFinishedAt(elapsed - _decompte.duration)) {
      _stop(termine: true);
      return;
    }
    setState(() => _depuisLeDepart = elapsed);
    if (!_enDecompte) {
      _surveillerLaFinDeMesure();
    }
  }

  /// Allume le halo quand une mesure vient d'etre passee proprement.
  ///
  /// **Au changement de mesure, pas a chaque note.** A la note, la lueur
  /// clignoterait en permanence et deviendrait du bruit ; a la mesure, elle
  /// marque une etape que l'enfant reconnait sur son papier.
  void _surveillerLaFinDeMesure() {
    final int? courante = _cursor.noteAt(_elapsed)?.measure;
    if (courante == null || courante == _mesureVue) {
      return;
    }
    final int? precedente = _mesureVue;
    _mesureVue = courante;
    if (precedente == null) {
      return;
    }
    final MeasureScore? finie = scoreByMeasure(widget.passage, _tuning)
        .where((MeasureScore m) => m.measure == precedente)
        .firstOrNull;
    // Entendue, et propre. Une mesure a peine entendue ne se felicite pas :
    // on ne sait pas ce qui s'y est passe.
    if (finie != null &&
        finie.heard &&
        finie.score! >= _scoreDuHalo &&
        finie.coverage >= 0.5) {
      setState(() => _mesuresReussies++);
    }
  }

  /// A partir de quoi une mesure est dite propre.
  ///
  /// Cent serait severe -- il faudrait chaque note dans la bande parfaite --
  /// et n'arriverait presque jamais. Quatre-vingt-dix laisse passer une note
  /// un peu flottante sans rien enlever au fait que la mesure est tenue.
  static const int _scoreDuHalo = 90;

  void _start() {
    setState(() {
      _depuisLeDepart = Duration.zero;
      _running = true;
      _tuning.reset();
      _trace.reset();
      _derive = null;
      _mesureVue = null;
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
      _abonnement = source.smoothedPitches.listen(_onPitch);
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
  /// tant que la latence n'est pas calibree (lot J2), prendre l'horodatage du
  /// micro donnerait une fausse precision. A 46 ms par trame, l'ecart ne se
  /// voit pas sur une coloration.
  void _onPitch(SmoothedPitch pitch) {
    if (!_running) {
      return;
    }
    // L'accord se surveille meme entre deux notes attendues : une corde a
    // vide tiree pour verifier compte autant qu'une du passage.
    final StringDrift? derive = _accord.observe(pitch);
    final ScoreNote? note = _cursor.noteAt(_elapsed);
    setState(() {
      if (derive != null) {
        _derive = derive;
      }
      if (note != null) {
        _tuning.observe(
          note,
          pitch.estimate,
          sinceNoteStartMs: _depuisLeDebutDeLaNote(note),
        );
        // Le trace suit l'ecart a la note ATTENDUE, comme le reste : compare
        // a la note la plus proche, il dirait "juste" sur une fausse note.
        _trace.add(
          pitch.timestampMs,
          PitchUtils.centsBetween(
            pitch.frequencyHz,
            PitchUtils.midiToFrequency(note.midi, a4: widget.a4),
          ),
        );
      }
    });
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

  void _stop({bool termine = false}) {
    _ticker.stop();
    unawaited(_fermerLeMicro());
    final int? score = termine ? _tuning.overallScore : null;
    setState(() {
      _running = false;
      _depuisLeDepart = Duration.zero;
    });
    if (score != null) {
      widget.onResult?.call(
        SessionResult(
          score: score,
          coverage: _tuning.heardNoteIds.length / widget.passage.notes.length,
          tempoBpm: widget.passage.writtenTempoBpm,
        ),
      );
    }
  }

  Future<void> _fermerLeMicro() async {
    final PitchSource? source = _source;
    final StreamSubscription<SmoothedPitch>? abonnement = _abonnement;
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
      setState(() {
        _tuning = LiveTuning(a4: widget.a4);
        // On vient d'accorder : ce qui precede ne decrit plus l'instrument,
        // et le trace a ete mesure contre l'ancienne reference.
        _accord = StringDriftMonitor(tuner: Tuner(a4: widget.a4));
        _trace.reset();
        _derive = null;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_fermerLeMicro());
    if (_pleinEcran) {
      // Les barres du systeme appartiennent a l'application entiere, pas a
      // cet ecran : les laisser cachees derriere soi rendrait tout le reste
      // inutilisable.
      _chromeSysteme(false);
    }
    super.dispose();
  }

  Color? _couleurDe(ScoreNote note) =>
      TuningColors.of(_tuning.verdictFor(note.id));

  /// Les profils defilent en boucle plutot que de s'ouvrir dans un menu.
  ///
  /// Un menu couterait deux appuis, et on change de profil **violon en
  /// main** : l'icone dit ou l'on est, l'infobulle le nomme.
  void _changerDeProfil() {
    setState(() {
      _profil = DisplayProfile
          .values[(_profil.index + 1) % DisplayProfile.values.length];
    });
  }

  /// Le plein ecran : plus rien a l'ecran que la musique.
  ///
  /// **Une bonne moitie de la hauteur partait en decor** -- barre de titre,
  /// barre de navigation, barre d'etat, barre systeme. Sur un telephone pose
  /// sur un pupitre a soixante-dix centimetres, cette hauteur-la vaut des
  /// notes plus grandes, et rien d'autre.
  bool _pleinEcran = false;

  /// Entre ou sort du plein ecran.
  ///
  /// **Trois choses disparaissent a la fois** : notre barre de titre, la
  /// barre de navigation de la coquille, et les barres du systeme. Les trois
  /// doivent revenir ensemble, sans quoi on sortirait sur un ecran mutile.
  void _basculerLePleinEcran() {
    final bool voulu = !_pleinEcran;
    setState(() => _pleinEcran = voulu);
    widget.onFullScreen?.call(voulu);
    _chromeSysteme(voulu);
  }

  /// `immersiveSticky` et non `immersive` : un enfant qui effleure le bas de
  /// la dalle en tournant sa page ne doit pas recuperer la barre systeme pour
  /// le reste de la seance.
  static void _chromeSysteme(bool cache) {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        cache ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
  }

  IconData get _iconeDuProfil => switch (_profil) {
        DisplayProfile.decouverte => Icons.hearing,
        DisplayProfile.parCoeur => Icons.music_note,
        DisplayProfile.pupitre => Icons.fullscreen,
      };

  String get _nomDuProfil => switch (_profil) {
        DisplayProfile.decouverte => 'decouverte',
        DisplayProfile.parCoeur => 'par coeur',
        DisplayProfile.pupitre => 'pupitre',
      };

  /// Le temps affiche pendant le decompte, ou `null`.
  int? get _compteAffiche => _decompte.beatAt(_depuisLeDepart);

  /// Les cases de mesures, et celle qui est en cours de lecture.
  Widget _mesures({double hauteur = MeasureStrip.hauteur}) {
    final ScoreNote? courante = _running ? _cursor.noteAt(_elapsed) : null;
    return MeasureStrip(
      measures: scoreByMeasure(widget.passage, _tuning),
      currentMeasure: courante?.measure,
      height: hauteur,
    );
  }

  /// Ce qu'il y a a dire une fois le passage termine.
  ///
  /// Rien pendant la lecture : un chiffre qui bouge pendant qu'on joue
  /// detournerait le regard de la partition, et changerait a chaque note.
  _Bilan? _bilan() {
    if (_running) {
      return null;
    }
    final int? score = _tuning.overallScore;
    if (score == null) {
      return null;
    }
    final String? pire = _tuning.weakestNoteId;
    final ScoreNote? aTravailler = pire == null
        ? null
        : widget.passage.notes.where((ScoreNote n) => n.id == pire).firstOrNull;
    return _Bilan(score: score, aTravailler: aTravailler);
  }

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

    return KeepScreenAwake(
      // Pendant la prise seulement : c'est le seul moment ou l'archet occupe
      // les deux mains. Cet ecran est l'onglet d'accueil, il reste monte toute
      // la seance -- le garder allume tout du long reviendrait a l'allumer
      // pour toujours.
      actif: _running,
      child: PopScope(
        // Le retour sort du plein ecran avant de sortir de l'ecran. En
        // immersion la barre systeme est cachee, et le geste de retour est
        // alors le seul reflexe qui reste : le laisser quitter la seance
        // serait le punir de s'en servir.
        canPop: !_pleinEcran,
        onPopInvokedWithResult: (bool sorti, Object? _) {
          if (!sorti && _pleinEcran) {
            _basculerLePleinEcran();
          }
        },
        child: Scaffold(
          appBar: _pleinEcran
              ? null
              : AppBar(
                  title: Text(passage.title),
                  actions: <Widget>[
                    IconButton(
                      onPressed: widget.onTune,
                      icon: const Icon(Icons.tune),
                      tooltip: 'Accorder',
                    ),
                    IconButton(
                      key: SessionScreen.profilKey,
                      onPressed: _changerDeProfil,
                      icon: Icon(_iconeDuProfil),
                      tooltip: 'Affichage : $_nomDuProfil',
                    ),
                    // La mise en page de la partition n'a de sens que si la partition
                    // est a l'ecran.
                    if (_profil == DisplayProfile.parCoeur)
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
                      key: SessionScreen.pleinEcranKey,
                      onPressed: _basculerLePleinEcran,
                      icon: const Icon(Icons.open_in_full),
                      tooltip: 'Plein ecran',
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
              // **Plus etroit lateralement que verticalement.** La largeur est
              // la ressource utile : elle se paie en notes plus grandes sur la
              // portee et en secondes lisibles sur le ruban. Le blanc en haut et
              // en bas, lui, ne sert qu'a ne pas coller aux barres du systeme.
              //
              // Pas de plein bord pour autant : une portee qui touche le bord de
              // la dalle se lit comme coupee, et aucune gravure ne fait ca.
              padding: EdgeInsets.symmetric(
                horizontal: paysage ? 10 : 12,
                vertical: paysage ? 12 : 24,
              ),
              child: MeasureHalo(
                trigger: _mesuresReussies,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: _pleinEcran
                          ? _enPleinEcran(orientation)
                          : paysage
                              ? _enPaysage(orientation)
                              : _enPortrait(orientation),
                    ),
                    if (_enDecompte)
                      Positioned.fill(child: _Decompte(compte: _compteAffiche)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Plus rien que la musique.
  ///
  /// **Ce qui reste se compte sur une main** : la portee, le tempo, et le
  /// bouton. Le reste s'atteint en sortant, ce qui est un geste rare -- le
  /// telephone passe l'essentiel d'une seance dans cet etat-la.
  ///
  /// **La partition s'affiche quel que soit le profil.** Demander le plein
  /// ecran, c'est demander la partition ; l'ouvrir sur le profil decouverte
  /// donnerait un ecran vide, ce qui serait une reponse absurde a une demande
  /// claire.
  Widget _enPleinEcran(Orientation orientation) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '${widget.passage.writtenTempoBpm} bpm',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              key: SessionScreen.sortiePleinEcranKey,
              onPressed: _basculerLePleinEcran,
              icon: const Icon(Icons.close_fullscreen),
              tooltip: 'Quitter le plein ecran',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Expanded(child: _partition(orientation)),
        const SizedBox(height: 8),
        _bouton(),
      ],
    );
  }

  /// En portrait, la hauteur est abondante : tout s'empile.
  Widget _enPortrait(Orientation orientation) {
    // Le profil pupitre ne montre que trois choses, en grand : ou il en est,
    // comment ca va, et le bouton. Rien a chercher, rien a lire.
    if (_profil == DisplayProfile.pupitre) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Spacer(),
          TuningRibbon(trace: _trace, height: 96),
          const SizedBox(height: 20),
          _mesures(hauteur: 72),
          const Spacer(),
          _Bandeau(etat: _mic, bilan: _bilan(), derive: _derive),
          const SizedBox(height: 20),
          _bouton(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _entete(),
        const SizedBox(height: 24),
        const SizedBox(height: 20),
        _metronome(),
        // En decouverte, la partition a l'ecran serait une seconde partition
        // a suivre, en plus petit que celle du pupitre. Elle encombre.
        if (_profil == DisplayProfile.parCoeur)
          Expanded(child: _partition(orientation))
        else
          const Spacer(),
        const SizedBox(height: 8),
        TuningRibbon(trace: _trace),
        const SizedBox(height: 6),
        _mesures(),
        const SizedBox(height: 8),
        _Bandeau(etat: _mic, bilan: _bilan(), derive: _derive),
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
    if (_profil == DisplayProfile.pupitre) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Spacer(),
          TuningRibbon(trace: _trace, height: 64),
          const SizedBox(height: 12),
          _mesures(hauteur: 48),
          const Spacer(),
          _Bandeau(etat: _mic, bilan: _bilan(), derive: _derive),
          const SizedBox(height: 12),
          _bouton(),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_profil == DisplayProfile.parCoeur)
          Expanded(child: _partition(orientation))
        else
          const Spacer(),
        const SizedBox(width: 16),
        SizedBox(
          width: _largeurDesCommandes,
          // **La colonne defile, le bouton non.** En paysage sur un telephone,
          // la hauteur utile tombe a deux cent cinquante points une fois la
          // barre systeme et celle de l'application retirees : la colonne des
          // commandes n'y tenait pas, et debordait de quatre-vingt-douze
          // points. Le bouton reste hors du defilement -- c'est le seul
          // element qu'on doit pouvoir atteindre sans chercher, violon en
          // main.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _entete(vertical: true),
                      const SizedBox(height: 12),
                      _metronome(compact: true),
                      const SizedBox(height: 12),
                      // Plus bas qu'en portrait : en paysage la hauteur est la
                      // ressource rare, et un ruban de 24 points se lit
                      // encore.
                      TuningRibbon(trace: _trace, height: 24),
                      const SizedBox(height: 6),
                      _mesures(),
                      const SizedBox(height: 10),
                      _Bandeau(etat: _mic, bilan: _bilan(), derive: _derive),
                    ],
                  ),
                ),
              ),
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

  /// Le metronome, et de quoi choisir sa subdivision d'un appui.
  ///
  /// **Le reglage est sur la barre elle-meme**, pas dans un menu : on change
  /// de subdivision en plein travail, quand le passage se complique, et
  /// aller le chercher ailleurs couterait le fil.
  Widget _metronome({bool compact = false}) => Semantics(
        button: true,
        label: 'Subdivision du metronome : $_libelleSubdivision',
        child: InkWell(
          key: SessionScreen.subdivisionKey,
          onTap: _changerDeSubdivision,
          child: Padding(
            // En paysage la hauteur est la ressource rare : la zone d'appui
            // se resserre plutot que de pousser le reste hors de l'ecran.
            padding: EdgeInsets.symmetric(vertical: compact ? 0 : 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: MetronomeBar(
                    tempoBpm: widget.passage.writtenTempoBpm,
                    running: _running,
                    subdivision: _subdivision,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _libelleSubdivision,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      );

  /// Noire, croches, triolet, doubles -- puis on recommence.
  void _changerDeSubdivision() {
    setState(() {
      _subdivision = _subdivision % 4 + 1;
    });
  }

  String get _libelleSubdivision => switch (_subdivision) {
        2 => 'croches',
        3 => 'triolet',
        4 => 'doubles',
        _ => 'noire',
      };

  /// Le seul bouton plein de l'ecran.
  ///
  /// Tout le reste de l'interface est en encre sur papier ; lancer la prise
  /// est la seule chose qu'on vient y faire, et c'est la seule qui porte la
  /// couleur.
  Widget _bouton() => FilledButton.icon(
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
        // En plein ecran, la hauteur gagnee doit se voir sur les notes.
        maxSpaceSize: _pleinEcran
            ? ScoreView.pleinEcranMaxSpaceSize
            : ScoreView.defaultMaxSpaceSize,
      ),
    );
  }
}

/// "Un, deux, trois, quatre", en grand.
///
/// **On compte en montant, comme un chef.** C'est ce qu'il entend en cours et
/// en orchestre ; un compte a rebours serait plus clair pour une fusee.
///
/// Le decompte recouvre l'ecran : il n'y a rien d'autre a regarder a cet
/// instant precis, et le chiffre doit se voir de l'autre bout du pupitre.
class _Decompte extends StatelessWidget {
  const _Decompte({required this.compte});

  final int? compte;

  static const Key compteKey = Key('decompte');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return IgnorePointer(
      child: ColoredBox(
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        child: Center(
          child: Text(
            '${compte ?? ''}',
            key: compteKey,
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ce qu'on a mesure sur le dernier passage.
class _Bilan {
  const _Bilan({required this.score, required this.aTravailler});

  final int score;
  final ScoreNote? aTravailler;
}

/// Une ligne discrete sous la portee : le bilan quand le passage est fini, la
/// legende des couleurs pendant qu'on joue, la raison quand le micro manque.
///
/// Sa hauteur est libre, mais jamais nulle : reserver la place evite que la
/// partition sursaute quand l'etat change.
class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.etat, required this.bilan, this.derive});

  final _MicState etat;
  final _Bilan? bilan;

  /// Une corde a bouge depuis le debut de la seance.
  final StringDrift? derive;

  static const double _hauteurMinimale = 20;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.bodySmall;
    final _Bilan? b = bilan;
    final StringDrift? d = derive;
    // **Le bilan passe devant l'alerte, et l'alerte le suit.** L'alerte seule
    // masquerait le score a la fin du passage ; le score seul laisserait
    // croire que le chiffre parle de l'enfant alors qu'une corde est fausse.
    // Les deux, donc, dans cet ordre.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _hauteurMinimale),
      child: b != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Resultat(bilan: b),
                if (d != null) _AlerteAccord(derive: d),
              ],
            )
          : d != null
              ? _AlerteAccord(derive: d)
              : switch (etat) {
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

/// "Ton mi a baisse, reaccorde."
///
/// **Ce n'est pas un reproche, et la formulation compte.** Un violon se
/// desaccorde tout seul en jouant ; l'enfant n'y est pour rien, et la phrase
/// doit le dire. On nomme la corde et le sens, sans chiffre : quinze cents ne
/// veulent rien dire a onze ans, "ton mi a baisse" si.
class _AlerteAccord extends StatelessWidget {
  const _AlerteAccord({required this.derive});

  final StringDrift derive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.tune, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Ton ${derive.stringName.toLowerCase()} a '
            '${derive.flat ? 'baisse' : 'monte'} : reaccorde.',
            key: const Key('alerte-accord'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.primary),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Le bilan du passage : un chiffre, et une seule chose a retravailler.
///
/// **Pas un palmares des erreurs.** Le projet dit que l'application montre la
/// prochaine tache, jamais tout ce qui a rate. D'ou une seule mesure
/// designee, et aucun rouge : le chiffre se suffit.
class _Resultat extends StatelessWidget {
  const _Resultat({required this.bilan});

  final _Bilan bilan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ScoreNote? note = bilan.aTravailler;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Justesse ${bilan.score} sur 100',
          key: const Key('bilan-score'),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (note != null)
          Text(
            'A retravailler : mesure ${note.measure}',
            key: const Key('bilan-tache'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
      ],
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
