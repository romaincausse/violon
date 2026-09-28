import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/import/imported_piece.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/store/piece_store.dart';

ImportedPiece morceau(String id, {int midi = 69}) => ImportedPiece(
      id: id,
      title: 'Morceau $id',
      passage: Passage(
        title: 'Morceau $id',
        notes: <ScoreNote>[
          ScoreNote(
            id: 'n1',
            midi: midi,
            onsetTicks: 0,
            durationTicks: 480,
            measure: 1,
          ),
        ],
        ticksPerBeat: 480,
      ),
    );

void main() {
  group('PieceLibrary', () {
    test('le dernier importe passe en tete, un reimport remplace', () {
      final PieceLibrary l = PieceLibrary.vide
          .withPiece(morceau('a'))
          .withPiece(morceau('b'))
          .withPiece(morceau('a', midi: 71));
      expect(l.pieces.map((ImportedPiece p) => p.id), <String>['a', 'b']);
      expect(l.byId('a')!.passage.notes.single.midi, 71);
      expect(l.byId('z'), isNull);
      expect(l.without('a').pieces.single.id, 'b');
    });

    test('survit a l encodage, et un morceau abime n emporte pas les autres',
        () {
      final PieceLibrary l =
          PieceLibrary.vide.withPiece(morceau('a')).withPiece(morceau('b'));
      expect(
        PieceLibrary.decode(l.encode()).pieces.map((ImportedPiece p) => p.id),
        <String>['b', 'a'],
      );
      // Le premier range est "b" : c'est lui qu'on abime.
      final String abime = l.encode().replaceFirst('"midi":69', '"midi":"x"');
      expect(
        PieceLibrary.decode(abime).pieces.map((ImportedPiece p) => p.id),
        <String>['a'],
      );
      expect(PieceLibrary.decode('{').pieces, isEmpty);
      expect(PieceLibrary.decode(null).pieces, isEmpty);
    });

    test('le magasin factice passe par l encodage reel', () async {
      final FakePieceStore store = FakePieceStore();
      await store.save(PieceLibrary.vide.withPiece(morceau('a')));
      expect((await store.load()).pieces.single.id, 'a');
      expect(store.saves, 1);
    });
  });
}
