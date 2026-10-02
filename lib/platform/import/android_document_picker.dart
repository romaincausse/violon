import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/import/piece_importer.dart';
import '../../core/play/headphones.dart';
import '../../core/store/document_saver.dart';
import '../../core/store/take_sharer.dart';

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
  Future<bool> save(
    String name,
    Uint8List bytes, {
    String mimeType = 'text/plain',
  }) async =>
      await _canal.invokeMethod<bool>(
        'enregistrer',
        <String, Object?>{'nom': name, 'octets': bytes, 'type': mimeType},
      ) ??
      false;
}

DocumentSaver defaultDocumentSaver() => AndroidDocumentSaver();

/// Envoyer une prise a quelqu'un, par le partage du systeme (ADR-018).
///
/// Android ne partage qu'un fichier : il est pose dans le cache prive de
/// l'application, derriere un `FileProvider`, et le Kotlin l'efface au
/// concert suivant et au lancement suivant. Aucune permission, aucun paquet.
class AndroidTakeSharer implements TakeSharer {
  AndroidTakeSharer({MethodChannel? channel})
      : _canal = channel ?? const MethodChannel(AndroidDocumentPicker.canal);

  final MethodChannel _canal;

  @override
  Future<bool> share(String name, Uint8List wav) async {
    try {
      return await _canal.invokeMethod<bool>(
            'partager',
            <String, Object?>{'nom': name, 'octets': wav, 'type': 'audio/wav'},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

TakeSharer defaultTakeSharer() => AndroidTakeSharer();

/// Ce qui est branche en sortie, par le meme canal.
class AndroidHeadphoneProbe implements HeadphoneProbe {
  AndroidHeadphoneProbe({MethodChannel? channel})
      : _canal = channel ?? const MethodChannel(AndroidDocumentPicker.canal);

  final MethodChannel _canal;

  @override
  Future<Headphones> check() async {
    try {
      return switch (await _canal.invokeMethod<String>('casque')) {
        'filaire' => Headphones.wired,
        'bluetooth' => Headphones.bluetooth,
        _ => Headphones.none,
      };
    } on PlatformException {
      return Headphones.none;
    } on MissingPluginException {
      return Headphones.none;
    }
  }
}

HeadphoneProbe defaultHeadphoneProbe() => AndroidHeadphoneProbe();

/// Le `deflate` brut d'une archive zip, par `dart:io`.
List<int> inflateRaw(List<int> compressed) =>
    ZLibDecoder(raw: true).convert(compressed);

/// Fabriques par defaut, injectees depuis `main`.
DocumentPicker defaultDocumentPicker() => AndroidDocumentPicker();

PieceImporter defaultPieceImporter() =>
    const PieceImporter(inflate: inflateRaw);
