import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/passage_builder.dart';
import 'package:violon/core/score/score_layout.dart';
import 'package:violon/core/score/staff_layout.dart';

void main() {
  /// Un passage de [mesures] mesures a quatre temps, une noire par temps.
  Passage passageDe(int mesures, {int beatsPerMeasure = 4}) {
    final PassageBuilder b = PassageBuilder(beatsPerMeasure: beatsPerMeasure);
    for (int i = 0; i < mesures * beatsPerMeasure; i++) {
      b.add(69, NoteValue.quarter);
    }
    return b.build();
  }

  /// Largeur qu'occuperait le passage entier sur une seule ligne.
  double surUneLigne(Passage p) => StaffLayout.of(p).widthSpaces;

  group('ScoreLayout', () {
    test('un passage qui tient tient sur un seul systeme', () {
      final Passage p = passageDe(2);
      final ScoreLayout l = ScoreLayout.of(
        p,
        maxWidthSpaces: surUneLigne(p) + 10,
      );
      expect(l.systemCount, 1);
      expect(l.systems.single.notes, hasLength(p.notes.length));
    });

    test('un passage trop long passe a la ligne', () {
      final Passage p = passageDe(4);
      final ScoreLayout l = ScoreLayout.of(
        p,
        maxWidthSpaces: surUneLigne(p) / 2,
      );
      expect(l.systemCount, greaterThan(1));
    });

    test('aucune note ne se perd ni ne se duplique', () {
      final Passage p = passageDe(5);
      final ScoreLayout l = ScoreLayout.of(p, maxWidthSpaces: 40);
      final List<String> ids = <String>[
        for (final s in l.systems)
          for (final n in s.notes) n.note.id,
      ];
      expect(ids, p.notes.map((n) => n.id).toList());
    });

    test('on ne coupe jamais au milieu d une mesure', () {
      // Une mesure commencee doit finir sur la meme ligne : c'est une faute
      // de gravure, et surtout illisible pour qui suit la pulsation.
      final Passage p = passageDe(6);
      final ScoreLayout l = ScoreLayout.of(p, maxWidthSpaces: 45);
      expect(l.systemCount, greaterThan(1));
      for (final s in l.systems) {
        final Set<int> mesures = s.notes.map((n) => n.note.measure).toSet();
        for (final int m in mesures) {
          final int dansLeSysteme =
              s.notes.where((n) => n.note.measure == m).length;
          final int enTout = p.notes.where((n) => n.measure == m).length;
          expect(dansLeSysteme, enTout, reason: 'mesure $m coupee en deux');
        }
      }
    });

    test('chaque systeme repart de sa propre gauche', () {
      // Sinon le deuxieme systeme commencerait a l'abscisse ou le premier
      // s'est arrete, donc hors de l'ecran.
      final ScoreLayout l = ScoreLayout.of(passageDe(4), maxWidthSpaces: 45);
      expect(l.systemCount, greaterThan(1));
      for (final s in l.systems) {
        expect(s.notes.first.xSpaces, l.systems.first.notes.first.xSpaces);
      }
    });

    test('une mesure plus large que la ligne reste entiere', () {
      // Seize doubles croches dans une mesure, sur un ecran etroit : on ne la
      // coupe pas pour autant. Une ligne trop longue vaut mieux qu'une mesure
      // escamotee.
      final PassageBuilder b = PassageBuilder();
      for (int i = 0; i < 16; i++) {
        b.add(69, NoteValue.sixteenth);
      }
      final Passage p = b.build();
      final ScoreLayout l = ScoreLayout.of(p, maxWidthSpaces: 20);
      expect(l.systemCount, 1);
      expect(l.widthSpaces, greaterThan(20));
    });

    test('le plafond de systemes est respecte', () {
      final Passage p = passageDe(8);
      final ScoreLayout l = ScoreLayout.of(
        p,
        maxWidthSpaces: 40,
        maxSystems: 2,
      );
      expect(l.systemCount, 2);
      // Le dernier systeme deborde, et c'est voulu : on prefere une ligne
      // trop longue a des mesures qui disparaissent.
      final List<String> ids = <String>[
        for (final s in l.systems)
          for (final n in s.notes) n.note.id,
      ];
      expect(ids, hasLength(p.notes.length));
    });

    group('position d un instant', () {
      final Passage p = passageDe(4);
      final ScoreLayout l = ScoreLayout.of(p, maxWidthSpaces: 45);

      test('le passage est bien sur plusieurs systemes', () {
        expect(l.systemCount, greaterThan(1));
      });

      test('la premiere note est sur le premier systeme', () {
        final (int systeme, double _) = l.positionOfTick(0);
        expect(systeme, 0);
      });

      test('la derniere note est sur le dernier systeme', () {
        final (int systeme, double _) =
            l.positionOfTick(p.notes.last.onsetTicks);
        expect(systeme, l.systemCount - 1);
      });

      test('le curseur avance dans un systeme puis saute au suivant', () {
        // Ce que le curseur doit faire a l'oeil : glisser vers la droite,
        // puis repartir de la gauche une ligne plus bas.
        int precedentSysteme = 0;
        double precedentX = -1;
        bool aSaute = false;
        for (int t = 0; t <= p.notes.last.offsetTicks; t += 60) {
          final (int systeme, double x) = l.positionOfTick(t);
          if (systeme != precedentSysteme) {
            expect(systeme, precedentSysteme + 1, reason: 'un seul saut');
            expect(x, lessThan(precedentX), reason: 'on repart a gauche');
            aSaute = true;
            precedentSysteme = systeme;
          } else {
            expect(x, greaterThanOrEqualTo(precedentX));
          }
          precedentX = x;
        }
        expect(aSaute, isTrue);
      });

      test('avant le debut et apres la fin, le curseur reste visible', () {
        expect(l.positionOfTick(-1000).$1, 0);
        expect(l.positionOfTick(p.notes.last.offsetTicks + 1000).$1,
            l.systemCount - 1);
      });
    });

    group('SystemMetrics', () {
      test('tous les systemes ont la meme hauteur', () {
        // Des portees de hauteurs differentes feraient sauter le regard.
        final ScoreLayout l = ScoreLayout.of(passageDe(4), maxWidthSpaces: 45);
        final SystemMetrics m = SystemMetrics.of(l);
        expect(m.heightSpaces, greaterThan(0));
        final double ecart = m.originOfSystem(1) - m.originOfSystem(0);
        expect(ecart, m.heightSpaces + SystemMetrics.gapSpaces);
      });

      test('la pile grandit d un systeme et d un blanc a la fois', () {
        final ScoreLayout l = ScoreLayout.of(passageDe(4), maxWidthSpaces: 45);
        final SystemMetrics m = SystemMetrics.of(l);
        expect(m.stackHeightSpaces(1), m.heightSpaces);
        expect(
          m.stackHeightSpaces(3) - m.stackHeightSpaces(2),
          m.heightSpaces + SystemMetrics.gapSpaces,
        );
      });
    });
  });

  group('justification', () {
    test('sans justification, la ligne s arrete a sa largeur naturelle', () {
      // C'est le defaut d'origine : une ligne de trente-six espaces dans une
      // place de soixante laissait quarante pour cent de blanc a droite.
      final Passage p = passageDe(4);
      final double uneMesure = surUneLigne(passageDe(1));
      final ScoreLayout l = ScoreLayout.of(p, maxWidthSpaces: uneMesure * 2.6);

      expect(l.systemCount, greaterThan(1));
      expect(l.widthSpaces, lessThan(uneMesure * 2.6));
    });

    test('justifie, chaque systeme assez plein remplit la largeur', () {
      // Cinq mesures dans une place de deux mesures et demie : trois mesures
      // sur la premiere ligne, deux sur la seconde. Les deux sont assez
      // pleines, donc les deux s'etirent.
      final Passage p = passageDe(5);
      final double dispo = surUneLigne(passageDe(1)) * 2.6;
      final ScoreLayout l = ScoreLayout.of(
        p,
        maxWidthSpaces: dispo,
        justify: true,
      );

      expect(l.systemCount, 2);
      for (final StaffSystem s in l.systems) {
        expect(s.widthSpaces, closeTo(dispo, 0.01));
      }
    });

    test('justifier ne change ni le decoupage ni l ordre des notes', () {
      // La justification est une affaire d'espacement. Si elle deplacait une
      // mesure d'une ligne a l'autre, elle changerait la lecture.
      final Passage p = passageDe(6);
      final double dispo = surUneLigne(passageDe(1)) * 2.6;
      final ScoreLayout brut = ScoreLayout.of(p, maxWidthSpaces: dispo);
      final ScoreLayout tire = ScoreLayout.of(
        p,
        maxWidthSpaces: dispo,
        justify: true,
      );

      expect(tire.systemCount, brut.systemCount);
      for (int i = 0; i < brut.systemCount; i++) {
        expect(
          tire.systems[i].notes.map((PlacedNote n) => n.note.midi),
          brut.systems[i].notes.map((PlacedNote n) => n.note.midi),
        );
      }
    });

    test('les notes restent dans l ordre et dans le cadre', () {
      final Passage p = passageDe(4);
      final double dispo = surUneLigne(passageDe(1)) * 2.6;
      final ScoreLayout l = ScoreLayout.of(
        p,
        maxWidthSpaces: dispo,
        justify: true,
      );

      for (final StaffSystem s in l.systems) {
        double precedent = -1;
        for (final PlacedNote n in s.notes) {
          expect(n.xSpaces, greaterThan(precedent));
          expect(n.xSpaces, lessThan(s.widthSpaces));
          precedent = n.xSpaces;
        }
      }
    });

    test('un reste de fin garde son espacement naturel', () {
      // Regle de gravure : une derniere ligne a peine remplie n'est pas
      // etiree. Etaler une mesure isolee sur toute la largeur ferait croire a
      // une mesure longue, parce que l'oeil lit la duree dans l'espace.
      //
      // Quatre mesures dans une place de deux et demie : trois puis une.
      final Passage p = passageDe(4);
      final double dispo = surUneLigne(passageDe(1)) * 2.6;
      final ScoreLayout l = ScoreLayout.of(
        p,
        maxWidthSpaces: dispo,
        justify: true,
      );

      expect(l.systems.first.widthSpaces, closeTo(dispo, 0.01));
      expect(
        l.systems.last.widthSpaces,
        closeTo(surUneLigne(passageDe(1)), 0.01),
        reason: 'la mesure isolee garde sa largeur naturelle',
      );
    });

    test('le curseur suit l espacement etire', () {
      // xForTick et les notes doivent rester d'accord : sinon le curseur
      // prendrait du retard sur une ligne justifiee.
      final Passage p = passageDe(4);
      final double dispo = surUneLigne(passageDe(1)) * 2.6;
      final ScoreLayout l = ScoreLayout.of(
        p,
        maxWidthSpaces: dispo,
        justify: true,
      );

      for (final StaffSystem s in l.systems) {
        for (final PlacedNote n in s.notes) {
          expect(s.xForTick(n.note.onsetTicks), closeTo(n.xSpaces, 0.001));
        }
      }
    });

    test('une ligne trop longue n est jamais tassee', () {
      // Le plafond de systemes laisse deborder le dernier : il doit defiler,
      // pas se comprimer jusqu'a l'illisible.
      final Passage p = passageDe(4);
      final double etroit = surUneLigne(passageDe(1)) * 1.2;
      final ScoreLayout l = ScoreLayout.of(
        p,
        maxWidthSpaces: etroit,
        maxSystems: 1,
        justify: true,
      );

      expect(l.systemCount, 1);
      expect(l.widthSpaces, greaterThan(etroit));
    });
  });
}
