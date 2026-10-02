import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/import/piece_importer.dart';
import '../../core/store/document_saver.dart';

/// Le selecteur de fichiers d'Android, par le Storage Access Framework.
///
/// **Aucune permission.** `ACTION_OPEN_DOCUMENT` laisse l'utilisateur choisir
/// un fichier et n'accorde a l'application que celui-la : elle ne lit pas le
/// stockage, ce que l'ADR-005 exclut. Drive, les telechargements et une cle
/// USB passent par le meme ecran.
///
/// **Aucun paquet non plus.** Un plugin de selection de fichiers aurait
/// ajoute une dependance pour une soixantaine de lignes de Kotlin : voir
/// `MainActivity.kt`, cote Android.
class AndroidDocumentPicker implements DocumentPicker {
  AndroidDocumentPicker({MethodChannel? channel})
      : _canal = channel ?? const MethodChannel(canal);

  static const String canal = 'violon/documents';

  final MethodChannel _canal;

  @override
  Future<PickedDocument?> pick() async {
    final Map<Object?, Object?>? rendu =
        await _canal.invokeMapMethod<Object?, Object?>('choisir');
    if (rendu == null) {
      return null;
    }
    final Object? nom = rendu['nom'];
    final Object? octets = rendu['octets'];
    if (octets is! Uint8List) {
      return null;
    }
    return PickedDocument(name: nom is String ? nom : '', bytes: octets);
  }
}

/// Ranger un fichier ou l'utilisateur le choisit, par le meme canal.
class AndroidDocumentSaver implements DocumentSaver {
  AndroidDocumentSaver({MethodChannel? channel})
      : _canal = channel ?? const MethodChannel(AndroidDocumentPicker.canal);

  final MethodChannel _canal;

  @override
  Future<bool> save(String name, Uint8List bytes) async =>
      await _canal.invokeMethod<bool>(
        'enregistrer',
        <String, Object?>{'nom': name, 'octets': bytes},
      ) ??
      false;
}

DocumentSaver defaultDocumentSaver() => AndroidDocumentSaver();

/// Le `deflate` brut d'une archive zip, par `dart:io`.
List<int> inflateRaw(List<int> compressed) =>
    ZLibDecoder(raw: true).convert(compressed);

/// Fabriques par defaut, injectees depuis `main`.
DocumentPicker defaultDocumentPicker() => AndroidDocumentPicker();

PieceImporter defaultPieceImporter() =>
    const PieceImporter(inflate: inflateRaw);
