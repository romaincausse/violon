import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/audio/pitch_smoother.dart';
import '../../core/audio/pitch_source.dart';
import '../../core/exercises/exercise.dart';
import '../../core/exercises/note_by_note.dart';
import '../../core/music/finger_pattern.dart';
import '../../core/music/pitch_utils.dart';
import '../widgets/fingerboard_view.dart';
import '../widgets/keep_screen_awake.dart';
import 'session_screen.dart' show PitchSourceFactory;

/// Un motif joue **note a note** : on n'avance que sur la bonne note.
///
/// **Et seulement pour un motif de doigts** (lot E5). Sur un morceau, bloquer
/// detruit la ligne musicale et punit ce qu'un enfant qui travaille fait
/// naturellement -- s'arreter, reprendre, sauter. Sur huit notes de Sevcik il
/// n'y a aucune ligne a casser : un doigt a la fois, et la justesse note a
/// note *est* le sujet.
///
/// **Ni score, ni couleur.** Ce n'est pas une prise notee : c'est un
/// exercice de main gauche. Ce qui a ete manque revient a la fin comme
/// prochaine tache, et rien d'autre n'est dit.
class NoteByNoteScreen extends StatefulWidget {
  const NoteByNoteScreen({
    required this.exercise,
    required this.pitchSourceFactory,
    this.a4 = PitchUtils.defaultA4,
    super.key,
  });

  final MotifExercise exercise;
  final PitchSourceFactory pitchSourceFactory;
  final double a4;

  static const Key noteKey = Key('note-a-note-attendue');
  static const Key avanceKey = Key('note-a-note-avance');
  static const Key bilanKey = Key('note-a-note-bilan');
  static const Key recommencerKey = Key('note-a-note-recommencer');

  @override
  State<NoteByNoteScreen> createState() => _NoteByNoteScreenState();
}

class _NoteByNoteScreenState extends State<NoteByNoteScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late NoteByNote _motif = NoteByNote(placements: widget.exercise.placements);

  PitchSource? _source;
  StreamSubscription<SmoothedPitch>? _abonnement;

  /// Le temps depuis l'ouverture. Une seule horloge, injectee dans le coeur.
  Duration _depuis = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
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
    } catch (_) {
      // Sans micro, l'ecran garde son horloge : l'aide s'affiche et on
      // avance quand meme. Mieux vaut un exercice qui defile qu'un mur.
    }
  }

  void _onTick(Duration elapsed) {
    _depuis = elapsed;
    final int avant = _motif.index;
    final bool aideAvant = _motif.showHelp;
    _motif.wait(elapsed);
    if (_motif.index != avant || _motif.showHelp != aideAvant) {
      setState(() {});
    }
  }

  void _onPitch(SmoothedPitch pitch) {
    if (!mounted || _motif.isFinished) {
      return;
    }
    final int avant = _motif.index;
    _motif.hear(
      PitchUtils.frequencyToMidi(pitch.frequencyHz, a4: widget.a4),
      _depuis,
    );
    if (_motif.index != avant) {
      setState(() {});
    }
  }

  void _recommencer() {
    setState(() {
      _motif = NoteByNote(placements: widget.exercise.placements);
      _depuis = Duration.zero;
    });
    _ticker
      ..stop()
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return KeepScreenAwake(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.exercise.titre)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: _motif.isFinished
                ? _leBilan(theme)
                : _laRecherche(
                    theme,
                    MediaQuery.orientationOf(context) == Orientation.landscape,
                  ),
          ),
        ),
      ),
    );
  }

  /// **En paysage, deux colonnes.** Le schema de manche est haut par nature --
  /// c'est un manche -- et l'empiler sous une note en gros deborde d'un
  /// telephone couche. Cote a cote, chacun a la place qu'il demande.
  Widget _laRecherche(ThemeData theme, bool paysage) {
    final FingerPlacement attendue = _motif.expected!;
    final Widget avance = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${_motif.index + 1} sur ${_motif.total}',
          key: NoteByNoteScreen.avanceKey,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Une barre qui se remplit : des donnees qui montent, et rien qui
        // redescende sur une note manquee.
        LinearProgressIndicator(
          value: _motif.index / _motif.total,
          minHeight: 6,
        ),
      ],
    );
    final Widget laNote = Text(
      PitchUtils.noteName(attendue.midi),
      key: NoteByNoteScreen.noteKey,
      style: paysage
          ? theme.textTheme.displayMedium
          : theme.textTheme.displayLarge,
      textAlign: TextAlign.center,
    );
    // **L'aide ne s'affiche pas tout de suite.** Chercher sa note fait partie
    // de l'exercice ; la donner d'emblee le viderait de son sens.
    final Widget leManche = AnimatedOpacity(
      opacity: _motif.showHelp ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: FingerboardView(
        pattern: widget.exercise.pattern,
        target: _motif.showHelp ? attendue : null,
        // **Aussi haut que la place le permet.** Le demi-ton de l'ecartement
        // est l'ecart le plus serre du schema, et c'est justement celui qu'il
        // faut voir : plus le manche est haut, plus il s'ouvre.
        height: paysage ? 195 : 260,
      ),
    );
    final Widget laPhrase = Text(
      _motif.showHelp
          ? '${_nomDeLaCorde(attendue)}, ${_nomDuDoigt(attendue)}'
          : 'Cherche la note.',
      style: theme.textTheme.titleMedium,
      textAlign: TextAlign.center,
    );

    if (paysage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          avance,
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      laNote,
                      const SizedBox(height: 12),
                      laPhrase,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Center(child: leManche)),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        avance,
        const Spacer(),
        laNote,
        const Spacer(),
        leManche,
        const SizedBox(height: 8),
        laPhrase,
        const Spacer(),
      ],
    );
  }

  Widget _leBilan(ThemeData theme) {
    final int trouvees = _motif.found;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '$trouvees notes sur ${_motif.total}',
          key: NoteByNoteScreen.bilanKey,
          style: theme.textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // **Une seule chose a retravailler, pas un palmares des echecs.**
        Text(
          _laProchaineTache(),
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: NoteByNoteScreen.recommencerKey,
          onPressed: _recommencer,
          icon: const Icon(Icons.replay),
          label: const Text('Recommencer'),
        ),
      ],
    );
  }

  /// Ce qu'il y a a retravailler, en une phrase.
  String _laProchaineTache() {
    final List<int> manquees = _motif.toRework;
    if (manquees.isEmpty) {
      return 'Tout y etait.';
    }
    final FingerPlacement pose = _motif.placements[manquees.first];
    return 'A retravailler : ${_nomDuDoigt(pose)} '
        'sur ${_nomDeLaCorde(pose)}.';
  }

  String _nomDeLaCorde(FingerPlacement pose) => 'la corde de '
      '${PitchUtils.noteName(pose.stringMidi).replaceAll(RegExp(r'\d'), '')}';

  String _nomDuDoigt(FingerPlacement pose) => switch (pose.finger) {
        0 => 'a vide',
        1 => 'premier doigt',
        2 => 'deuxieme doigt',
        3 => 'troisieme doigt',
        _ => 'quatrieme doigt',
      };
}
