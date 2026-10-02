import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/music/pitch_utils.dart';
import '../../core/scoring/finger_diagnosis.dart';
import '../../core/store/document_saver.dart';
import '../../core/store/take_history.dart';
import '../../core/store/week_report.dart';

/// Ma semaine, a montrer au professeur (lots T2, T3).
///
/// **Sur le telephone de l'enfant, et c'est lui qui le montre.** Rien ne part
/// tout seul : l'ecran s'ouvre en debut de cours, et l'export est un geste --
/// copier, ou ranger un fichier ou il veut (`docs/professeur.md`).
class WeekReportScreen extends StatelessWidget {
  const WeekReportScreen({
    required this.history,
    this.saver,
    this.clock = DateTime.now,
    super.key,
  });

  final TakeHistory history;

  /// Pour ranger le rapport dans un fichier. `null` : seulement le copier.
  final DocumentSaver? saver;
  final DateTime Function() clock;

  static const Key copierKey = Key('copier-le-rapport');
  static const Key enregistrerKey = Key('enregistrer-le-rapport');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WeekReport r = WeekReport.of(history, clock());
    final DocumentSaver? s = saver;
    return Scaffold(
      appBar: AppBar(title: const Text('Ma semaine')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (r.days.isEmpty)
              Text(
                'Pas encore de prise suivie cette semaine.',
                style: theme.textTheme.bodyLarge,
              )
            else ...<Widget>[
              Text(
                '${r.days.length} jour${r.days.length > 1 ? 's' : ''} de travail, '
                '${r.playing.inMinutes} min d archet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text('Ce qui a monte', style: theme.textTheme.titleSmall),
              for (final WorkWeek w in r.works)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(w.rose ? Icons.trending_up : Icons.music_note),
                  title: Text(w.title),
                  subtitle: Text(<String>[
                    '${w.takes} prise${w.takes > 1 ? 's' : ''}',
                    if (w.bestPulseBpm != null)
                      w.rose && w.previousBestPulseBpm != null
                          ? 'tempo ${w.previousBestPulseBpm} -> ${w.bestPulseBpm}'
                          : 'tempo ${w.bestPulseBpm}',
                    if (w.bestTuning != null) 'justesse ${w.bestTuning}',
                    if (w.bestRhythm != null) 'rythme ${w.bestRhythm}',
                  ].join(' - ')),
                ),
              if (r.resisting.isNotEmpty ||
                  r.finger != null ||
                  r.noteFact != null) ...<Widget>[
                const SizedBox(height: 16),
                Text('Ce qui resiste encore',
                    style: theme.textTheme.titleSmall),
                for (final ResistingMeasure m in r.resisting)
                  _Ligne(
                    '${m.title}, mesure ${m.measure} : ${<String>[
                      if (m.restarts > 0) 'reprise ${m.restarts} fois',
                      if (m.stops > 0)
                        '${m.stops} arret${m.stops > 1 ? 's' : ''}',
                    ].join(', ')}',
                  ),
                if (r.finger case final FingerFinding f)
                  _Ligne(
                    '${f.place.label} : ${f.flat ? 'bas' : 'haut'} de '
                    '${f.medianCents.abs().round()} cents, sur '
                    '${f.strings.length} corde${f.strings.length > 1 ? 's' : ''}',
                  ),
                if (r.noteFact case final NoteFact n)
                  _Ligne(
                    '${PitchUtils.noteName(n.midi)} : '
                    '${n.medianCents < 0 ? 'bas' : 'haut'} de '
                    '${n.medianCents.abs().round()} cents, ${n.off} prises '
                    'sur ${n.total}',
                  ),
              ],
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: copierKey,
              onPressed: () => unawaited(_copier(context, r)),
              icon: const Icon(Icons.copy),
              label: const Text('Copier pour l envoyer'),
            ),
            if (s != null) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: enregistrerKey,
                onPressed: () => unawaited(_enregistrer(context, r, s)),
                icon: const Icon(Icons.save_alt),
                label: const Text('Enregistrer un fichier'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copier(BuildContext context, WeekReport r) async {
    await Clipboard.setData(ClipboardData(text: r.toText()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport copie.')),
      );
    }
  }

  Future<void> _enregistrer(
    BuildContext context,
    WeekReport r,
    DocumentSaver s,
  ) async {
    final DateTime d = r.to;
    final String nom = 'violon-semaine-${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}.txt';
    bool ok;
    try {
      ok = await s.save(nom, Uint8List.fromList(utf8.encode(r.toText())));
    } on Exception {
      ok = false;
    }
    if (context.mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport enregistre.')),
      );
    }
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(texte, style: Theme.of(context).textTheme.bodyMedium),
      );
}
