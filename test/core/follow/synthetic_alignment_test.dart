import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/alignment_report.dart';
import 'package:violon/core/follow/synthetic_take.dart';
import 'package:violon/core/music/passage.dart';

import 'scenarios.dart';

/// Toute la chaine sur des prises de synthese : signal, oreille, alignement,
/// verdict.
///
/// **Ces seuils ne prouvent rien sur le vrai violon** (lot P0) : ils gardent
/// l'aligneur de regresser pendant qu'on le developpera. Le critere du jalon
/// se mesure sur les prises reelles, avec `tool/banc.dart`.
void main() {
  final Passage p = melodie();

  void verifie(
    String nom,
    TakeScript scenario, {
    Set<String> liees = const <String>{},
    ViolinSynth? synth,
  }) {
    test(nom, () {
      final AlignmentReport r = aligner(
        scenario.build(),
        p,
        slurredInto: liees,
        synth: synth,
      );
      final String rates = r.misses
          .map((NoteVerdict v) => '${v.label.noteId}>${v.alignedId}')
          .join(' ');
      expect(r.measureRate, greaterThanOrEqualTo(0.95), reason: rates);
      expect(r.noteRate, greaterThanOrEqualTo(0.90), reason: rates);
      expect(r.extrasTakenForNotes, 0);
    });
  }

  group('Alignement de prises de synthese', () {
    verifie('du debut a la fin', TakeScript(p, seed: 1)..play('n1', 'n22'));

    verifie(
      'arret puis reprise de la mesure',
      TakeScript(p, seed: 2)
        ..play('n1', 'n13')
        ..pause(const Duration(seconds: 2))
        ..play('n11', 'n22'),
    );

    verifie(
      'retour en arriere sans s arreter',
      TakeScript(p, seed: 3)
        ..play('n1', 'n12')
        ..play('n5', 'n22'),
    );

    verifie(
      'lent, avec des hesitations',
      TakeScript(p, seed: 4, tempoBpm: 50)
        ..play('n1', 'n6')
        ..pause(const Duration(milliseconds: 1500))
        ..play('n7', 'n14')
        ..pause(const Duration(milliseconds: 800))
        ..play('n15', 'n22'),
    );

    verifie(
      'fausses notes, note sautee, note ajoutee',
      TakeScript(p, seed: 5)
        ..play(
          'n1',
          'n9',
          centsOff: <String, double>{'n3': 80, 'n7': -70},
          skip: <String>{'n2'},
        )
        ..extra(80)
        ..play('n10', 'n22'),
    );

    verifie(
      'liaisons',
      TakeScript(p, seed: 6)
        ..play('n1', 'n14')
        ..play('n15', 'n20', slurred: true)
        ..play('n21', 'n22'),
      liees: <String>{'n16', 'n17', 'n18', 'n19', 'n20'},
    );

    verifie(
      'vibrato, violon accorde a 443',
      TakeScript(p, seed: 7, tempoBpm: 70, vibratoCents: 35)..play('n1', 'n22'),
      synth: ViolinSynth(a4: 443),
    );

    verifie(
      'une vraie seance : reprises dans les notes repetees',
      TakeScript(p, seed: 8, intonationSpreadCents: 12)
        ..play('n1', 'n6')
        ..pause(const Duration(milliseconds: 1200))
        ..play('n5', 'n8')
        ..play('n5', 'n10', centsOff: <String, double>{'n9': 60})
        ..pause(const Duration(seconds: 2))
        ..play('n5', 'n14')
        ..play('n11', 'n17')
        ..extra(66)
        ..play('n18', 'n22', skip: <String>{'n19'}),
    );
  });
}
