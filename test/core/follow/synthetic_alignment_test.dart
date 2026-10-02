// Lent : une quinzaine de secondes de synthese, d'oreille et d'alignement.
// Exclu de `make test`, lance par `make test-lent` et toujours par la CI.
@Tags(<String>['lent'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/audio/violin_synth.dart';
import 'package:violon/core/follow/alignment_report.dart';
import 'package:violon/core/follow/offline_aligner.dart';
import 'package:violon/core/follow/performance_features.dart';
import 'package:violon/core/follow/reanchoring.dart';
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
    test('$nom, en direct', () {
      // Le suiveur en direct ne peut pas se corriger apres coup : il est
      // tenu un peu moins haut que l'aligneur, qui reste sa borne (S2).
      final AlignmentReport r = suivre(
        scenario.build(),
        p,
        slurredInto: liees,
        synth: synth,
      );
      final String rates = r.misses
          .map((NoteVerdict v) => '${v.label.noteId}>${v.alignedId}')
          .join(' ');
      expect(r.measureRate, greaterThanOrEqualTo(0.85), reason: rates);
      expect(r.noteRate, greaterThanOrEqualTo(0.85), reason: rates);
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

  group('Re-ancrage (S3)', () {
    // Le piege des vraies prises : une phrase qui revient, et l'eleve qui
    // revient au debut. En direct, rien ne distingue "il reprend la mesure 1"
    // de "il continue a la mesure 3" avant la deuxieme note de la mesure
    // suivante. On exige qu'il se retrouve des que la musique le permet.
    test('une phrase repetee et un retour au debut', () {
      final Passage q = phraseRepetee();
      final SyntheticTake prise = (TakeScript(q, seed: 9)
            ..play('n1', 'n8')
            ..play('n1', 'n16'))
          .build();
      final List<FeatureFrame> trames =
          PerformanceFeatures.extract(prise.render(ViolinSynth()));
      final GroundTruth verite =
          GroundTruth.parseAudacity(prise.audacityLabels());
      final List<Discontinuity> direct =
          Reanchoring.measure(enDirect(trames, q), verite, q);
      final Discontinuity retour = direct.last;
      expect(retour.noteId, 'n1');
      // Deux noires a 92 font 1,3 s : la musique ne tranche qu'a la
      // deuxieme note de la mesure 2 ou 4, soit cinq noires apres le retour.
      expect(retour.recoveryMs, isNotNull);
      expect(retour.recoveryMs, lessThanOrEqualTo(4000));
      // L'aligneur, qui voit la suite, se retrouve tout de suite.
      final List<Discontinuity> horsLigne = Reanchoring.measure(
        OfflineAligner(q).align(trames),
        verite,
        q,
      );
      expect(horsLigne.last.recoveryMs, lessThanOrEqualTo(100));
    });

    test('apres un arret, il repart d ou l eleve repart', () {
      final SyntheticTake prise = (TakeScript(p, seed: 10)
            ..play('n1', 'n13')
            ..pause(const Duration(seconds: 2))
            ..play('n5', 'n22'))
          .build();
      final List<FeatureFrame> trames =
          PerformanceFeatures.extract(prise.render(ViolinSynth()));
      final List<Discontinuity> d = Reanchoring.measure(
        enDirect(trames, p),
        GroundTruth.parseAudacity(prise.audacityLabels()),
        p,
      );
      for (final Discontinuity x in d) {
        expect(x.recoveryMs, isNotNull, reason: '$x');
        expect(x.recoveryMs, lessThanOrEqualTo(500), reason: '$x');
      }
    });
  });
}
