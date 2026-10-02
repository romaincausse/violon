import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'feature_extractor.dart';
import 'performance_features.dart';

/// Fait tourner un [FeatureExtractor] sur le flux du micro.
///
/// Asynchrone pour la meme raison que `PitchAnalyzer` : la version reelle
/// traverse un isolate. **Une seule regle pour les appelants** : les paquets
/// se soumettent dans l'ordre, sans en sauter un -- c'est un flux, et le
/// detecteur d'attaques compare chaque spectre au precedent.
abstract class FeatureAnalyzer {
  /// Les trames que ce paquet complete, dans l'ordre.
  Future<List<FeatureFrame>> add(
    Float32List samples, {
    bool analysePitch = true,
  });

  /// Oublie le flux precedent : le temps repart de zero.
  Future<void> reset();

  Future<void> dispose();
}

/// Sur l'isolate appelant : pour les tests, et pour developper sans micro.
class InlineFeatureAnalyzer implements FeatureAnalyzer {
  InlineFeatureAnalyzer({FeatureExtractor? extractor})
      : _extracteur = extractor ?? FeatureExtractor();

  final FeatureExtractor _extracteur;

  @override
  Future<List<FeatureFrame>> add(
    Float32List samples, {
    bool analysePitch = true,
  }) async =>
      _extracteur.addSamples(samples, analysePitch: analysePitch);

  @override
  Future<void> reset() async => _extracteur.reset();

  @override
  Future<void> dispose() async {}
}

/// L'extracteur dans son propre isolate.
///
/// Les paquets traversent dans l'ordre ou ils sont soumis, et l'isolate les
/// traite dans cet ordre : un port est une file. Les trames reviennent mises
/// a plat, cinq nombres chacune, dans un seul tableau transfere.
class IsolateFeatureAnalyzer implements FeatureAnalyzer {
  IsolateFeatureAnalyzer._(this._isolate, this._vers, this._reponses) {
    _abonnement = _reponses.listen(_onReponse);
  }

  static Future<IsolateFeatureAnalyzer> spawn({int sampleRate = 44100}) async {
    final ReceivePort reponses = ReceivePort();
    final Stream<dynamic> flux = reponses.asBroadcastStream();
    final Future<dynamic> pret = flux.firstWhere((dynamic m) => m is SendPort);
    final Isolate isolate = await Isolate.spawn<List<Object>>(
      _pointDEntree,
      <Object>[reponses.sendPort, sampleRate],
      debugName: 'trames',
    );
    final SendPort vers = await pret as SendPort;
    return IsolateFeatureAnalyzer._(isolate, vers, flux);
  }

  final Isolate _isolate;
  final SendPort _vers;
  final Stream<dynamic> _reponses;
  late final StreamSubscription<dynamic> _abonnement;
  final Map<int, Completer<Object?>> _enCours = <int, Completer<Object?>>{};
  int _prochainId = 0;
  bool _liberee = false;

  Future<Object?> _demander(List<Object> message) {
    if (_liberee) {
      throw StateError('analyseur deja libere');
    }
    final int id = _prochainId++;
    final Completer<Object?> c = Completer<Object?>();
    _enCours[id] = c;
    _vers.send(<Object>[id, ...message]);
    return c.future;
  }

  @override
  Future<List<FeatureFrame>> add(
    Float32List samples, {
    bool analysePitch = true,
  }) async {
    final Object? r = await _demander(<Object>[
      'ajouter',
      TransferableTypedData.fromList(<TypedData>[samples]),
      analysePitch,
    ]);
    return r is Float64List ? _relire(r) : const <FeatureFrame>[];
  }

  @override
  Future<void> reset() => _demander(<Object>['oublier']);

  void _onReponse(dynamic message) {
    if (message is! List<Object?>) {
      return;
    }
    final Completer<Object?>? c = _enCours.remove(message[0]! as int);
    final Object? corps = message[1];
    c?.complete(
      corps is TransferableTypedData
          ? corps.materialize().asFloat64List()
          : corps,
    );
  }

  static List<FeatureFrame> _relire(Float64List plat) => <FeatureFrame>[
        for (int i = 0; i + 4 < plat.length; i += 5)
          FeatureFrame(
            timeMs: plat[i].toInt(),
            midi: plat[i + 1].isNaN ? null : plat[i + 1],
            rms: plat[i + 2],
            onset: plat[i + 3] != 0,
            analysed: plat[i + 4] != 0,
          ),
      ];

  @override
  Future<void> dispose() async {
    if (_liberee) {
      return;
    }
    _liberee = true;
    await _abonnement.cancel();
    for (final Completer<Object?> c in _enCours.values) {
      if (!c.isCompleted) {
        c.complete(null);
      }
    }
    _enCours.clear();
    _isolate.kill(priority: Isolate.immediate);
  }
}

void _pointDEntree(List<Object> demarrage) {
  final SendPort reponses = demarrage[0] as SendPort;
  final FeatureExtractor extracteur =
      FeatureExtractor(sampleRate: demarrage[1] as int);
  final ReceivePort demandes = ReceivePort();
  reponses.send(demandes.sendPort);
  demandes.listen((dynamic message) {
    final List<Object?> m = message as List<Object?>;
    final int id = m[0]! as int;
    if (m[1] == 'oublier') {
      extracteur.reset();
      reponses.send(<Object?>[id, null]);
      return;
    }
    final Float32List samples =
        (m[2]! as TransferableTypedData).materialize().asFloat32List();
    final List<FeatureFrame> trames =
        extracteur.addSamples(samples, analysePitch: m[3]! as bool);
    final Float64List plat = Float64List(trames.length * 5);
    for (int i = 0; i < trames.length; i++) {
      final FeatureFrame t = trames[i];
      plat[5 * i] = t.timeMs.toDouble();
      plat[5 * i + 1] = t.midi ?? double.nan;
      plat[5 * i + 2] = t.rms;
      plat[5 * i + 3] = t.onset ? 1 : 0;
      plat[5 * i + 4] = t.analysed ? 1 : 0;
    }
    reponses.send(<Object?>[
      id,
      TransferableTypedData.fromList(<TypedData>[plat]),
    ]);
  });
}
