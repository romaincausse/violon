import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/import/piece_importer.dart';
import 'package:violon/platform/import/android_document_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel canal = MethodChannel(AndroidDocumentPicker.canal);

  void repondre(Object? reponse) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (MethodCall appel) async {
      expect(appel.method, 'choisir');
      return reponse;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  test('rend le nom et les octets choisis', () async {
    repondre(<String, Object?>{
      'nom': 'gavotte.mxl',
      'octets': Uint8List.fromList(<int>[1, 2, 3]),
    });
    final PickedDocument? doc = await AndroidDocumentPicker().pick();
    expect(doc?.name, 'gavotte.mxl');
    expect(doc?.bytes, <int>[1, 2, 3]);
  });

  test('rend null quand on renonce', () async {
    repondre(null);
    expect(await AndroidDocumentPicker().pick(), isNull);
  });

  test('inflateRaw defait un deflate brut', () {
    final List<int> c = ZLibEncoder(raw: true).convert('partition'.codeUnits);
    expect(String.fromCharCodes(inflateRaw(c)), 'partition');
  });
}
