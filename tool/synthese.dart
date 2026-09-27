// Ecrit une prise de synthese dans le banc d'essai, pour l'ecouter dans
// Audacity a cote des vraies.
//
//   dart run tool/synthese.dart [graine]
//
// Le WAV et ses etiquettes vont dans $VIOLON_BANC/synthese/ (par defaut
// ~/violon-banc/synthese/), hors du depot comme tout le banc. Une prise de
// synthese sert a construire l'aligneur, jamais a le juger : voir le lot P0
// dans docs/plan.md.
import 'dart:convert';
import 'dart:io';

import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/audio/wav.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/follow/bench_score.dart';
import 'package:violon/core/follow/synthetic_take.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';

void main(List<String> args) {
  final int graine = args.isEmpty ? 1 : int.parse(args.first);

  final Exercise gamme = ExerciseCatalog.byId('gamme-sol-majeur-1')!;
  final PassageBuilder b = PassageBuilder();
  for (final int midi in gamme.midis) {
    b.add(midi, NoteValue.quarter);
  }
  final Passage passage = Passage(
    title: gamme.titre,
    notes: b.notes,
    ticksPerBeat: b.ticksPerBeat,
    writtenTempoBpm: gamme.tempoVise,
  );
  final String derniere = passage.notes.last.id;

  // Une seance de travail comme le protocole les decrit : un depart, une
  // fausse note, un arret, la reprise de la mesure, une liaison, une note
  // ajoutee, et une fin tenue avec vibrato.
  final TakeScript script = TakeScript(passage, seed: graine)
    ..play('n1', 'n6', centsOff: <String, double>{'n4': 65})
    ..pause(const Duration(milliseconds: 1800))
    ..play('n5', 'n8', slurred: true)
    ..extra(passage.notes[7].midi + 2)
    ..tempo(60)
    ..play('n9', derniere, vibratoCents: 30);
  final SyntheticTake prise = script.build();

  final String banc = Platform.environment['VIOLON_BANC'] ??
      '${Platform.environment['HOME']}/violon-banc';
  final Directory dossier = Directory('$banc/synthese')
    ..createSync(recursive: true);
  final String nom = '${dossier.path}/gamme-sol-seance-g$graine';
  const JsonEncoder json = JsonEncoder.withIndent('  ');

  // La partition et les metadonnees, au format du protocole : tool/banc.dart
  // lit une prise de synthese exactement comme une vraie.
  final Directory partitions = Directory('$banc/partitions')
    ..createSync(recursive: true);
  File('${partitions.path}/${gamme.id}.json').writeAsStringSync(
    json.convert(
      BenchScore.toJson(passage, slurredInto: <String>{'n6', 'n7', 'n8'}),
    ),
  );
  File('$nom.json').writeAsStringSync(
    json.convert(<String, Object?>{
      'id': nom.split('/').last,
      'partition': gamme.id,
      'consigne': 'synthese, graine $graine',
      'pieges': <String>['arret-reprise', 'fausse-note', 'liaison'],
      'critere': false,
      'la_mesure_hz': 440,
    }),
  );

  File('$nom.wav').writeAsBytesSync(
    Wav.encode(prise.render(ViolinSynth(seed: graine))),
  );
  File('$nom.labels.txt').writeAsStringSync(prise.audacityLabels());
  stdout.writeln('$nom.wav, ${prise.notes.length} notes jouees');
}
