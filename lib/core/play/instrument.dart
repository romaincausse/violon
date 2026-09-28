import 'dart:math' as math;

/// Un echantillon enregistre : une note d'un instrument, et sa hauteur reelle.
///
/// **La hauteur est mesuree, pas deduite du nom.** Un echantillon de piano
/// etire dans l'aigu, un violon au vibrato large s'ecartent de leur note
/// nominale de dix, vingt, trente cents : jouer "la" en se fiant au nom du
/// fichier ferait un la faux. `tool/echantillons.py` mesure chaque fichier, et
/// c'est cette mesure qui sert a calculer la vitesse de lecture.
class InstrumentSample {
  const InstrumentSample({
    required this.midi,
    required this.hz,
    required this.file,
    this.loopStart,
  });

  /// Note nominale, pour choisir l'echantillon le plus proche.
  final int midi;

  /// Hauteur mesuree de l'enregistrement.
  final double hz;

  /// Nom du fichier dans `assets/sons/`.
  final String file;

  /// Debut de la boucle de tenue, pour un instrument qui tient la note.
  final Duration? loopStart;

  static InstrumentSample? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? midi = json['midi'];
    final Object? hz = json['hz'];
    final Object? file = json['file'];
    final Object? boucle = json['loopStart'];
    if (midi is! int || hz is! num || hz <= 0 || file is! String) {
      return null;
    }
    return InstrumentSample(
      midi: midi,
      hz: hz.toDouble(),
      file: file,
      loopStart: boucle is num
          ? Duration(microseconds: (boucle * 1000000).round())
          : null,
    );
  }
}

/// Ce qu'il faut pour jouer une note : quel echantillon, et a quelle vitesse.
class SamplePlayback {
  const SamplePlayback(this.sample, this.speed);

  final InstrumentSample sample;

  /// Vitesse de lecture : 1 joue l'echantillon a sa hauteur, 2 a l'octave.
  final double speed;
}

/// Un instrument : son nom, et ses echantillons du grave a l'aigu.
class Instrument {
  Instrument({
    required this.id,
    required this.name,
    required this.sustains,
    required List<InstrumentSample> samples,
  })  : assert(samples.isNotEmpty, 'un instrument a au moins un echantillon'),
        samples = List<InstrumentSample>.unmodifiable(
          List<InstrumentSample>.of(samples)
            ..sort((InstrumentSample a, InstrumentSample b) =>
                a.hz.compareTo(b.hz)),
        );

  final String id;

  /// Nom affiche.
  final String name;

  /// L'instrument tient la note tant qu'on veut : ses echantillons bouclent.
  /// Un piano, lui, s'eteint -- et ne peut donc pas servir de bourdon.
  final bool sustains;

  final List<InstrumentSample> samples;

  /// Au-dela de trois demi-tons de transposition, un timbre enregistre se
  /// deforme : la voix d'un violon ralenti d'une quinte n'est plus un violon.
  static const int margeDemiTons = 3;

  int get lowestMidi => samples.first.midi - margeDemiTons;
  int get highestMidi => samples.last.midi + margeDemiTons;

  /// L'echantillon le plus proche de [hz], et la vitesse qui l'y amene.
  SamplePlayback playbackFor(double hz) {
    InstrumentSample meilleur = samples.first;
    double ecart = double.infinity;
    for (final InstrumentSample s in samples) {
      final double e = (math.log(hz / s.hz)).abs();
      if (e < ecart) {
        ecart = e;
        meilleur = s;
      }
    }
    return SamplePlayback(meilleur, hz / meilleur.hz);
  }

  /// Ramene [midi] dans la tessiture de l'instrument, par octaves.
  ///
  /// **Une octave plutot qu'une deformation.** Une basse de piano confiee a
  /// une flute monte d'une ou deux octaves : c'est ce que ferait un
  /// arrangeur, et c'est bien moins faux que de ralentir un echantillon de
  /// flute jusqu'a le rendre meconnaissable.
  int fold(int midi) {
    int m = midi;
    while (m < lowestMidi && m + 12 <= highestMidi) {
      m += 12;
    }
    while (m > highestMidi && m - 12 >= lowestMidi) {
      m -= 12;
    }
    return m;
  }

  static Instrument? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? id = json['id'];
    final Object? name = json['name'];
    final Object? tient = json['sustains'];
    final Object? brut = json['samples'];
    if (id is! String || name is! String || brut is! List<Object?>) {
      return null;
    }
    final List<InstrumentSample> samples = <InstrumentSample>[
      for (final Object? s in brut)
        if (InstrumentSample.fromJson(s) case final InstrumentSample e) e,
    ];
    if (samples.isEmpty) {
      return null;
    }
    return Instrument(
      id: id,
      name: name,
      sustains: tient == true,
      samples: samples,
    );
  }
}

/// Les instruments embarques, tels que les decrit `assets/sons/instruments.json`.
class InstrumentLibrary {
  InstrumentLibrary(List<Instrument> instruments)
      : instruments = List<Instrument>.unmodifiable(instruments);

  final List<Instrument> instruments;

  static final InstrumentLibrary vide = InstrumentLibrary(const <Instrument>[]);

  Instrument? byId(String id) {
    for (final Instrument i in instruments) {
      if (i.id == id) {
        return i;
      }
    }
    return null;
  }

  /// Ceux qui tiennent la note : les seuls qui puissent faire un bourdon.
  List<Instrument> get sustaining =>
      instruments.where((Instrument i) => i.sustains).toList();

  static InstrumentLibrary fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return vide;
    }
    final Object? brut = json['instruments'];
    if (brut is! List<Object?>) {
      return vide;
    }
    return InstrumentLibrary(<Instrument>[
      for (final Object? i in brut)
        if (Instrument.fromJson(i) case final Instrument instrument) instrument,
    ]);
  }
}
