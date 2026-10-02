import 'package:flutter/material.dart';

import '../../core/scoring/finger_diagnosis.dart';
import '../../core/store/document_saver.dart';
import '../../core/store/progress.dart';
import '../../core/store/take_history.dart';
import 'week_report_screen.dart';

/// Le progres, enfin visible (jalon 9).
///
/// **Des donnees qui montent, pas des recompenses.** Pas de badge, pas de
/// medaille : le tempo tenu au bout du passage, jour apres jour, et ce que la
/// soiree a permis d'atteindre. A onze ans, on sait qu'on fait de la musique ;
/// on veut voir le chiffre bouger.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    required this.history,
    this.clock = DateTime.now,
    this.saver,
    super.key,
  });

  final TakeHistory history;
  final DateTime Function() clock;

  /// Pour enregistrer le rapport de la semaine (T3).
  final DocumentSaver? saver;

  static const Key semaineKey = Key('ouvrir-ma-semaine');

  static const Key journalKey = Key('journal-du-jour');
  static const Key mainKey = Key('diagnostic-de-la-main');
  static Key courbeKey(String key) => Key('courbe-$key');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DayJournal jour = DayJournal.of(history, clock());
    final List<String> travaux = history.keys;
    return Scaffold(
      appBar: AppBar(title: const Text('Progres')),
      body: SafeArea(
        child: travaux.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Les courbes apparaissent apres une premiere prise jouee '
                  'jusqu au bout, quand l application te suit.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _Journal(jour: jour, history: history),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: semaineKey,
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext c) => WeekReportScreen(
                          history: history,
                          saver: saver,
                          clock: clock,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Ma semaine, pour le professeur'),
                  ),
                  if (FingerDiagnosis.of(history).main
                      case final FingerFinding f) ...<Widget>[
                    const SizedBox(height: 16),
                    _Main(trouve: f),
                  ],
                  const SizedBox(height: 16),
                  for (final String k in travaux)
                    _Courbe(serie: ProgressSeries.of(history, k)),
                ],
              ),
      ),
    );
  }
}

/// Aujourd'hui, en une carte (H5).
class _Journal extends StatelessWidget {
  const _Journal({required this.jour, required this.history});

  final DayJournal jour;
  final TakeHistory history;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int minutes = jour.playing.inMinutes;
    return Card(
      key: ProgressScreen.journalKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Aujourd hui', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              jour.takes.isEmpty
                  ? 'Rien encore aujourd hui.'
                  : '${jour.takes.length} prise${jour.takes.length > 1 ? 's' : ''}'
                      ', ${minutes < 1 ? 'moins d une minute' : '$minutes min'}'
                      ' d archet',
              style: theme.textTheme.bodyMedium,
            ),
            for (final String k in jour.keys)
              if (jour.recordFor(history, k) case final int r)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${history.forKey(k).last.title} : nouveau record, $r',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// La courbe d'un travail : le tempo tenu au bout, jour apres jour (H4).
class _Courbe extends StatelessWidget {
  const _Courbe({required this.serie});

  final ProgressSeries serie;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProgressPoint dernier = serie.points.last;
    final int? record = serie.bestPulseBpm;
    return Card(
      key: ProgressScreen.courbeKey(serie.key),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(serie.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              <String>[
                if (record != null) 'Record : $record',
                if (dernier.tuningScore != null)
                  'justesse ${dernier.tuningScore}',
                if (dernier.rhythmScore != null)
                  'rythme ${dernier.rhythmScore}',
              ].join(' - '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: CustomPaint(
                painter: _Trace(
                  valeurs: <int?>[
                    for (final ProgressPoint p in serie.points) p.heldPulseBpm,
                  ],
                  couleur: theme.colorScheme.primary,
                  grille: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne qui monte, ou qui monterait. Un point par jour joue.
class _Trace extends CustomPainter {
  _Trace({required this.valeurs, required this.couleur, required this.grille});

  final List<int?> valeurs;
  final Color couleur;
  final Color grille;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = grille,
    );
    final List<(int, int)> points = <(int, int)>[
      for (int i = 0; i < valeurs.length; i++)
        if (valeurs[i] != null) (i, valeurs[i]!),
    ];
    if (points.isEmpty) {
      return;
    }
    int min = points.first.$2;
    int max = points.first.$2;
    for (final (int, int) p in points) {
      min = p.$2 < min ? p.$2 : min;
      max = p.$2 > max ? p.$2 : max;
    }
    // Un peu d'air au-dessus et au-dessous : une ligne plate reste lisible.
    final double bas = min - 4;
    final double haut = max + 4;
    Offset vers((int, int) p) => Offset(
          valeurs.length == 1
              ? size.width / 2
              : p.$1 / (valeurs.length - 1) * size.width,
          size.height - (p.$2 - bas) / (haut - bas) * size.height,
        );
    final Paint trait = Paint()
      ..color = couleur
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final Path chemin = Path()
      ..moveTo(vers(points.first).dx, vers(points.first).dy);
    for (final (int, int) p in points.skip(1)) {
      chemin.lineTo(vers(p).dx, vers(p).dy);
    }
    canvas.drawPath(chemin, trait);
    for (final (int, int) p in points) {
      canvas.drawCircle(vers(p), 3, Paint()..color = couleur);
    }
  }

  @override
  bool shouldRepaint(_Trace old) =>
      old.valeurs != valeurs || old.couleur != couleur;
}

/// Ce que la main fait d'un doigt, sur plusieurs cordes (H3).
///
/// **Un seul doigt a la fois**, le plus net : *voila ta prochaine tache*, pas
/// la liste de tout ce qui derive.
class _Main extends StatelessWidget {
  const _Main({required this.trouve});

  final FingerFinding trouve;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> cordes = <String>[
      for (final ViolinString c in ViolinString.values)
        if (trouve.strings.contains(c)) c.name,
    ];
    final String ou = cordes.length == 1
        ? 'sur la corde de ${cordes.single}'
        : 'sur les cordes de ${cordes.sublist(0, cordes.length - 1).join(', ')}'
            ' et ${cordes.last}';
    return Card(
      key: ProgressScreen.mainKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Ta main gauche', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Ton ${trouve.place.label} tombe ${trouve.flat ? 'bas' : 'haut'}, '
              '$ou. ${trouve.flat ? 'Avance-le' : 'Recule-le'} un peu vers '
              '${trouve.flat ? 'le chevalet' : 'la volute'}.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
