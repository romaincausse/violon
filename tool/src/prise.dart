// Ce que banc.dart et marqueurs.dart partagent : lire une prise du banc et
// la faire aligner, exactement de la meme facon dans les deux outils.
import 'dart:convert';
import 'dart:io';

import 'package:violon/core/audio/wav.dart';
import 'package:violon/core/follow/bench_score.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/music/pitch_utils.dart';

String dossierDuBanc() =>
    Platform.environment['VIOLON_BANC'] ??
    '${Platform.environment['HOME']}/violon-banc';

/// Une prise et tout ce qu'il faut pour l'aligner.
class Prise {
  Prise._(this.nom, this.base, this.meta, this.partition);

  final String nom;

  /// Chemin sans extension : `<base>.wav`, `<base>.json`, `<base>.labels.txt`.
  final String base;
  final Map<String, Object?> meta;
  final BenchScore partition;

  /// Lit la prise [base], ou rend le motif de son absence.
  static (Prise?, String?) lire(String base, String banc) {
    final String nom = base.split('/').last;
    final File meta = File('$base.json');
    if (!File('$base.wav').existsSync() || !meta.existsSync()) {
      return (null, '$nom : son ou metadonnees absents');
    }
    final Map<String, Object?> m =
        jsonDecode(meta.readAsStringSync()) as Map<String, Object?>;
    final File fichier = File('$banc/partitions/${m['partition']}.json');
    if (!fichier.existsSync()) {
      return (null, '$nom : partition ${m['partition']} absente');
    }
    final BenchScore partition = BenchScore.fromJson(
      jsonDecode(fichier.readAsStringSync()) as Map<String, Object?>,
    );
    return (Prise._(nom, base, m, partition), null);
  }

  Alignment aligner() {
    final WavData son = Wav.decode(File('$base.wav').readAsBytesSync());
    final double a4 =
        (meta['la_mesure_hz'] as num?)?.toDouble() ?? PitchUtils.defaultA4;
    return OfflineAligner(
      partition.passage,
      slurredInto: partition.slurredInto,
    ).align(
      PerformanceFeatures.extract(
        son.samples,
        sampleRate: son.sampleRate,
        a4: a4,
      ),
    );
  }
}
