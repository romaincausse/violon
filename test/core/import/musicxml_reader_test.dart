import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/import/imported_piece.dart';
import 'package:violon/core/import/musicxml_reader.dart';
import 'package:violon/core/music/meter.dart';
import 'package:violon/core/music/passage.dart';
import 'package:violon/core/music/score_note.dart';
import 'package:violon/core/play/accompaniment.dart';

import 'musicxml_fixtures.dart';

void main() {
  group('MusicXmlReader', () {
    test('lit hauteurs, durees, mesures, chiffrage et armure', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="1">$sixHuit'
          '${note('D4', 2)}${note('D4', 1)}${note('F#4', 1)}'
          '${note('A4', 1)}${note('B4', 1)}</measure>'
          '<measure number="2">${note('C#5', 6)}</measure>',
        ),
      );
      final Passage passage = p.passage;
      expect(p.title, 'Essai');
      expect(passage.meter, const Meter(6, 8));
      expect(passage.keyFifths, 2);
      expect(passage.ticksPerBeat, 480);
      expect(
        passage.notes.map((ScoreNote n) => n.midi),
        <int>[62, 62, 66, 69, 71, 73],
      );
      expect(
        passage.notes.map((ScoreNote n) => n.onsetTicks),
        <int>[0, 480, 720, 960, 1200, 1440],
      );
      expect(passage.notes.last.durationTicks, 1440);
      expect(passage.notes.last.measure, 2);
      expect(passage.notes.map((ScoreNote n) => n.id).first, 'n1');
      expect(passage.bars, const <Bar>[
        Bar(number: 1, startTicks: 0, durationTicks: 1440),
        Bar(number: 2, startTicks: 1440, durationTicks: 1440),
      ]);
      expect(p.warnings, isEmpty);
    });

    test('un silence laisse sa place, une mesure de silence existe', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="1">$sixHuit${note('B4', 3)}${silence(3)}</measure>'
          '<measure number="2">'
          '<note><rest measure="yes"/><duration>6</duration></note></measure>'
          '<measure number="3">${note('A4', 6)}</measure>',
        ),
      );
      expect(
          p.passage.notes.map((ScoreNote n) => n.onsetTicks), <int>[0, 2880]);
      expect(p.passage.bars!.map((Bar b) => b.number), <int>[1, 2, 3]);
      expect(p.passage.bars![1].durationTicks, 1440);
    });

    test('une tenue ne fait qu une note, meme par-dessus la barre', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="21">$sixHuit'
          '${note('A4', 6, notations: '<tied type="start"/>', extra: '<tie type="start"/>')}'
          '</measure>'
          '<measure number="22">'
          '${note('A4', 6, extra: '<tie type="stop"/>')}</measure>',
        ),
      );
      expect(p.passage.notes, hasLength(1));
      expect(p.passage.notes.single.durationTicks, 2880);
      expect(p.passage.notes.single.measure, 21);
    });

    test('une liaison met les notes suivantes dans le meme archet', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="1">$sixHuit'
          '${note('D4', 3)}'
          '${note('E4', 1, notations: '<slur type="start" number="1"/>')}'
          '${note('F#4', 1)}'
          '${note('G4', 1, notations: '<slur type="stop" number="1"/>')}'
          '</measure>',
        ),
      );
      expect(p.slurredInto, <String>{'n3', 'n4'});
    });

    test('une double corde garde la note aigue, et le dit', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="4">$sixHuit${note('D4', 6)}'
          '${note('B4', 6, extra: '<chord/>')}</measure>',
        ),
      );
      expect(p.passage.notes.single.midi, 71);
      expect(p.passage.notes.single.durationTicks, 1440);
      expect(p.warnings.single, contains('Doubles cordes'));
      expect(p.warnings.single, contains('mesure 4'));
    });

    test('une seconde voix et une petite note sont ignorees, et dites', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="1">$sixHuit'
          '<note><grace/><pitch><step>C</step><octave>5</octave></pitch>'
          '<voice>1</voice></note>'
          '${note('B4', 6)}'
          '<backup><duration>6</duration></backup>'
          '<note><pitch><step>G</step><octave>3</octave></pitch>'
          '<duration>6</duration><voice>2</voice></note>'
          '</measure>',
        ),
      );
      expect(p.passage.notes.single.midi, 71);
      expect(p.passage.bars!.single.durationTicks, 1440);
      expect(p.warnings, hasLength(2));
      expect(p.warnings.join(), contains('Seconde voix'));
      expect(p.warnings.join(), contains('Petites notes'));
    });

    test('plusieurs parties : seule la premiere, et on le dit', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="1">$sixHuit${note('A4', 6)}</measure>',
          parties: '<part id="P2"><measure number="1">$sixHuit'
              '${note('D3', 6)}</measure></part>',
        ),
      );
      expect(p.passage.notes.single.midi, 69);
      expect(p.warnings.single, contains('"Violon"'));
    });

    test('les autres parties deviennent l accompagnement, calees par mesure',
        () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="0" implicit="yes">$sixHuit${note('A4', 1)}'
          '</measure>'
          '<measure number="1">${note('D5', 6)}</measure>',
          parties: '<part id="P2">'
              '<measure number="0"><attributes><divisions>4</divisions>'
              '</attributes><note><rest/><duration>2</duration></note>'
              '</measure>'
              '<measure number="1">'
              '<note><pitch><step>D</step><octave>3</octave></pitch>'
              '<duration>6</duration><tie type="start"/></note>'
              '<note><chord/><pitch><step>F</step><alter>1</alter>'
              '<octave>3</octave></pitch><duration>6</duration></note>'
              '<note><pitch><step>D</step><octave>3</octave></pitch>'
              '<duration>6</duration><tie type="stop"/></note>'
              '</measure></part>',
        ),
      );
      // La levee dure une croche : le re du piano tombe sur le premier temps
      // de la mesure 1, a 240 ticks, et sa tenue ne fait qu'une note.
      expect(
        p.accompaniment.map((AccompanimentNote n) =>
            '${n.midi} ${n.onsetTicks} ${n.durationTicks}'),
        <String>['50 240 1440', '54 240 720'],
      );
      expect(p.passage.notes.map((ScoreNote n) => n.midi), <int>[69, 74]);
      final ImportedPiece relu = ImportedPiece.fromJson(p.toJson())!;
      expect(relu.accompaniment, hasLength(2));
      expect(relu.accompanimentFor(p.excerpt(1, 1)!), hasLength(2));
    });

    test('le tempo du metronome se ramene a la noire', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="1">$sixHuit'
          '<direction><direction-type><metronome>'
          '<beat-unit>quarter</beat-unit><beat-unit-dot/>'
          '<per-minute>94</per-minute></metronome></direction-type>'
          '</direction>${note('A4', 6)}</measure>',
        ),
      );
      expect(p.passage.writtenTempoBpm, 141);
    });

    test('le tempo du son l emporte, il est deja a la noire', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="1">$sixHuit'
          '<direction><direction-type><metronome><beat-unit>quarter'
          '</beat-unit><per-minute>60</per-minute></metronome>'
          '</direction-type><sound tempo="72.4"/></direction>'
          '${note('A4', 6)}</measure>',
        ),
      );
      expect(p.passage.writtenTempoBpm, 72);
    });

    test('une levee garde son numero, les numeros non entiers se suivent', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="0" implicit="yes">$sixHuit${note('A4', 1)}'
          '</measure>'
          '<measure number="1">${note('D5', 6)}</measure>'
          '<measure number="X1">${note('C#5', 6)}</measure>',
        ),
      );
      expect(p.passage.bars!.map((Bar b) => b.number), <int>[0, 1, 2]);
      expect(p.passage.bars!.first.durationTicks, 240);
      expect(p.passage.notes.map((ScoreNote n) => n.measure), <int>[0, 1, 2]);
    });

    test('un titre peut venir du mouvement ou des credits', () {
      expect(
        MusicXmlReader.read(
          partition(
            '<measure number="1">$sixHuit${note('A4', 6)}</measure>',
            entete: '<movement-title>Gavotte</movement-title>'
                '<identification><creator type="composer">Gossec'
                '</creator></identification>',
          ),
        ).composer,
        'Gossec',
      );
      expect(
        MusicXmlReader.read(
          partition(
            '<measure number="1">$sixHuit${note('A4', 6)}</measure>',
            entete: '<credit page="1"><credit-type>title</credit-type>'
                '<credit-words>Menuet</credit-words></credit>',
          ),
        ).title,
        'Menuet',
      );
    });

    test('l identifiant est stable et depend du contenu', () {
      String avec(String h) => MusicXmlReader.read(
            partition('<measure number="1">$sixHuit${note(h, 6)}</measure>'),
          ).id;
      expect(avec('A4'), avec('A4'));
      expect(avec('A4'), isNot(avec('B4')));
      expect(avec('A4'), startsWith('essai-'));
    });

    test('refuse ce qui n est pas une partition lisible', () {
      expect(
        () => MusicXmlReader.read('<html></html>'),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => MusicXmlReader.read('<score-timewise/>'),
        throwsA(
          isA<ImportException>().having(
            (ImportException e) => e.message,
            'message',
            contains('timewise'),
          ),
        ),
      );
      expect(
        () => MusicXmlReader.read('pas du tout du xml'),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => MusicXmlReader.read(
          partition('<measure number="1">$sixHuit${silence(6)}</measure>'),
        ),
        throwsA(isA<ImportException>()),
      );
    });
  });

  group('ImportedPiece', () {
    ImportedPiece piece() => MusicXmlReader.read(
          partition(
            '<measure number="1">$sixHuit${note('D4', 6)}</measure>'
            '<measure number="2">${note('E4', 3)}${silence(3)}</measure>'
            '<measure number="3">${silence(6)}</measure>'
            '<measure number="4">${note('G4', 3)}'
            '${note('A4', 3, notations: '<slur type="start"/>')}</measure>'
            '<measure number="5">'
            '${note('B4', 6, notations: '<slur type="stop"/>')}</measure>',
          ),
        );

    test('un extrait garde chiffrage, armure et mesures de silence', () {
      final Passage e = piece().excerpt(2, 4)!;
      expect(e.title, 'Essai - mesures 2 a 4');
      expect(e.notes.map((ScoreNote n) => n.midi), <int>[64, 67, 69]);
      expect(e.meter, const Meter(6, 8));
      expect(e.keyFifths, 2);
      expect(e.bars!.map((Bar b) => b.number), <int>[2, 3, 4]);
    });

    test('un extrait garde la mesure ou deborde sa derniere tenue', () {
      final ImportedPiece p = MusicXmlReader.read(
        partition(
          '<measure number="1">$sixHuit'
          '${note('A4', 6, extra: '<tie type="start"/>')}</measure>'
          '<measure number="2">${note('A4', 6, extra: '<tie type="stop"/>')}'
          '</measure>'
          '<measure number="3">${note('B4', 6)}</measure>',
        ),
      );
      expect(p.excerpt(1, 1)!.bars!.map((Bar b) => b.number), <int>[1, 2]);
    });

    test('un extrait qui finit sur un silence garde sa mesure de silence', () {
      expect(
        piece().excerpt(1, 3)!.bars!.map((Bar b) => b.number),
        <int>[1, 2, 3],
      );
    });

    test('un extrait sans note n existe pas', () {
      expect(piece().excerpt(3, 3), isNull);
    });

    test('le morceau entier garde son titre', () {
      expect(piece().excerpt(1, 5)!.title, 'Essai');
    });

    test('survit a un aller-retour par JSON', () {
      final ImportedPiece p = piece();
      final ImportedPiece relu = ImportedPiece.fromJson(p.toJson())!;
      expect(relu.id, p.id);
      expect(relu.title, p.title);
      expect(relu.slurredInto, p.slurredInto);
      expect(relu.warnings, p.warnings);
      expect(relu.passage.meter, p.passage.meter);
      expect(relu.passage.keyFifths, p.passage.keyFifths);
      expect(relu.passage.bars, p.passage.bars);
      expect(relu.passage.writtenTempoBpm, p.passage.writtenTempoBpm);
      expect(
        relu.passage.notes.map((ScoreNote n) =>
            '${n.id} ${n.midi} ${n.onsetTicks} ${n.durationTicks} ${n.measure}'),
        p.passage.notes.map((ScoreNote n) =>
            '${n.id} ${n.midi} ${n.onsetTicks} ${n.durationTicks} ${n.measure}'),
      );
    });

    test('un morceau abime se relit comme rien, sans lever', () {
      expect(ImportedPiece.fromJson(null), isNull);
      expect(ImportedPiece.fromJson(<String, Object?>{'id': 'x'}), isNull);
      final Map<String, Object?> json = piece().toJson();
      (json['passage']! as Map<String, Object?>)['notes'] = <Object?>[
        <String, Object?>{'id': 'n1', 'midi': 'soixante'},
      ];
      expect(ImportedPiece.fromJson(json), isNull);
    });
  });
}
