import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'pitch_analyzer.dart';
import 'pitch_estimate.dart';
import 'yin_detector.dart';

/// YIN execute dans un isolate dedie.
///
/// **Pourquoi.** L'analyse est un calcul serre : une boucle imbriquee sur
/// 1024 decalages de 1024 echantillons, soit un million de multiplications
/// par trame. Sur l'isolate principal, ce calcul tombe pile entre deux images
/// et repousse celle qui suit. Le curseur avance sur l'horloge, donc il ne se
/// desynchronise pas, mais il saccade -- et la charge ne fera qu'augmenter
/// quand le detecteur d'attaques (A3) et le lissage (A5) s'y ajouteront.
///
/// **Le buffer est transfere, pas copie.** [TransferableTypedData] cede la
/// memoire a l'isolate receveur au lieu de la dupliquer. L'appelant ne doit
/// donc plus toucher au tableau qu'il a soumis ; c'est sans risque ici, le
/// decoupage en trames en alloue un neuf a chaque fois.
class YinIsolateAnalyzer implements PitchAnalyzer {
  YinIsolateAnalyzer._(this._isolate, this._vers, this._reponses) {
    _abonnement = _reponses.listen(_onReponse);
  }

  /// Demarre l'isolate et attend qu'il soit pret a recevoir.
  static Future<YinIsolateAnalyzer> spawn({
    int sampleRate = 44100,
    double threshold = 0.15,
    double minFrequencyHz = 180,
    double maxFrequencyHz = 3000,
  }) async {
    final ReceivePort reponses = ReceivePort();
    final Completer<SendPort> pret = Completer<SendPort>();
    final Stream<dynamic> flux = reponses.asBroadcastStream();
    final StreamSubscription<dynamic> premier = flux.listen((dynamic message) {
      if (message is SendPort && !pret.isCompleted) {
        pret.complete(message);
      }
    });

    final Isolate isolate = await Isolate.spawn<_Demarrage>(
      _pointDEntree,
      _Demarrage(
        reponses.sendPort,
        sampleRate,
        threshold,
        minFrequencyHz,
        maxFrequencyHz,
      ),
      debugName: 'yin',
    );

    final SendPort vers = await pret.future;
    await premier.cancel();
    return YinIsolateAnalyzer._(isolate, vers, flux);
  }

  final Isolate _isolate;
  final SendPort _vers;
  final Stream<dynamic> _reponses;
  late final StreamSubscription<dynamic> _abonnement;

  final Map<int, Completer<PitchEstimate?>> _enCours =
      <int, Completer<PitchEstimate?>>{};
  int _prochainId = 0;
  bool _liberee = false;

  @override
  Future<PitchEstimate?> analyze(
    Float32List samples, {
    required int timestampMs,
  }) {
    if (_liberee) {
      throw StateError('analyseur deja libere');
    }
    final int id = _prochainId++;
    final Completer<PitchEstimate?> completer = Completer<PitchEstimate?>();
    _enCours[id] = completer;
    _vers.send(<Object>[
      id,
      TransferableTypedData.fromList(<TypedData>[samples]),
      timestampMs,
    ]);
    return completer.future;
  }

  void _onReponse(dynamic message) {
    if (message is! List<Object?>) {
      return;
    }
    final int id = message[0]! as int;
    final Completer<PitchEstimate?>? completer = _enCours.remove(id);
    if (completer == null || completer.isCompleted) {
      return;
    }
    final double? frequence = message[1] as double?;
    if (frequence == null) {
      completer.complete(null);
      return;
    }
    completer.complete(
      PitchEstimate(
        frequencyHz: frequence,
        confidence: message[2]! as double,
        timestampMs: message[3]! as int,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_liberee) {
      return;
    }
    _liberee = true;
    await _abonnement.cancel();
    // Une analyse en vol ne reviendra jamais : la denouer plutot que de
    // laisser un `await` suspendu pour toujours.
    for (final Completer<PitchEstimate?> c in _enCours.values) {
      if (!c.isCompleted) {
        c.complete(null);
      }
    }
    _enCours.clear();
    _isolate.kill(priority: Isolate.immediate);
  }
}

/// Ce que l'isolate recoit a sa naissance.
class _Demarrage {
  const _Demarrage(
    this.reponses,
    this.sampleRate,
    this.threshold,
    this.minFrequencyHz,
    this.maxFrequencyHz,
  );

  final SendPort reponses;
  final int sampleRate;
  final double threshold;
  final double minFrequencyHz;
  final double maxFrequencyHz;
}

/// Corps de l'isolate. Il ne fait que detecter : aucune regle metier ici.
void _pointDEntree(_Demarrage demarrage) {
  final YinDetector detector = YinDetector(
    sampleRate: demarrage.sampleRate,
    threshold: demarrage.threshold,
    minFrequencyHz: demarrage.minFrequencyHz,
    maxFrequencyHz: demarrage.maxFrequencyHz,
  );
  final ReceivePort demandes = ReceivePort();
  demarrage.reponses.send(demandes.sendPort);

  demandes.listen((dynamic message) {
    final List<Object?> demande = message as List<Object?>;
    final int id = demande[0]! as int;
    final Float32List samples =
        (demande[1]! as TransferableTypedData).materialize().asFloat32List();
    final int timestampMs = demande[2]! as int;

    final PitchEstimate? estimate =
        detector.detect(samples, timestampMs: timestampMs);
    demarrage.reponses.send(<Object?>[
      id,
      estimate?.frequencyHz,
      estimate?.confidence,
      estimate?.timestampMs ?? timestampMs,
    ]);
  });
}
