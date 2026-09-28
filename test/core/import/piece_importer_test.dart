import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/import/imported_piece.dart';
import 'package:violon/core/import/musicxml_reader.dart';
import 'package:violon/core/import/piece_importer.dart';

const String xml = '<?xml version="1.0"?><score-partwise>'
    '<work><work-title>Gavotte</work-title></work>'
    '<part id="P1"><measure number="1"><attributes><divisions>1</divisions>'
    '</attributes><note><pitch><step>A</step><octave>4</octave></pitch>'
    '<duration>4</duration></note></measure></part></score-partwise>';

/// Une archive zip minimale, fichier par fichier, comme MuseScore l'ecrit.
Uint8List zip(Map<String, String> fichiers, {bool compresser = true}) {
  final BytesBuilder corps = BytesBuilder();
  final BytesBuilder repertoire = BytesBuilder();
  int nombre = 0;
  for (final MapEntry<String, String> f in fichiers.entries) {
    final List<int> nom = utf8.encode(f.key);
    final List<int> clair = utf8.encode(f.value);
    final List<int> donnees =
        compresser ? ZLibEncoder(raw: true).convert(clair) : clair;
    final int local = corps.length;
    final ByteData en = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(8, compresser ? 8 : 0, Endian.little)
      ..setUint32(18, donnees.length, Endian.little)
      ..setUint32(22, clair.length, Endian.little)
      ..setUint16(26, nom.length, Endian.little);
    corps
      ..add(en.buffer.asUint8List())
      ..add(nom)
      ..add(donnees);
    final ByteData central = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(10, compresser ? 8 : 0, Endian.little)
      ..setUint32(20, donnees.length, Endian.little)
      ..setUint32(24, clair.length, Endian.little)
      ..setUint16(28, nom.length, Endian.little)
      ..setUint32(42, local, Endian.little);
    repertoire
      ..add(central.buffer.asUint8List())
      ..add(nom);
    nombre++;
  }
  final int debutRepertoire = corps.length;
  final int tailleRepertoire = repertoire.length;
  final ByteData fin = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, nombre, Endian.little)
    ..setUint16(10, nombre, Endian.little)
    ..setUint32(12, tailleRepertoire, Endian.little)
    ..setUint32(16, debutRepertoire, Endian.little);
  return (BytesBuilder()
        ..add(corps.takeBytes())
        ..add(repertoire.takeBytes())
        ..add(fin.buffer.asUint8List()))
      .takeBytes();
}

void main() {
  const PieceImporter importer = PieceImporter(inflate: _inflate);

  PickedDocument doc(List<int> octets, [String nom = 'x']) =>
      PickedDocument(name: nom, bytes: Uint8List.fromList(octets));

  group('PieceImporter', () {
    test('lit un MusicXML en clair', () {
      final ImportedPiece p = importer.read(doc(utf8.encode(xml)));
      expect(p.title, 'Gavotte');
      expect(p.passage.notes.single.midi, 69);
    });

    test('lit un MusicXML en UTF-16', () {
      final List<int> utf16 = <int>[0xFF, 0xFE];
      for (final int u in xml.codeUnits) {
        utf16
          ..add(u & 0xff)
          ..add(u >> 8);
      }
      expect(importer.read(doc(utf16)).title, 'Gavotte');
    });

    test('lit un .mxl par son conteneur, quel que soit le nom', () {
      final Uint8List mxl = zip(<String, String>{
        'META-INF/container.xml': '<container><rootfiles>'
            '<rootfile full-path="score/gavotte.xml"/></rootfiles></container>',
        'autre.xml': '<pas-une-partition/>',
        'score/gavotte.xml': xml,
      });
      expect(importer.read(doc(mxl, 'renomme.bin')).title, 'Gavotte');
    });

    test('lit un .mxl sans conteneur, et une entree non compressee', () {
      final Uint8List mxl =
          zip(<String, String>{'gavotte.musicxml': xml}, compresser: false);
      expect(importer.read(doc(mxl)).title, 'Gavotte');
    });

    test('une archive sans partition ou abimee le dit', () {
      expect(
        () => importer.read(doc(zip(<String, String>{'image.png': 'x'}))),
        throwsA(isA<ImportException>()),
      );
      final Uint8List coupee = zip(<String, String>{'g.xml': xml});
      expect(
        () => importer.read(doc(coupee.sublist(0, coupee.length - 30))),
        throwsA(isA<ImportException>()),
      );
    });

    test('un fichier demesure est refuse avant d etre lu', () {
      expect(
        () => importer.read(doc(Uint8List(PieceImporter.maxBytes + 1))),
        throwsA(isA<ImportException>()),
      );
    });
  });
}

List<int> _inflate(List<int> c) => ZLibDecoder(raw: true).convert(c);
