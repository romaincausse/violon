import 'package:flutter/material.dart';

import '../../core/import/imported_piece.dart';
import '../../core/music/passage.dart';
import '../widgets/score_view.dart';

/// Ce que l'ecran d'un morceau rend en se fermant.
sealed class PieceAction {
  const PieceAction();
}

/// Travailler les mesures [from] a [to].
class WorkBars extends PieceAction {
  const WorkBars(this.from, this.to);

  final int from;
  final int to;
}

/// Retirer le morceau du repertoire.
class RemovePiece extends PieceAction {
  const RemovePiece();
}

/// Un morceau importe : choisir les mesures a travailler.
///
/// **On ne travaille pas un morceau, on travaille des mesures.** L'ecran ne
/// propose pas "jouer le morceau" : il demande lesquelles, et montre tout de
/// suite ce qu'on a choisi, grave, pour qu'on le reconnaisse sur son papier.
///
/// **Huit mesures par defaut.** Assez pour une phrase, assez peu pour que
/// l'objectif soit fini et visible des le premier passage.
class PieceScreen extends StatefulWidget {
  const PieceScreen({
    required this.piece,
    this.initialFrom,
    this.initialTo,
    super.key,
  });

  final ImportedPiece piece;

  /// Les mesures travaillees la derniere fois, s'il y en a eu.
  final int? initialFrom;
  final int? initialTo;

  static const Key travaillerKey = Key('travailler-ces-mesures');
  static const Key retirerKey = Key('retirer-le-morceau');
  static const Key mesuresKey = Key('choisir-les-mesures');

  /// Longueur proposee a l'ouverture d'un morceau neuf.
  static const int mesuresParDefaut = 8;

  @override
  State<PieceScreen> createState() => _PieceScreenState();
}

class _PieceScreenState extends State<PieceScreen> {
  late int _de;
  late int _a;

  int get _premiere => widget.piece.firstMeasure;
  int get _derniere => widget.piece.lastMeasure;

  @override
  void initState() {
    super.initState();
    final int? de = widget.initialFrom;
    final int? a = widget.initialTo;
    if (de != null && a != null && de >= _premiere && a <= _derniere) {
      _de = de;
      _a = a;
    } else {
      _de = _premiere;
      _a = (_premiere + PieceScreen.mesuresParDefaut - 1).clamp(
        _premiere,
        _derniere,
      );
    }
  }

  Future<void> _retirer() async {
    final bool? oui = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Retirer ce morceau ?'),
        content: Text(
          '${widget.piece.title} disparait du repertoire. Le fichier '
          'd origine n est pas touche : il pourra etre reimporte.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Garder'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (oui == true && mounted) {
      Navigator.of(context).pop<PieceAction>(const RemovePiece());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ImportedPiece piece = widget.piece;
    final Passage? extrait = piece.excerpt(_de, _a);
    final Passage tout = piece.passage;
    final List<String> details = <String>[
      if (piece.composer != null) piece.composer!,
      '${_derniere - _premiere + 1} mesures',
      if (tout.meter != null) '${tout.meter}',
      'noire = ${tout.writtenTempoBpm}',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(piece.title),
        actions: <Widget>[
          IconButton(
            key: PieceScreen.retirerKey,
            tooltip: 'Retirer du repertoire',
            icon: const Icon(Icons.delete_outline),
            onPressed: _retirer,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(details.join(' - '), style: theme.textTheme.bodyMedium),
            if (piece.warnings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _Simplifications(warnings: piece.warnings),
            ],
            const SizedBox(height: 24),
            Text(
              _de == _a ? 'Mesure $_de' : 'Mesures $_de a $_a',
              style: theme.textTheme.titleMedium,
            ),
            if (_derniere > _premiere)
              RangeSlider(
                key: PieceScreen.mesuresKey,
                min: _premiere.toDouble(),
                max: _derniere.toDouble(),
                divisions: _derniere - _premiere,
                values: RangeValues(_de.toDouble(), _a.toDouble()),
                labels: RangeLabels('$_de', '$_a'),
                onChanged: (RangeValues v) => setState(() {
                  _de = v.start.round();
                  _a = v.end.round();
                }),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: extrait == null
                  ? Center(
                      child: Text(
                        'Que des silences : rien a jouer ici.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ScoreView(passage: extrait, maxSpaceSize: 10),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: PieceScreen.travaillerKey,
              onPressed: extrait == null
                  ? null
                  : () =>
                      Navigator.of(context).pop<PieceAction>(WorkBars(_de, _a)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Travailler ces mesures'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ce que l'import a du simplifier.
///
/// **Une information, pas une alerte.** Pas de rouge, pas d'icone de danger :
/// une double corde reduite a sa note aigue n'est la faute de personne. Mais
/// il faut le dire, parce que l'application jugera sur cette partition-la.
class _Simplifications extends StatelessWidget {
  const _Simplifications({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ce que l import a simplifie',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final String w in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(w, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
