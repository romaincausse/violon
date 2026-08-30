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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final int midi in naturals)
          _NoteButton(
            midi: midi,
            sharp: sharp,
            onSelected: onNoteSelected,
          ),
      ],
    );
  }
}

class _NoteButton extends StatelessWidget {
  const _NoteButton({
    required this.midi,
    required this.sharp,
    required this.onSelected,
  });

  final int midi;
  final bool sharp;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool altered = sharp && NoteKeyboard.canSharpen(midi);
    final bool enabled = !sharp || NoteKeyboard.canSharpen(midi);
    final int produced = altered ? midi + 1 : midi;

    return SizedBox(
      width: 78,
      child: OutlinedButton(
        onPressed: enabled ? () => onSelected(produced) : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          PitchUtils.noteName(produced),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
