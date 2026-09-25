import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/finger_pattern.dart';
import 'package:violon/core/music/pitch_utils.dart';

void main() {
  group('FingerPattern', () {
    test('les quatre ecartements de la premiere position sont bien formes', () {
      for (final FingerPattern pattern in FingerPattern.premierePosition) {
        expect(pattern.semitones.length, 5, reason: pattern.id);
        expect(pattern.semitones.first, 0, reason: pattern.id);
        // Le quatrieme doigt tombe sur la quinte, c est-a-dire sur la corde
        // a vide suivante. C est vrai des quatre ecartements, et c est ce qui
        // permet a l eleve de verifier son quatrieme doigt a l oreille.
        expect(pattern.semitones.last, 7, reason: pattern.id);
        for (int i = 1; i < pattern.semitones.length; i++) {
          expect(pattern.semitones[i], greaterThan(pattern.semitones[i - 1]),
              reason: '${pattern.id}, doigt $i');
        }
      }
    });

    test('chaque ecartement serre une paire de doigts differente', () {
      final Set<int> serres = <int>{};
      for (final FingerPattern pattern in FingerPattern.premierePosition) {
        final List<int> demiTons = <int>[];
        for (int i = 1; i < pattern.semitones.length; i++) {
          if (pattern.semitones[i] - pattern.semitones[i - 1] == 1) {
            demiTons.add(i - 1);
          }
        }
        expect(demiTons.length, 1, reason: '${pattern.id} serre $demiTons');
        serres.add(demiTons.single);
      }
      expect(serres, <int>{0, 1, 2, 3});
    });

    test('sur la corde de re, 2-3 serres donne re mi fa# sol la', () {
      const FingerPattern majeur = FingerPattern.deuxTroisSerres;
      expect(
        <int>[
          for (int d = 0; d <= 4; d++) majeur.midiFor(stringMidi: 62, finger: d)
        ],
        <int>[62, 64, 66, 67, 69],
      );
    });

    test('sur la corde de re, 1-2 serres donne re mi fa sol la', () {
      const FingerPattern mineur = FingerPattern.unDeuxSerres;
      expect(
        <int>[
          for (int d = 0; d <= 4; d++) mineur.midiFor(stringMidi: 62, finger: d)
        ],
        <int>[62, 64, 65, 67, 69],
      );
    });
  });

  group('FingerMotif', () {
    test('le motif se promene sur les quatre cordes', () {
      final List<int> notes = FingerMotif.enLigne.midis(
        pattern: FingerPattern.deuxTroisSerres,
        strings: PitchUtils.violinOpenStrings,
      );
      expect(notes.length, 32);
      expect(notes.sublist(0, 8), <int>[55, 57, 59, 60, 62, 60, 59, 57]);
      expect(notes.sublist(8, 16), <int>[62, 64, 66, 67, 69, 67, 66, 64]);
    });

    test('noteCount annonce ce que midis produit', () {
      for (final FingerMotif motif in FingerMotif.all) {
        expect(
          motif.noteCount(4),
          motif
              .midis(
                pattern: FingerPattern.deuxTroisSerres,
                strings: PitchUtils.violinOpenStrings,
              )
              .length,
          reason: motif.id,
        );
      }
    });

    test('la verification revient a la corde a vide toutes les deux notes', () {
      final List<int> notes = FingerMotif.verification.midis(
        pattern: FingerPattern.deuxTroisSerres,
        strings: <int>[62],
      );
      expect(notes, <int>[64, 62, 66, 62, 67, 62, 69, 62]);
    });

    test('aucun motif ne repete deux fois la meme hauteur a la suite', () {
      // Le quatrieme doigt d une corde sonne la corde a vide suivante : un
      // motif mal ordonne produirait donc un unisson, et le detecteur
      // d attaques n y verrait qu une seule note.
      for (final FingerMotif motif in FingerMotif.all) {
        for (final FingerPattern pattern in FingerPattern.premierePosition) {
          final List<int> notes = motif.midis(
            pattern: pattern,
            strings: PitchUtils.violinOpenStrings,
          );
          for (int i = 1; i < notes.length; i++) {
            expect(notes[i], isNot(notes[i - 1]),
                reason: '${motif.id} / ${pattern.id}, note $i');
          }
        }
      }
    });
  });
}
