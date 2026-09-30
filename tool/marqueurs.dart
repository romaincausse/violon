// L'annotation corrigee du banc d'essai (docs/banc-d-essai.md).
//
//   dart run tool/marqueurs.dart proposer <prise>
//       ecrit <prise>.app.txt : un marqueur par note, pose par l'aligneur,
//       a importer dans Audacity (Fichier > Importer > Marqueurs).
//
//   dart run tool/marqueurs.dart valider <prise>
//       lit <prise>.corrige.txt, exporte d'Audacity apres correction, et
//       ecrit <prise>.labels.txt, les etiquettes que lit tool/banc.dart.
//
// <prise> est le nom sans extension, par exemple 05-stars-arret-reprise.
import 'dart:io';

import 'package:violon/core/follow/proposed_labels.dart';

import 'src/prise.dart';

void main(List<String> args) {
  if (args.length != 2 || !<String>{'proposer', 'valider'}.contains(args[0])) {
    stderr.writeln('usage : dart run tool/marqueurs.dart proposer|valider '
        '<prise>');
    exitCode = 64;
    return;
  }
  final String banc = dossierDuBanc();
  final String base = '$banc/prises/${args[1]}';
  final (Prise? prise, String? motif) = Prise.lire(base, banc);
  if (prise == null) {
    stderr.writeln(motif);
    exitCode = 1;
    return;
  }

  if (args[0] == 'proposer') {
    final String marqueurs =
        ProposedLabels.propose(prise.aligner(), prise.partition.passage);
    File('$base.app.txt').writeAsStringSync(marqueurs);
    stdout.writeln(
      '${'\n'.allMatches(marqueurs).length} marqueurs dans $base.app.txt',
    );
    return;
  }

  final File corrige = File('$base.corrige.txt');
  if (!corrige.existsSync()) {
    stderr.writeln('Pas de ${corrige.path} : exporter les marqueurs corriges '
        'depuis Audacity sous ce nom.');
    exitCode = 1;
    return;
  }
  try {
    final (String etiquettes, List<String> deduites) = ProposedLabels.resolve(
      corrige.readAsStringSync(),
      prise.partition.passage,
    );
    File('$base.labels.txt').writeAsStringSync(etiquettes);
    stdout.writeln('Etiquettes ecrites dans $base.labels.txt');
    if (deduites.isNotEmpty) {
      stdout.writeln('\nIdentifiants deduits des corrections, a relire :');
      deduites.forEach(stdout.writeln);
    }
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  }
}
