import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/import/xml_reader.dart';

void main() {
  group('XmlReader', () {
    test('lit elements, attributs et texte', () {
      final XmlElement r = XmlReader.parse(
        '<a x="1" y=\'deux\'><b>texte</b><c/><b>autre</b></a>',
      );
      expect(r.name, 'a');
      expect(r.attributes, <String, String>{'x': '1', 'y': 'deux'});
      expect(r.childrenNamed('b').map((XmlElement e) => e.text),
          <String>['texte', 'autre']);
      expect(r.child('c'), isNotNull);
      expect(r.child('d'), isNull);
    });

    test('saute prologue, DOCTYPE, commentaires et BOM', () {
      final XmlElement r = XmlReader.parse(
        '﻿<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD" '
        '"http://www.musicxml.org/dtds/partwise.dtd" [ <!ENTITY x "y"> ]>\n'
        '<!-- un commentaire -->\n'
        '<score-partwise><!-- dedans --><work/></score-partwise>\n',
      );
      expect(r.name, 'score-partwise');
      expect(r.children.single.name, 'work');
    });

    test('decode les entites et le CDATA', () {
      final XmlElement r = XmlReader.parse(
        '<t a="&quot;x&quot;">Do &amp; R&#233; &#x2014; &lt;b&gt;'
        '<![CDATA[<brut>]]></t>',
      );
      expect(r.attributes['a'], '"x"');
      expect(r.text, 'Do & R\u00e9 \u2014 <b><brut>');
    });

    test('suit un chemin', () {
      final XmlElement r =
          XmlReader.parse('<n><pitch><step>G</step></pitch></n>');
      expect(r.path('pitch/step')?.text, 'G');
      expect(r.path('pitch/octave'), isNull);
    });

    test('refuse un document mal forme, avec la ligne', () {
      expect(
        () => XmlReader.parse('<a>\n<b></a>'),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('ligne 2'),
          ),
        ),
      );
      expect(() => XmlReader.parse('<a>'), throwsFormatException);
      expect(() => XmlReader.parse('pas du xml'), throwsFormatException);
      expect(() => XmlReader.parse('<a/><b/>'), throwsFormatException);
    });
  });
}
