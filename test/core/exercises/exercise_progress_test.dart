import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/exercise.dart';
import 'package:violon/core/exercises/exercise_catalog.dart';
import 'package:violon/core/exercises/exercise_progress.dart';

/// Les exercices du premier palier, ceux qu'on ouvre en premier.
List<Exercise> get _palier1 => ExerciseCatalog.ofPalier(1);

/// Rend un palier entierement acquis.
void _acquerir(ExerciseProgress progres, int palier) {
  for (final Exercise exercise in ExerciseCatalog.ofPalier(palier)) {
    progres.record(ExerciseAttempt(
      exerciseId: exercise.id,
      score: 95,
      tempoBpm: exercise.tempoVise,
    ));
  }
}

void main() {
  group('ExerciseProgress', () {
    test('rien joue : le premier palier est ouvert, pas le deuxieme', () {
      final ExerciseProgress progres = ExerciseProgress();
      expect(progres.palierOuvert, 1);
      expect(progres.palierEstOuvert(1), isTrue);
      expect(progres.palierEstOuvert(2), isFalse);
      expect(progres.acquis, 0);
    });

    test('la premiere tache est le premier exercice du catalogue', () {
      final ExerciseProgress progres = ExerciseProgress();
      expect(progres.prochaineTache?.id, ExerciseCatalog.all.first.id);
    });

    test('un exercice propre au tempo vise devient acquis', () {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 92,
        tempoBpm: exercise.tempoVise,
      ));
      expect(progres.estAcquis(exercise), isTrue);
      expect(progres.prochaineTache?.id, _palier1[1].id);
    });

    test('propre mais trop lent ne suffit pas', () {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 100,
        tempoBpm: exercise.tempoVise - 10,
      ));
      expect(progres.estAcquis(exercise), isFalse);
      expect(progres.bestFor(exercise.id)?.meilleurScore, 100);
      expect(
        progres.bestFor(exercise.id)?.meilleurTempoPropre,
        exercise.tempoVise - 10,
      );
    });

    test('rapide mais pas propre ne suffit pas non plus', () {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 60,
        tempoBpm: exercise.tempoVise + 20,
      ));
      expect(progres.estAcquis(exercise), isFalse);
      expect(progres.bestFor(exercise.id)?.meilleurTempoPropre, 0);
    });

    test('un score et un tempo venus de deux prises ne se combinent pas', () {
      // Le piege : 100 obtenu lentement et le bon tempo obtenu salement
      // s additionneraient en un exercice declare acquis, alors qu il n a
      // jamais ete joue proprement au tempo.
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 100,
        tempoBpm: 40,
      ));
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 55,
        tempoBpm: exercise.tempoVise,
      ));
      expect(progres.estAcquis(exercise), isFalse);
      expect(progres.bestFor(exercise.id)?.meilleurScore, 100);
      expect(progres.bestFor(exercise.id)?.meilleurTempoPropre, 40);
    });

    test('une mauvaise prise n efface jamais une bonne', () {
      // La regle produit la plus ancienne du projet : une erreur ne remet
      // pas un compteur a zero.
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 97,
        tempoBpm: exercise.tempoVise,
      ));
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 12,
        tempoBpm: exercise.tempoVise,
      ));
      expect(progres.estAcquis(exercise), isTrue);
      expect(progres.bestFor(exercise.id)?.meilleurScore, 97);
      expect(progres.bestFor(exercise.id)?.essais, 2);
      expect(progres.essais, 2);
    });

    test('un palier entierement acquis ouvre le suivant', () {
      final ExerciseProgress progres = ExerciseProgress();
      _acquerir(progres, 1);
      expect(progres.palierOuvert, 2);
      expect(progres.prochaineTache?.palier, 2);
    });

    test('il suffit d un exercice manquant pour garder le palier ferme', () {
      final ExerciseProgress progres = ExerciseProgress();
      for (final Exercise exercise in _palier1.skip(1)) {
        progres.record(ExerciseAttempt(
          exerciseId: exercise.id,
          score: 95,
          tempoBpm: exercise.tempoVise,
        ));
      }
      expect(progres.palierOuvert, 1);
      expect(progres.resteAuPalier(1), 1);
      expect(progres.prochaineTache?.id, _palier1.first.id);
    });

    test('la prochaine tache ne saute jamais au-dela du palier ouvert', () {
      final ExerciseProgress progres = ExerciseProgress();
      // Le professeur a fait travailler tout le palier 3 par-dessus la tete
      // de l application : il en a le droit, la progression ne verrouille
      // rien. Mais la prochaine tache proposee reste celle du palier 1.
      _acquerir(progres, 3);
      expect(progres.palierOuvert, 1);
      expect(progres.prochaineTache?.palier, 1);
    });

    test('tout acquis : plus de tache a proposer', () {
      final ExerciseProgress progres = ExerciseProgress();
      for (final Palier palier in ExerciseCatalog.paliers) {
        _acquerir(progres, palier.numero);
      }
      expect(progres.prochaineTache, isNull);
      expect(progres.acquis, ExerciseCatalog.all.length);
      expect(progres.palierOuvert, ExerciseCatalog.palierCount + 1);
    });

    test('un passage a peine entendu ne rend rien acquis', () {
      // Quatre notes justes sur vingt-neuf donnent cent : le score ne compte
      // que ce qui a ete entendu. Sans garde de couverture, l exercice serait
      // declare acquis et ne reviendrait jamais.
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 100,
        tempoBpm: exercise.tempoVise,
        coverage: 0.15,
      ));
      expect(progres.estAcquis(exercise), isFalse);
      expect(progres.bestFor(exercise.id)?.essais, 1);
      expect(progres.bestFor(exercise.id)?.meilleurScore, 100);
      expect(progres.bestFor(exercise.id)?.meilleurTempoPropre, 0);
    });

    test('une note avalee n empeche pas l acquisition', () {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 95,
        tempoBpm: exercise.tempoVise,
        coverage: 0.9,
      ));
      expect(progres.estAcquis(exercise), isTrue);
    });

    test('le tempo propose reste le tempo vise tant que rien n est acquis', () {
      // L'objectif ne bouge pas parce qu'on a rate.
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      expect(progres.tempoPropose(exercise), exercise.tempoVise);

      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 40,
        tempoBpm: exercise.tempoVise,
      ));
      expect(progres.tempoPropose(exercise), exercise.tempoVise);
    });

    test('une fois acquis, on propose le cran au-dessus', () {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 95,
        tempoBpm: exercise.tempoVise,
      ));
      expect(
        progres.tempoPropose(exercise),
        exercise.tempoVise + ExerciseProgress.pasDeTempo,
      );
    });

    test('le cran monte a partir du meilleur tempo tenu, pas du vise', () {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      for (final int tempo in <int>[
        exercise.tempoVise,
        exercise.tempoVise + 12
      ]) {
        progres.record(ExerciseAttempt(
          exerciseId: exercise.id,
          score: 95,
          tempoBpm: tempo,
        ));
      }
      expect(
        progres.tempoPropose(exercise),
        exercise.tempoVise + 12 + ExerciseProgress.pasDeTempo,
      );
    });

    test('la progression se range et se relit', () {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 95,
        tempoBpm: exercise.tempoVise,
      ));

      final ExerciseProgress relue = ExerciseProgress()
        ..restore(progres.bests.values);
      expect(relue.estAcquis(exercise), isTrue);
      expect(relue.acquis, 1);
      expect(relue.bestFor(exercise.id)?.essais, 1);
      expect(relue.prochaineTache?.id, _palier1[1].id);
    });

    test('un record d un exercice disparu du catalogue est ignore', () {
      // Le catalogue peut changer entre deux versions ; la memoire ne doit pas
      // ressusciter un exercice qui n'existe plus.
      final ExerciseProgress progres = ExerciseProgress()
        ..restore(<ExerciseBest>[
          const ExerciseBest(
            exerciseId: 'gamme-de-mars',
            meilleurScore: 100,
            meilleurTempoPropre: 200,
            essais: 9,
          ),
        ]);
      expect(progres.bests, isEmpty);
      expect(progres.acquis, 0);
    });

    test('relire remplace, ca ne s ajoute pas', () {
      final ExerciseProgress progres = ExerciseProgress();
      final Exercise exercise = _palier1.first;
      progres.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 95,
        tempoBpm: exercise.tempoVise,
      ));
      progres.restore(const <ExerciseBest>[]);
      expect(progres.bests, isEmpty);
      expect(progres.estAcquis(exercise), isFalse);
    });

    test('un seuil plus severe retarde l acquisition', () {
      final ExerciseProgress severe = ExerciseProgress(scorePropre: 99);
      final Exercise exercise = _palier1.first;
      severe.record(ExerciseAttempt(
        exerciseId: exercise.id,
        score: 95,
        tempoBpm: exercise.tempoVise,
      ));
      expect(severe.estAcquis(exercise), isFalse);
    });
  });
}
