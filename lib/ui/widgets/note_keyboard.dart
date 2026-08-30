import 'package:flutter/material.dart';

import '../../core/music/pitch_utils.dart';

/// Clavier de saisie des hauteurs.
///
/// Ne montre que les notes naturelles de la premiere position au violon, du
/// sol3 (corde a vide grave) au si5. C'est la position que l'eleve connait,
/// et 17 boutons tiennent en portrait sans devenir minuscules.
///
/// Les alterations passent par un modificateur diese plutot que par 12 notes
/// par octave : deux fois moins de boutons, et l'eleve raisonne comme sur sa
/// partition, une note plus une alteration.
///
/// Pas de bemol : [ScoreNote] ne stocke qu'un numero MIDI, sans orthographe
/// enharmonique. Un si bemol et un la diese y sont la meme note, et
/// [PitchUtils.noteName] ne sait afficher que des dieses. Proposer les deux
/// afficherait "La#4" apres avoir tape "Si bemol".
class NoteKeyboard extends StatelessWidget {
  const NoteKeyboard({
    required this.onNoteSelected,
    this.sharp = false,
    super.key,
  });

  /// Rend le numero MIDI, alteration deja appliquee.
  final ValueChanged<int> onNoteSelected;

  final bool sharp;

  /// Notes naturelles de sol3 a si5.
  static const List<int> naturals = <int>[
    55, 57, 59, // sol3 la3 si3
    60, 62, 64, 65, 67, 69, 71, // do4 a si4
    72, 74, 76, 77, 79, 81, 83, // do5 a si5
  ];

  /// Un mi diese est un fa, un si diese est un do : ces deux boutons n'ont
  /// rien a proposer une fois le diese actif.
  static bool canSharpen(int midi) {
    final int pitchClass = midi % 12;
    return pitchClass != 4 && pitchClass != 11;
  }

  /// Espacement entre deux touches.
  static const double _spacing = 8;

  /// Largeur minimale d'une touche. En dessous de 56 dp la cible devient trop
  /// petite pour un appareil pose sur un pupitre et lu a 70 cm.
  static const double _minKeyWidth = 56;

  /// Sept colonnes suffisent : c'est deja une octave par ligne.
  static const int _maxColumns = 7;

  @override
  Widget build(BuildContext context) {
    // Largeur calculee plutot que figee : a 360 dp on tient cinq touches par
    // ligne, donc quatre lignes au lieu de six. Une largeur en dur donnait
    // trois touches par ligne, et le clavier occupait les deux tiers de
    // l'ecran sans plus laisser voir les notes deja saisies.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns =
            ((constraints.maxWidth + _spacing) / (_minKeyWidth + _spacing))
                .floor()
                .clamp(3, _maxColumns);
        final double keyWidth =
            (constraints.maxWidth - _spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final int midi in naturals)
              _NoteButton(
                midi: midi,
                sharp: sharp,
                width: keyWidth,
                onSelected: onNoteSelected,
              ),
          ],
        );
      },
    );
  }
}

class _NoteButton extends StatelessWidget {
  const _NoteButton({
    required this.midi,
    required this.sharp,
    required this.width,
    required this.onSelected,
  });

  final int midi;
  final bool sharp;
  final double width;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool altered = sharp && NoteKeyboard.canSharpen(midi);
    final bool enabled = !sharp || NoteKeyboard.canSharpen(midi);
    final int produced = altered ? midi + 1 : midi;

    return SizedBox(
      width: width,
      child: OutlinedButton(
        onPressed: enabled ? () => onSelected(produced) : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 48),
        ),
        child: Text(
          PitchUtils.noteName(produced),
          maxLines: 1,
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}
