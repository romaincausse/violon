// Passe l'aligneur sur tout le banc d'essai et rend le chiffre du jalon 5.
//
//   dart run tool/banc.dart [--detail]
//
// Lit $VIOLON_BANC (par defaut ~/violon-banc/), organise comme le decrit
// docs/banc-d-essai.md :
//
//   partitions/<id>.json
//   prises/<prise>.wav, .labels.txt, .json   <- comptent pour le critere
//   synthese/<prise>.wav, .labels.txt, .json <- rapportees, jamais comptees
//
// Les regles de comptage sont celles du protocole, fixees avant d'avoir vu
// un chiffre : voir AlignmentReport.
import 'dart:convert';
import 'dart:io';

import 'package:violon/core/audio/wav.dart';
import 'package:violon/core/follow/alignment_report.dart';
import 'package:violon/core/follow/bench_score.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/pitch_utils.dart';

/// Les pieges qui font d'une prise une prise "avec reprise" au sens du
/// critere.
const Set<String> piegesDeReprise = <String>{'arret-reprise', 'saut-arriere'};

class Resultat {
  Resultat(this.nom, this.meta, this.rapport);

  final String nom;
  final Map<String, Object?> meta;
  final AlignmentReport rapport;

  bool get critere => meta['critere'] == true;

  List<String> get pieges => <String>[
        for (final Object? p
            in (meta['pieges'] as List<Object?>?) ?? <Object?>[])
          '$p',
      ];

  bool get avecReprise => pieges.any(piegesDeReprise.contains);
}

void main(List<String> args) {
  final bool detail = args.contains('--detail');
  final String banc = Platform.environment['VIOLON_BANC'] ??
      '${Platform.environment['HOME']}/violon-banc';
  if (!Directory(banc).existsSync()) {
    stderr.writeln('Pas de banc dans $banc (variable VIOLON_BANC).');
    exitCode = 1;
    return;
  }

  final List<Resultat> reelles = _passer('$banc/prises', banc, detail);
  final List<Resultat> synthese = _passer('$banc/synthese', banc, detail);

  if (synthese.isNotEmpty) {
    stdout.writeln('\nSynthese (jamais comptee pour le critere)');
    _tableau(synthese);
  }
  stdout.writeln('\nPrises reelles');
  if (reelles.isEmpty) {
    stdout.writeln('  aucune');
    return;
  }
  _tableau(reelles);
  _verdict(reelles);
}

List<Resultat> _passer(String dossier, String banc, bool detail) {
  final Directory d = Directory(dossier);
  if (!d.existsSync()) {
    return <Resultat>[];
  }
  final List<File> wavs = d
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.wav'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));

  final List<Resultat> resultats = <Resultat>[];
  for (final File wav in wavs) {
    final String base = wav.path.substring(0, wav.path.length - 4);
    final String nom = base.split('/').last;
    final File etiquettes = File('$base.labels.txt');
    final File meta = File('$base.json');
    if (!etiquettes.existsSync() || !meta.existsSync()) {
      stderr.writeln('$nom : etiquettes ou metadonnees absentes, prise sautee');
      continue;
    }
    final Map<String, Object?> m =
        jsonDecode(meta.readAsStringSync()) as Map<String, Object?>;
    final File fichierPartition =
        File('$banc/partitions/${m['partition']}.json');
    if (!fichierPartition.existsSync()) {
      stderr
          .writeln('$nom : partition ${m['partition']} absente, prise sautee');
      continue;
    }
    final BenchScore partition = BenchScore.fromJson(
      jsonDecode(fichierPartition.readAsStringSync()) as Map<String, Object?>,
    );

    final WavData son = Wav.decode(wav.readAsBytesSync());
    final double a4 =
        (m['la_mesure_hz'] as num?)?.toDouble() ?? PitchUtils.defaultA4;
    final Alignment alignement = OfflineAligner(
      partition.passage,
      slurredInto: partition.slurredInto,
    ).align(
      PerformanceFeatures.extract(
        son.samples,
        sampleRate: son.sampleRate,
        a4: a4,
      ),
    );
    final AlignmentReport rapport = AlignmentReport.evaluate(
      alignement,
      GroundTruth.parseAudacity(etiquettes.readAsStringSync()),
      partition.passage,
    );
    resultats.add(Resultat(nom, m, rapport));

    if (detail) {
      stdout.writeln('\n$nom');
      for (final NoteVerdict v in rapport.misses) {
        final String t = (v.label.timeMs / 1000).toStringAsFixed(2);
        stdout.writeln(
          '  ${t}s  ${v.label.noteId}${v.label.wrong ? ' faux' : ''}'
          '  ->  ${v.alignedId ?? 'silence'}',
        );
      }
    }
  }
  return resultats;
}

void _tableau(List<Resultat> resultats) {
  stdout.writeln(
    '  ${'prise'.padRight(32)} notes  mesure   note   x pris  pieges',
  );
  for (final Resultat r in resultats) {
    final AlignmentReport a = r.rapport;
    stdout.writeln(
      '  ${r.nom.padRight(32)} '
      '${'${a.counted}'.padLeft(5)}  '
      '${_pc(a.measureRate).padLeft(6)} '
      '${_pc(a.noteRate).padLeft(6)}   '
      '${'${a.extrasTakenForNotes}/${a.extras}'.padLeft(6)}  '
      '${r.pieges.join(', ')}${r.critere ? '' : '  (hors critere)'}',
    );
  }
}

/// Le critere du jalon : 95 % dans la bonne mesure, 90 % sur la bonne note,
/// sur l'ensemble **et** sur les prises avec reprise -- 95 % global peut
/// cacher 60 % sur les reprises, qui sont le cas nominal.
void _verdict(List<Resultat> reelles) {
  final List<Resultat> critere =
      reelles.where((Resultat r) => r.critere).toList();
  final List<Resultat> reprises =
      critere.where((Resultat r) => r.avecReprise).toList();

  stdout.writeln();
  final bool ensemble = _seuils('Ensemble', critere);
  final bool avecReprise = _seuils('Avec reprise', reprises);

  if (critere.length < 10 || reprises.length < 3) {
    stdout.writeln(
      '\nBanc incomplet : ${critere.length} prises au critere sur 10, '
      '${reprises.length} avec reprise sur 3. Pas de verdict.',
    );
    return;
  }
  stdout.writeln(
    ensemble && avecReprise
        ? '\nCritere tenu.'
        : '\nCritere NON tenu : c\'est le plan qui change (jalon 5).',
  );
}

bool _seuils(String nom, List<Resultat> prises) {
  int total = 0;
  int mesure = 0;
  int note = 0;
  for (final Resultat r in prises) {
    total += r.rapport.counted;
    mesure += r.rapport.rightMeasure;
    note += r.rapport.rightNote;
  }
  if (total == 0) {
    stdout.writeln('  ${nom.padRight(14)} aucune note');
    return false;
  }
  final double m = mesure / total;
  final double n = note / total;
  final bool tenu = m >= 0.95 && n >= 0.90;
  stdout.writeln(
    '  ${nom.padRight(14)} ${prises.length} prises, $total notes : '
    'mesure ${_pc(m)} (>= 95 %), note ${_pc(n)} (>= 90 %)  '
    '${tenu ? 'tenu' : 'NON TENU'}',
  );
  return tenu;
}

String _pc(double v) => '${(100 * v).toStringAsFixed(1)} %';
