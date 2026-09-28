/// Le chiffrage d'une mesure : 4/4, 3/4, 6/8...
///
/// **Il sert a graver, pas a suivre.** Le suiveur ne suppose rien du tempo ni
/// de la mesure (ADR-009) ; la gravure, elle, en a besoin pour grouper les
/// croches comme un musicien les lit. En 6/8, trois croches font un temps :
/// les ligaturer par deux, comme en 3/4, rendrait le rythme meconnaissable.
class Meter {
  const Meter(this.beats, this.beatType)
      : assert(beats > 0, 'une mesure a au moins un temps'),
        assert(beatType > 0, 'une unite de temps est positive');

  /// Numerateur : 6 dans 6/8.
  final int beats;

  /// Denominateur : 8 dans 6/8. 4 pour la noire, 8 pour la croche.
  final int beatType;

  /// Une mesure composee se bat en temps pointes : 6/8, 9/8, 12/8.
  bool get isCompound => beatType >= 8 && beats > 3 && beats % 3 == 0;

  /// Duree d'une mesure pleine, pour une resolution donnee a la noire.
  int ticksPerMeasure(int ticksPerBeat) => ticksPerBeat * 4 * beats ~/ beatType;

  /// Duree du temps tel qu'on le bat : la noire pointee en 6/8, la noire en
  /// 4/4, la blanche en 2/2.
  ///
  /// C'est l'unite de ligature : deux croches ne se relient que si elles
  /// tombent dans le meme temps battu.
  int beatTicks(int ticksPerBeat) {
    final int unite = ticksPerBeat * 4 ~/ beatType;
    return isCompound ? unite * 3 : unite;
  }

  /// Temps battus par mesure : 2 en 6/8, 3 en 3/4.
  int pulsesPerMeasure(int ticksPerBeat) =>
      ticksPerMeasure(ticksPerBeat) ~/ beatTicks(ticksPerBeat);

  /// Le tempo tel qu'on le lit sur la partition, dans l'unite du temps
  /// battu : un morceau a la noire = 141 en 6/8 se lit noire pointee = 94.
  ///
  /// **Le reste de l'application compte a la noire**, et continue : les crans
  /// de tempo, le curseur et la notation n'ont pas a savoir ce qu'est une
  /// mesure composee. Seul ce qui se montre ou se compte a voix haute --
  /// l'indication de tempo, le metronome, le decompte -- parle en temps
  /// battus, parce que c'est ainsi que l'enfant compte.
  int pulseBpm(int quarterBpm, int ticksPerBeat) =>
      (quarterBpm * ticksPerBeat / beatTicks(ticksPerBeat)).round();

  /// Nom de la figure qui porte le temps battu.
  String pulseName(int ticksPerBeat) {
    final int t = beatTicks(ticksPerBeat);
    if (t == ticksPerBeat) {
      return 'noire';
    }
    if (t == ticksPerBeat * 3 ~/ 2) {
      return 'noire pointee';
    }
    if (t == ticksPerBeat * 2) {
      return 'blanche';
    }
    if (t == ticksPerBeat * 3) {
      return 'blanche pointee';
    }
    if (t * 2 == ticksPerBeat) {
      return 'croche';
    }
    return 'temps';
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'beats': beats,
        'beatType': beatType,
      };

  static Meter? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? b = json['beats'];
    final Object? t = json['beatType'];
    if (b is! int || t is! int || b <= 0 || t <= 0) {
      return null;
    }
    return Meter(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is Meter && other.beats == beats && other.beatType == beatType;

  @override
  int get hashCode => Object.hash(beats, beatType);

  @override
  String toString() => '$beats/$beatType';
}

/// Une mesure du morceau : son numero imprime et sa place dans le temps.
///
/// **Necessaire des qu'il y a des silences.** Tant qu'un passage n'etait fait
/// que de notes, les barres se deduisaient d'un changement de numero de
/// mesure. Une mesure de silence n'a aucune note : sans elle, elle
/// disparaitrait de la partition, et l'enfant qui compte ses mesures de pause
/// se retrouverait decale par rapport a son papier.
class Bar {
  const Bar({
    required this.number,
    required this.startTicks,
    required this.durationTicks,
  });

  /// Numero imprime sur la partition. 0 pour une levee.
  final int number;

  final int startTicks;
  final int durationTicks;

  int get endTicks => startTicks + durationTicks;

  Map<String, Object?> toJson() => <String, Object?>{
        'number': number,
        'start': startTicks,
        'duration': durationTicks,
      };

  static Bar? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? n = json['number'];
    final Object? s = json['start'];
    final Object? d = json['duration'];
    if (n is! int || s is! int || d is! int || d <= 0) {
      return null;
    }
    return Bar(number: n, startTicks: s, durationTicks: d);
  }

  @override
  bool operator ==(Object other) =>
      other is Bar &&
      other.number == number &&
      other.startTicks == startTicks &&
      other.durationTicks == durationTicks;

  @override
  int get hashCode => Object.hash(number, startTicks, durationTicks);

  @override
  String toString() => 'Bar($number @ $startTicks +$durationTicks)';
}
