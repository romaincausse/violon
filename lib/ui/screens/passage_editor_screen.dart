import 'package:flutter/material.dart';

import '../../core/music/note_value.dart';
import '../../core/music/passage.dart';
import '../../core/music/passage_builder.dart';
import '../../core/music/pitch_utils.dart';
import '../../core/music/score_note.dart';
import '../widgets/note_keyboard.dart';

/// Saisie d'un passage a la main, note apres note.
///
/// Tant que la gravure de partition n'existe pas, c'est le seul moyen de
/// travailler autre chose que le passage de demonstration. Or c'est la tout
/// l'interet de l'application : elle doit servir sur les mesures que le
/// professeur a donnees cette semaine, pas sur un exemple.
///
/// Rend le [Passage] construit via `Navigator.pop`, ou `null` si on annule.
class PassageEditorScreen extends StatefulWidget {
  const PassageEditorScreen({super.key});

  @override
  State<PassageEditorScreen> createState() => _PassageEditorScreenState();
}

/// Une note telle que l'eleve l'a tapee.
///
/// L'ecran garde les gestes bruts plutot qu'un [PassageBuilder] deja rempli :
/// changer le chiffrage ou la premiere mesure doit renumeroter les mesures
/// deja saisies, ce qu'un simple rejeu des gestes fait gratuitement.
class _Entry {
  const _Entry({
    required this.midi,
    required this.value,
    required this.dotted,
  });

  final int midi;
  final NoteValue value;
  final bool dotted;
}

class _PassageEditorScreenState extends State<PassageEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final List<_Entry> _entries = <_Entry>[];

  NoteValue _value = NoteValue.quarter;
  bool _dotted = false;
  bool _sharp = false;
  int _firstMeasure = 1;
  int _beatsPerMeasure = 4;
  int _tempoBpm = 80;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  PassageBuilder get _builder {
    final PassageBuilder builder = PassageBuilder(
      beatsPerMeasure: _beatsPerMeasure,
      firstMeasure: _firstMeasure,
    );
    for (final _Entry entry in _entries) {
      builder.add(entry.midi, entry.value, dotted: entry.dotted);
    }
    return builder;
  }

  void _addNote(int midi) {
    setState(() {
      _entries.add(_Entry(midi: midi, value: _value, dotted: _dotted));
    });
  }

  void _undo() => setState(() => _entries.removeLast());

  void _validate() {
    Navigator.of(context).pop<Passage>(
      _builder.build(title: _title.text, writtenTempoBpm: _tempoBpm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PassageBuilder builder = _builder;
    final bool empty = _entries.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau passage'),
        actions: <Widget>[
          TextButton(
            onPressed: empty ? null : _validate,
            child: const Text('Travailler'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Titre',
                        hintText: builder.suggestedTitle,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Stepper(
                      name: 'Mesure',
                      label: 'Premiere mesure',
                      value: _firstMeasure,
                      min: 1,
                      max: 999,
                      onChanged: (int v) => setState(() => _firstMeasure = v),
                    ),
                    _Stepper(
                      name: 'Temps',
                      label: 'Temps par mesure',
                      value: _beatsPerMeasure,
                      min: 1,
                      max: 12,
                      onChanged: (int v) =>
                          setState(() => _beatsPerMeasure = v),
                    ),
                    _Stepper(
                      name: 'Tempo',
                      label: 'Tempo ecrit',
                      value: _tempoBpm,
                      min: 30,
                      max: 200,
                      step: 2,
                      onChanged: (int v) => setState(() => _tempoBpm = v),
                    ),
                    const Divider(height: 32),
                    if (empty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Tape les notes du passage, dans l\'ordre.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    else ...<Widget>[
                      Text(
                        '${builder.noteCount} notes  -  '
                        '${builder.suggestedTitle.toLowerCase()}',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (int i = 0; i < _entries.length; i++)
                            _NoteChip(
                              note: builder.notes[i],
                              entry: _entries[i],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SegmentedButton<NoteValue>(
                          segments: <ButtonSegment<NoteValue>>[
                            for (final NoteValue v in NoteValue.values)
                              ButtonSegment<NoteValue>(
                                value: v,
                                label: Text(v.shortLabel),
                                tooltip: v.label,
                              ),
                          ],
                          selected: <NoteValue>{_value},
                          showSelectedIcon: false,
                          onSelectionChanged: (Set<NoteValue> s) =>
                              setState(() => _value = s.first),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Toggle(
                        label: '.',
                        tooltip: 'Note pointee',
                        selected: _dotted,
                        onChanged: (bool v) => setState(() => _dotted = v),
                      ),
                      const SizedBox(width: 4),
                      _Toggle(
                        label: '♯',
                        tooltip: 'Diese',
                        selected: _sharp,
                        onChanged: (bool v) => setState(() => _sharp = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  NoteKeyboard(sharp: _sharp, onNoteSelected: _addNote),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: empty ? null : _undo,
                    icon: const Icon(Icons.undo),
                    label: const Text('Annuler la derniere'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reglage numerique, tape au pouce.
///
/// Une ligne pleine largeur par reglage plutot que trois cote a cote : sur un
/// telephone de 360 dp, trois steppers laissent 109 dp chacun pour un moins,
/// un nombre et un plus. Ca debordait, et les cibles tactiles tombaient sous
/// les 48 dp alors que l'appareil est lu a 70 cm, pose sur un pupitre.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.name,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  /// Identifiant stable, utilise pour les cles de test : le libelle affiche
  /// peut etre reformule sans casser les tests.
  final String name;

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
        IconButton(
          key: Key('$name-moins'),
          onPressed: value - step < min ? null : () => onChanged(value - step),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        IconButton(
          key: Key('$name-plus'),
          onPressed: value + step > max ? null : () => onChanged(value + step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 40,
        child: FilterChip(
          label: Text(label, style: const TextStyle(fontSize: 18)),
          labelPadding: EdgeInsets.zero,
          selected: selected,
          showCheckmark: false,
          onSelected: onChanged,
        ),
      ),
    );
  }
}

/// Une note deja saisie : sa hauteur, et l'initiale de sa figure.
class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.note, required this.entry});

  final ScoreNote note;
  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            PitchUtils.noteName(note.midi),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: 4),
          Text(
            '${entry.value.shortLabel}${entry.dotted ? '.' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
