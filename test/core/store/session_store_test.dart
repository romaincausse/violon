import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/exercise_progress.dart';
import 'package:violon/core/store/session_store.dart';

void main() {
  const ExerciseBest unRecord = ExerciseBest(
    exerciseId: 'gamme-sol-majeur-2',
    meilleurScore: 94,
    meilleurTempoPropre: 80,
    essais: 3,
  );

  group('RememberedSession', () {
    test('un aller-retour ne perd rien', () {
      const RememberedSession avant = RememberedSession(
        a4: 442,
        exerciseId: 'gamme-sol-majeur-2',
        tempoBpm: 76,
        bests: <ExerciseBest>[unRecord],
      );
      final RememberedSession apres = RememberedSession.decode(avant.encode());

      expect(apres.a4, 442);
      expect(apres.exerciseId, 'gamme-sol-majeur-2');
      expect(apres.tempoBpm, 76);
      expect(apres.bests.single.meilleurScore, 94);
      expect(apres.bests.single.meilleurTempoPropre, 80);
      expect(apres.bests.single.essais, 3);
    });

    test('une seance vide se relit comme vide', () {
      expect(RememberedSession.decode(null).isEmpty, isTrue);
      expect(RememberedSession.decode('').isEmpty, isTrue);
      expect(
        RememberedSession.decode(RememberedSession.vide.encode()).isEmpty,
        isTrue,
      );
    });

    test('un enregistrement abime ne fait pas echouer l ouverture', () {
      // Perdre une progression est desagreable ; ne plus pouvoir ouvrir
      // l'application parce qu'une cle est mal formee serait pire.
      for (final String abime in <String>[
        'pas du json',
        '[]',
        '{',
        '{"records": "pas une liste"}',
        '{"a4": "quatre cent quarante"}',
      ]) {
        expect(RememberedSession.decode(abime).isEmpty, isTrue, reason: abime);
      }
    });

    test('un record incomplet est ignore, les autres survivent', () {
      const String source = '{"version":1,"records":['
          '{"id":"gamme-sol-majeur-2","score":94,"tempo":80,"essais":3},'
          '{"id":"casse"},'
          '{"score":50,"tempo":40,"essais":1}'
          ']}';
      final RememberedSession lue = RememberedSession.decode(source);
      expect(lue.bests, hasLength(1));
      expect(lue.bests.single.exerciseId, 'gamme-sol-majeur-2');
    });

    test('un diapason aberrant est refuse', () {
      // Une valeur folle relue en silence rendrait toute la justesse fausse,
      // et l'enfant serait declare faux partout sans qu'on sache pourquoi.
      expect(RememberedSession.decode('{"a4": 12}').a4, isNull);
      expect(RememberedSession.decode('{"a4": 20000}').a4, isNull);
      expect(RememberedSession.decode('{"a4": 442}').a4, 442);
      expect(RememberedSession.decode('{"a4": 415}').a4, 415);
    });

    test('un score hors bornes est refuse', () {
      const String source =
          '{"records":[{"id":"x","score":500,"tempo":80,"essais":1}]}';
      expect(RememberedSession.decode(source).bests, isEmpty);
    });
  });

  group('FakeSessionStore', () {
    test('ce qui est range est ce qui est relu', () async {
      final FakeSessionStore magasin = FakeSessionStore();
      expect((await magasin.load()).isEmpty, isTrue);

      await magasin.save(
        const RememberedSession(a4: 441.5, bests: <ExerciseBest>[unRecord]),
      );
      final RememberedSession relue = await magasin.load();
      expect(relue.a4, 441.5);
      expect(relue.bests.single.exerciseId, unRecord.exerciseId);
      expect(magasin.saves, 1);
    });

    test('oublier remet tout a zero', () async {
      final FakeSessionStore magasin =
          FakeSessionStore(const RememberedSession(a4: 442));
      await magasin.clear();
      expect((await magasin.load()).isEmpty, isTrue);
    });
  });
}
