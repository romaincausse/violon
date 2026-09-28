import '../music/meter.dart';
import '../music/passage.dart';
import '../music/score_note.dart';
import '../score/staff_layout.dart';
import 'accompaniment.dart';

/// Un accord : ses classes de hauteur, sa fondamentale, et son degre.
class Chord {
  const Chord({
    required this.degree,
    required this.root,
    required this.tones,
    this.seventh,
  });

  /// Degre dans la tonalite, de 0 (tonique) a 6.
  final int degree;

  /// Classe de hauteur de la fondamentale, de 0 (do) a 11.
  final int root;

  /// Les trois notes de l'accord, en classes de hauteur.
  final List<int> tones;

  /// La septieme de dominante, qui peut passer dans la melodie sans que
  /// l'accord soit faux.
  final int? seventh;

  @override
  bool operator ==(Object other) =>
      other is Chord && other.degree == degree && other.root == root;

  @override
  int get hashCode => Object.hash(degree, root);

  @override
  String toString() => 'Chord(degre ${degree + 1}, $tones)';
}

/// Une tonalite : sa tonique, et majeur ou mineur.
class KeyGuess {
  const KeyGuess(this.tonic, {required this.minor});

  final int tonic;
  final bool minor;

  /// Les accords qu'on se permet dans cette tonalite.
  ///
  /// **Peu d'accords, et les plus courants.** Un accompagnement d'eleve qui
  /// risque un accord rare pour coller a une note de passage sonne faux bien
  /// plus souvent qu'il ne sonne juste. En majeur : I, ii, IV, V, vi. En
  /// mineur : i, iv, V (sensible haussee), VI, III.
  List<Chord> get chords {
    if (minor) {
      const List<int> naturelle = <int>[0, 2, 3, 5, 7, 8, 10];
      Chord sur(int d, {bool sensible = false}) {
        final List<int> tons = <int>[
          (tonic + naturelle[d]) % 12,
          (tonic + naturelle[(d + 2) % 7]) % 12,
          (tonic + naturelle[(d + 4) % 7]) % 12,
        ];
        if (sensible) {
          // V en mineur : la tierce est la sensible, un demi-ton sous la
          // tonique. C'est l'accord qui dit "mineur harmonique".
          tons[1] = (tonic + 11) % 12;
        }
        return Chord(
          degree: d,
          root: tons.first,
          tones: tons,
          seventh: sensible ? (tonic + naturelle[3]) % 12 : null,
        );
      }

      return <Chord>[sur(0), sur(3), sur(4, sensible: true), sur(5), sur(2)];
    }
    const List<int> majeure = <int>[0, 2, 4, 5, 7, 9, 11];
    Chord sur(int d) => Chord(
          degree: d,
          root: (tonic + majeure[d]) % 12,
          tones: <int>[
            (tonic + majeure[d]) % 12,
            (tonic + majeure[(d + 2) % 7]) % 12,
            (tonic + majeure[(d + 4) % 7]) % 12,
          ],
          seventh: d == 4 ? (tonic + majeure[3]) % 12 : null,
        );
    // Le VII bemol, emprunte : do majeur en re majeur. Il ne sort que si la
    // melodie baisse elle-meme la septieme -- c'est alors l'accord juste, et
    // les accords de la tonalite heurteraient tous le do becarre.
    final int septiemeBaissee = (tonic + 10) % 12;
    return <Chord>[
      sur(0),
      sur(1),
      sur(3),
      sur(4),
      sur(5),
      Chord(
        degree: 6,
        root: septiemeBaissee,
        tones: <int>[
          septiemeBaissee,
          (tonic + 2) % 12,
          (tonic + 5) % 12,
        ],
      ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is KeyGuess && other.tonic == tonic && other.minor == minor;

  @override
  int get hashCode => Object.hash(tonic, minor);

  @override
  String toString() => 'KeyGuess($tonic ${minor ? 'mineur' : 'majeur'})';
}

/// Deduit une basse et des accords d'une melodie.
///
/// **Deterministe, et explicable.** Chaque tranche -- une mesure, ou une
/// demi-mesure quand la mesure a deux temps forts -- recoit l'accord qui
/// contient le plus de la melodie qu'elle porte, les notes longues et les
/// temps forts comptant davantage. Un enchainement se choisit en entier
/// (programmation dynamique) : V vers I, IV vers V et la tonique en tete sont
/// favorises, et changer d'accord au milieu d'une mesure coute un peu. Pas
/// d'aleatoire : le meme passage donne toujours le meme accompagnement.
///
/// **Une proposition, pas l'harmonie du compositeur.** Sur un passage qui
/// module, l'accord peut etre faux ; l'ecran le dit, et l'accompagnement
/// ecrit du fichier, quand il existe, passe devant.
class Harmonizer {
  Harmonizer._();

  /// Tonalite du passage : celle de l'armure, majeure ou relative mineure
  /// selon la melodie ; sans armure, la plus compatible avec les notes.
  static KeyGuess keyOf(Passage passage) {
    final List<double> poids = List<double>.filled(12, 0);
    for (final ScoreNote n in passage.notes) {
      poids[n.midi % 12] += n.durationTicks.toDouble();
    }
    final int? quintes = passage.keyFifths;
    if (quintes != null) {
      final int majeur = (quintes * 7) % 12;
      final int mineur = (majeur + 9) % 12;
      double triade(int t, List<int> intervalles) => intervalles.fold(
            0,
            (double s, int i) => s + poids[(t + i) % 12],
          );
      final double enMajeur = triade(majeur, const <int>[0, 4, 7]);
      final double enMineur = triade(mineur, const <int>[0, 3, 7]);
      // **La sensible decide.** Une armure dit "re majeur ou si mineur" ; ce
      // qui tranche, c'est le la diese -- la sensible haussee que seul si
      // mineur emploie. Finir sur si ne suffit pas : un extrait de morceau en
      // re majeur peut s'arreter n'importe ou.
      final bool sensible = poids[(mineur + 11) % 12] > 0;
      final bool mineure =
          (sensible && enMineur >= enMajeur * 0.8) || enMineur > enMajeur * 1.3;
      return KeyGuess(mineure ? mineur : majeur, minor: mineure);
    }
    // Profils de Krumhansl-Kessler : le poids de chaque degre dans une
    // tonalite, mesure sur l'ecoute. On garde la tonalite qui correle le
    // mieux avec les durees jouees.
    const List<double> profilMajeur = <double>[
      6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88, //
    ];
    const List<double> profilMineur = <double>[
      6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17, //
    ];
    KeyGuess meilleure = const KeyGuess(0, minor: false);
    double score = double.negativeInfinity;
    for (final bool mineure in <bool>[false, true]) {
      final List<double> profil = mineure ? profilMineur : profilMajeur;
      for (int t = 0; t < 12; t++) {
        double s = 0;
        for (int pc = 0; pc < 12; pc++) {
          s += poids[pc] * profil[(pc - t + 12) % 12];
        }
        if (s > score + 1e-9) {
          score = s;
          meilleure = KeyGuess(t, minor: mineure);
        }
      }
    }
    return meilleure;
  }

  /// Les tranches harmoniques du passage : une par mesure, ou deux quand la
  /// mesure se bat en un nombre pair de temps.
  static List<(int, int)> slicesOf(Passage passage) {
    final List<(int, int)> tranches = <(int, int)>[];
    for (final Bar b in StaffLayout.barsOf(passage)) {
      final int temps = _pulsations(passage, b);
      if (temps.isEven && temps >= 2) {
        final int moitie = b.durationTicks ~/ 2;
        tranches
          ..add((b.startTicks, b.startTicks + moitie))
          ..add((b.startTicks + moitie, b.endTicks));
      } else {
        tranches.add((b.startTicks, b.endTicks));
      }
    }
    return tranches;
  }

  /// Un accord par tranche.
  static List<Chord> chordsFor(Passage passage, {KeyGuess? key}) {
    final KeyGuess tonalite = key ?? keyOf(passage);
    final List<Chord> accords = tonalite.chords;
    final List<(int, int)> tranches = slicesOf(passage);
    final int n = tranches.length;
    final int k = accords.length;

    // Adequation de chaque accord a chaque tranche.
    final List<List<double>> fit = <List<double>>[
      for (final (int de, int a) in tranches)
        <double>[for (final Chord c in accords) _adequation(passage, c, de, a)],
    ];

    // Viterbi : meilleur enchainement jusqu'a chaque tranche.
    final List<List<double>> score = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(k, double.negativeInfinity),
    );
    final List<List<int>> venu = List<List<int>>.generate(
      n,
      (_) => List<int>.filled(k, 0),
    );
    for (int j = 0; j < k; j++) {
      score[0][j] = fit[0][j] + _prior(accords[j]) + (j == 0 ? 0.25 : 0);
    }
    for (int i = 1; i < n; i++) {
      final bool dansLaMesure =
          _memeMesure(passage, tranches[i - 1], tranches[i]);
      for (int j = 0; j < k; j++) {
        for (int p = 0; p < k; p++) {
          final double s = score[i - 1][p] +
              fit[i][j] +
              _prior(accords[j]) +
              _enchainement(accords[p], accords[j], dansLaMesure);
          if (s > score[i][j]) {
            score[i][j] = s;
            venu[i][j] = p;
          }
        }
      }
    }
    // Finir sur la tonique si la melodie le permet : c'est la cadence que
    // l'oreille attend.
    int j = 0;
    double meilleur = double.negativeInfinity;
    for (int c = 0; c < k; c++) {
      final double s = score[n - 1][c] + (c == 0 ? 0.2 : 0);
      if (s > meilleur) {
        meilleur = s;
        j = c;
      }
    }
    final List<Chord> choix = List<Chord>.filled(n, accords[j]);
    for (int i = n - 1; i > 0; i--) {
      choix[i] = accords[j];
      j = venu[i][j];
    }
    choix[0] = accords[j];
    return choix;
  }

  /// La basse et les accords, notes a jouer.
  ///
  /// **Le motif suit la mesure** : la basse sur le premier temps, l'accord
  /// sur les suivants -- "oum-pa" a deux temps, "oum-pa-pa" a trois, et a
  /// quatre la quinte en basse au troisieme temps. En 6/8, la basse sur la
  /// premiere noire pointee et l'accord sur la seconde.
  static List<AccompanimentNote> accompaniment(
    Passage passage, {
    KeyGuess? key,
  }) {
    final List<(int, int)> tranches = slicesOf(passage);
    final List<Chord> accords = chordsFor(passage, key: key);
    final List<AccompanimentNote> notes = <AccompanimentNote>[];
    List<int> voicing = const <int>[];

    Chord accordA(int tick) {
      for (int i = tranches.length - 1; i >= 0; i--) {
        if (tick >= tranches[i].$1) {
          return accords[i];
        }
      }
      return accords.first;
    }

    for (final Bar b in StaffLayout.barsOf(passage)) {
      final int temps = _pulsations(passage, b);
      final int pas = b.durationTicks ~/ temps;
      for (int t = 0; t < temps; t++) {
        final int debut = b.startTicks + t * pas;
        final Chord c = accordA(debut);
        if (t == 0 || (temps == 4 && t == 2)) {
          // La basse : la fondamentale, et sa quinte au troisieme temps d'une
          // mesure a quatre, pour que la ligne de basse bouge.
          final int classe = t == 0 ? c.root : c.tones[2];
          notes.add(
            AccompanimentNote(
              midi: _dansLaBasse(classe),
              onsetTicks: debut,
              durationTicks: pas,
              velocity: 0.8,
            ),
          );
        } else {
          voicing = _voicing(c, voicing);
          for (final int m in voicing) {
            notes.add(
              AccompanimentNote(
                midi: m,
                onsetTicks: debut,
                // Un peu detache : un accord plaque qui tiendrait jusqu'au
                // suivant empaterait la melodie.
                durationTicks: pas * 3 ~/ 4,
                velocity: 0.55,
              ),
            );
          }
        }
      }
    }
    return notes;
  }

  /// Temps battus d'une mesure : ceux du chiffrage pour une mesure pleine, a
  /// defaut autant que de noires qu'elle contient.
  static int _pulsations(Passage passage, Bar b) {
    final Meter? m = passage.meter;
    final int unite =
        m?.beatTicks(passage.ticksPerBeat) ?? passage.ticksPerBeat;
    final int n = b.durationTicks ~/ unite;
    return n < 1 ? 1 : n;
  }

  static bool _memeMesure(Passage passage, (int, int) a, (int, int) b) {
    for (final Bar bar in StaffLayout.barsOf(passage)) {
      if (a.$1 >= bar.startTicks && a.$1 < bar.endTicks) {
        return b.$1 >= bar.startTicks && b.$1 < bar.endTicks;
      }
    }
    return false;
  }

  static double _adequation(Passage passage, Chord c, int de, int a) {
    double total = 0;
    double bon = 0;
    for (final ScoreNote n in passage.notes) {
      final int debut = n.onsetTicks > de ? n.onsetTicks : de;
      final int fin = n.offsetTicks < a ? n.offsetTicks : a;
      if (fin <= debut) {
        continue;
      }
      // Une note attaquee en tete de tranche pese davantage : c'est elle que
      // l'oreille entend avec l'accord.
      final double poids = (fin - debut) * (n.onsetTicks == de ? 1.5 : 1.0);
      total += poids;
      final int pc = n.midi % 12;
      if (c.tones.contains(pc)) {
        bon += poids;
      } else if (pc == c.seventh) {
        bon += poids * 0.5;
      } else if (c.tones.contains((pc + 1) % 12) ||
          c.tones.contains((pc + 11) % 12)) {
        // Un demi-ton contre une note de l'accord : un do contre un do diese.
        // Ca ne passe pas pour une note de passage, ca s'entend comme faux.
        bon -= poids * 1.2;
      } else {
        bon -= poids * 0.6;
      }
    }
    // Une tranche de silence ne dit rien : l'enchainement decide.
    return total == 0 ? 0 : bon / total;
  }

  static double _prior(Chord c) => switch (c.degree) {
        0 => 0.12,
        4 => 0.08,
        3 => 0.08,
        6 => -0.05,
        _ => 0.02,
      };

  static double _enchainement(Chord de, Chord vers, bool dansLaMesure) {
    if (de == vers) {
      return dansLaMesure ? 0.1 : 0.03;
    }
    // Changer au milieu d'une mesure doit se meriter.
    double s = dansLaMesure ? -0.25 : 0;
    final int d = de.degree;
    final int v = vers.degree;
    if (d == 4 && v == 0) {
      s += 0.2; // V -> I, la cadence
    } else if ((d == 3 || d == 1) && v == 4) {
      s += 0.12; // IV -> V, ii -> V
    } else if (d == 0 && (v == 3 || v == 4)) {
      s += 0.06;
    } else if (d == 3 && v == 0) {
      s += 0.05; // cadence plagale
    }
    return s;
  }

  /// Une basse entre mi1 et mi2 : sous le violon, et encore nette.
  static int _dansLaBasse(int classe) {
    int m = 36 + classe;
    if (m < 40) {
      m += 12;
    }
    return m;
  }

  /// L'accord en position serree, au plus pres du precedent : les voix
  /// bougent le moins possible, comme les doigts d'un pianiste.
  static List<int> _voicing(Chord c, List<int> precedent) {
    final int centre = precedent.isEmpty
        ? 60
        : precedent.reduce((int a, int b) => a + b) ~/ precedent.length;
    List<int> meilleur = const <int>[];
    int ecart = 1 << 30;
    for (int basse = 52; basse <= 67; basse++) {
      if (!c.tones.contains(basse % 12)) {
        continue;
      }
      final List<int> v = <int>[basse];
      int m = basse;
      while (v.length < 3) {
        m++;
        if (c.tones.contains(m % 12) && !v.any((int x) => x % 12 == m % 12)) {
          v.add(m);
        }
      }
      final int milieu = v.reduce((int a, int b) => a + b) ~/ v.length;
      final int e = (milieu - centre).abs();
      if (e < ecart) {
        ecart = e;
        meilleur = v;
      }
    }
    return meilleur;
  }
}
