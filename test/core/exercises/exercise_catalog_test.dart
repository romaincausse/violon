import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/exercises/method_source.dart';
import 'package:violon/core/music/note_value.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';

void main() {
  group('ExerciseCatalog', () {
    test('les identifiants sont uniques', () {
      final Set<String> ids =
          ExerciseCatalog.all.map((Exercise e) => e.id).toSet();
      expect(ids.length, ExerciseCatalog.all.length);
    });

    test('tous les paliers annonces ont des exercices', () {
      for (final Palier palier in ExerciseCatalog.paliers) {
        expect(ExerciseCatalog.ofPalier(palier.numero), isNotEmpty,
            reason: 'palier ${palier.numero}');
      }
    });

    test('le catalogue est trie par palier croissant', () {
      // L ordre du catalogue est le contrat : la prochaine tache et
      // l ouverture des paliers le lisent tel quel.
      for (int i = 1; i < ExerciseCatalog.all.length; i++) {
        expect(
          ExerciseCatalog.all[i].palier,
          greaterThanOrEqualTo(ExerciseCatalog.all[i - 1].palier),
        );
      }
    });

    test('chaque exercice annonce un palier qui existe', () {
      final Set<int> numeros =
          ExerciseCatalog.paliers.map((Palier p) => p.numero).toSet();
      for (final Exercise exercise in ExerciseCatalog.all) {
        expect(numeros, contains(exercise.palier), reason: exercise.id);
      }
    });

    test('chaque exercice cite une methode du catalogue', () {
      for (final Exercise exercise in ExerciseCatalog.all) {
        expect(MethodSource.all, contains(exercise.source),
            reason: exercise.id);
      }
    });

    test('tout tient dans la main d un violoniste de quatrieme annee', () {
      for (final Exercise exercise in ExerciseCatalog.all) {
        expect(exercise.lowestMidi,
            greaterThanOrEqualTo(ExerciseCatalog.plusGraveJouable),
            reason: '${exercise.id} descend sous la corde de sol');
        expect(exercise.highestMidi,
            lessThanOrEqualTo(ExerciseCatalog.plusAiguEnPremierePosition),
            reason: '${exercise.id} demande de demancher');
      }
    });

    test('aucun exercice ne repete deux fois la meme hauteur a la suite', () {
      // YIN ne voit pas une note rejouee a la meme hauteur, et le detecteur
      // d attaques n est pas encore eprouve : un unisson consecutif serait
      // compte comme une note manquee alors que l enfant l a bien jouee.
      for (final Exercise exercise in ExerciseCatalog.all) {
        final List<int> notes = exercise.midis;
        for (int i = 1; i < notes.length; i++) {
          expect(notes[i], isNot(notes[i - 1]),
              reason: '${exercise.id}, note $i');
        }
      }
    });

    test('les tempos vises restent jouables', () {
      for (final Exercise exercise in ExerciseCatalog.all) {
        expect(exercise.tempoVise, inInclusiveRange(40, 120),
            reason: exercise.id);
      }
    });

    test('chaque exercice se grave en figures reelles', () {
      // Le graveur deduit la tete de note de la duree : une duree qui n est
      // aucune figure se dessinerait quand meme, en affichant n importe quoi.
      for (final Exercise exercise in ExerciseCatalog.all) {
        final Passage passage = exercise.toPassage();
        expect(passage.notes.length, exercise.noteCount, reason: exercise.id);
        for (final ScoreNote note in passage.notes) {
          expect(
            NoteValue.exactly(note.durationTicks, passage.ticksPerBeat),
            isNotNull,
            reason: '${exercise.id} : ${note.durationTicks} ticks',
          );
        }
      }
    });

    test('chaque exercice remplit ses mesures jusqu au bout', () {
      for (final Exercise exercise in ExerciseCatalog.all) {
        final Passage passage = exercise.toPassage();
        final int total = passage.notes.last.offsetTicks;
        expect(total % (passage.ticksPerBeat * 4), 0,
            reason: '${exercise.id} laisse une mesure incomplete');
      }
    });

    test('le tempo de travail remplace le tempo vise sans rien changer', () {
      final Exercise exercise = ExerciseCatalog.all.first;
      final Passage lent = exercise.toPassage(tempoBpm: 50);
      final Passage vise = exercise.toPassage();
      expect(lent.writtenTempoBpm, 50);
      expect(vise.writtenTempoBpm, exercise.tempoVise);
      expect(
        lent.notes.map((ScoreNote n) => n.midi),
        vise.notes.map((ScoreNote n) => n.midi),
      );
    });

    test('byId retrouve un exercice, et rend null sinon', () {
      expect(ExerciseCatalog.byId('gamme-sol-majeur-2')?.palier, 4);
      expect(ExerciseCatalog.byId('gamme-de-mars'), isNull);
    });

    test('le catalogue couvre les motifs, les gammes et les arpeges', () {
      final Set<ExerciseKind> genres =
          ExerciseCatalog.all.map((Exercise e) => e.genre).toSet();
      expect(genres, ExerciseKind.values.toSet());
    });
  });

  group('gravePar', () {
    test('la derniere note complete la mesure', () {
      // Quinze notes : quatorze croches font sept temps, la derniere note
      // vaut donc une noire pour fermer la deuxieme mesure.
      final Passage passage = gravePar(
        List<int>.generate(15, (int i) => 60 + i % 7),
        titre: 'test',
        tempoBpm: 80,
      );
      expect(passage.notes.last.durationTicks, 480);
      expect(passage.measureCount, 2);
    });

    test('une suite qui tombe pile recoit une mesure entiere', () {
      // Neuf notes : huit croches font une mesure pleine, la derniere en
      // ouvre donc une seconde et l occupe toute seule.
      final Passage passage = gravePar(
        List<int>.generate(9, (int i) => 60 + i),
        titre: 'test',
        tempoBpm: 80,
      );
      expect(passage.notes.last.durationTicks, 1920);
      expect(passage.measureCount, 2);
    });

    test('refuse une liste vide', () {
      expect(() => gravePar(<int>[], titre: 'rien', tempoBpm: 80),
          throwsArgumentError);
    });
  });
}
