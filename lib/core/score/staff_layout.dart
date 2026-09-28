import '../music/meter.dart';
import '../music/passage.dart';
import '../music/score_note.dart';
import 'staff_geometry.dart';

/// Une tete de note posee sur la portee : ou la dessiner, et avec quoi.
///
/// **Une note peut donner plusieurs tetes.** Une note qui franchit une barre
/// de mesure, ou dont la duree n'est celle d'aucune figure, s'ecrit en
/// plusieurs figures liees : c'est la meme note pour l'oreille et pour le
/// suiveur, deux tetes pour l'oeil. Chaque tete garde donc la [note] dont
/// elle vient, et sa propre part de la duree.
class PlacedNote {
  PlacedNote({
    required this.note,
    required this.step,
    required this.accidental,
    required this.ledgerSteps,
    required this.xSpaces,
    int? onsetTicks,
    int? durationTicks,
    int? measure,
    this.barStartTicks = 0,
    this.tiedToNext = false,
    this.isContinuation = false,
  })  : onsetTicks = onsetTicks ?? note.onsetTicks,
        durationTicks = durationTicks ?? note.durationTicks,
        measure = measure ?? note.measure;

  final ScoreNote note;

  /// Pas sur la portee, 0 sur la ligne du milieu.
  final int step;

  final Accidental accidental;

  /// Lignes supplementaires a tracer sous ou sur cette note.
  final List<int> ledgerSteps;

  /// Abscisse du centre de la tete, en espaces de portee.
  final double xSpaces;

  /// Debut et duree de **cette tete**, qui peuvent differer de ceux de la
  /// note quand elle est coupee.
  final int onsetTicks;
  final int durationTicks;

  /// Mesure ou tombe cette tete.
  final int measure;

  /// Debut de cette mesure : les ligatures se comptent en temps depuis la
  /// barre, pas depuis le debut du morceau, sans quoi une levee decalerait
  /// tous les groupes.
  final int barStartTicks;

  /// Une liaison de tenue part de cette tete vers la suivante.
  final bool tiedToNext;

  /// Cette tete prolonge la precedente : pas d'attaque, pas d'alteration.
  final bool isContinuation;

  double get yInSpaces => StaffGeometry.yInSpaces(step);
  bool get isOnLine => StaffGeometry.isOnLine(step);
}

/// Un silence pose sur la portee.
class PlacedRest {
  const PlacedRest({
    required this.onsetTicks,
    required this.durationTicks,
    required this.xSpaces,
    this.wholeBar = false,
  });

  final int onsetTicks;
  final int durationTicks;

  /// Centre du silence, en espaces.
  final double xSpaces;

  /// Toute la mesure est silencieuse : on grave une pause au milieu de la
  /// mesure, quelle que soit sa duree, comme sur toute partition.
  final bool wholeBar;
}

/// Mise en page d'un passage sur une portee, en espaces de portee.
///
/// **Espacement proportionnel au temps.** Un graveur professionnel espace de
/// facon non lineaire (une ronde n'occupe pas quatre fois la place d'une
/// noire). Sur deux a quatre mesures monodiques, le proportionnel se lit tres
/// bien et se raisonne en une ligne. C'est un choix assume, pas un oubli.
///
/// **Les mesures viennent du passage quand il les connait, des notes sinon.**
/// Un morceau importe porte ses mesures, silences compris ([Passage.bars]).
/// Un passage saisi ou un exercice n'en porte pas : chaque [ScoreNote] a son
/// numero de mesure, et un changement de numero est une barre. La mise en
/// page reste donc juste meme si le passage commence sur une levee.
///
/// **Les silences et les tenues ne se gravent que si les mesures sont
/// connues.** Sans elles, on ne sait pas ou finit une mesure, donc ni ce qui
/// manque ni ce qui deborde : un passage saisi garde exactement la gravure
/// qu'il a toujours eue.
///
/// **La ligne se justifie en ecartant les notes, pas en les grossissant.**
/// Une portee qui s'arrete au deux tiers de la place disponible laisse un
/// blanc a droite qu'aucune gravure n'accepte. On ne le comble pas apres coup
/// en etirant des coordonnees : on choisit [spacesPerBeat] pour que la ligne
/// tombe juste. Tout ce qui en decoule -- barres, hampes, ligatures, curseur
/// -- reste alors calcule par la meme formule, sans rattrapage.
class StaffLayout {
  const StaffLayout._({
    required this.notes,
    required this.rests,
    required this.barlineXSpaces,
    required this.widthSpaces,
    required this.ticksPerBeat,
    required this.beamUnitTicks,
    required this.firstOnsetTicks,
    required this.lastOffsetTicks,
    required this.keyFifths,
    required this.meter,
    required this.keySignatureXSpaces,
    required this.timeSignatureXSpaces,
    required double leadingSpaces,
    required double spacesPerTick,
    required List<(int, double)> barlineOffsets,
  })  : _leadingSpaces = leadingSpaces,
        _spacesPerTick = spacesPerTick,
        _barlineOffsets = barlineOffsets;

  /// Bord gauche de l'armure, juste apres la cle.
  static const double keySignatureStartSpaces = 4.2;

  /// Largeur prise par une alteration de l'armure.
  static const double keyAccidentalSpaces = 1.1;

  /// Largeur prise par le chiffrage, blanc compris.
  static const double timeSignatureSpaces = 2.6;

  /// Blanc apres la cle quand il n'y a ni armure ni chiffrage : c'est ce qui
  /// donnait les neuf espaces historiques avant la premiere note.
  static const double _blancAvantLaPremiereNote = 4.8;

  /// Place a reserver avant la premiere note pour une cle, une armure et,
  /// eventuellement, un chiffrage.
  static double leadingFor({int? keyFifths, Meter? meter}) =>
      keySignatureStartSpaces +
      (keyFifths ?? 0).abs() * keyAccidentalSpaces +
      (meter == null ? 0 : timeSignatureSpaces) +
      _blancAvantLaPremiereNote;

  /// Met en page [passage].
  ///
  /// [bars] restreint la ligne a certaines mesures du passage : c'est ce que
  /// fait `ScoreLayout` pour chaque systeme. Une note qui deborde de ces
  /// mesures n'y laisse que sa part.
  ///
  /// [showTimeSignature] ne vaut que pour le premier systeme : on ne repete
  /// pas le chiffrage a chaque ligne, contrairement a la cle et a l'armure.
  factory StaffLayout.of(
    Passage passage, {
    double spacesPerBeat = 6,
    double? leadingSpaces,
    double trailingSpaces = 3,
    double barlineGapSpaces = 2.5,
    double? stretchToSpaces,
    List<Bar>? bars,
    bool showTimeSignature = true,
  }) {
    final bool explicites = passage.bars != null;
    final List<Bar> mesures = bars ?? barsOf(passage);
    final Meter? chiffrage = showTimeSignature ? passage.meter : null;
    final double avant = leadingSpaces ??
        leadingFor(keyFifths: passage.keyFifths, meter: chiffrage);
    final int debut = mesures.first.startTicks;
    final int fin = mesures.last.endTicks;

    final double perTick = _espacesParTemps(
          duree: fin - debut,
          barres: mesures.length - 1,
          ticksPerBeat: passage.ticksPerBeat,
          spacesPerBeat: spacesPerBeat,
          leadingSpaces: avant,
          trailingSpaces: trailingSpaces,
          barlineGapSpaces: barlineGapSpaces,
          stretchToSpaces: stretchToSpaces,
        ) /
        passage.ticksPerBeat;

    // Chaque barre decale tout ce qui la suit. On memorise le cumul a partir
    // de quel instant il s'applique, pour pouvoir situer n'importe quel
    // instant sur la portee -- pas seulement les notes.
    final List<(int, double)> barlineOffsets = <(int, double)>[(0, 0)];
    final List<double> barlines = <double>[];
    for (int k = 1; k < mesures.length; k++) {
      final double xAvant = avant +
          (mesures[k].startTicks - debut) * perTick +
          (k - 1) * barlineGapSpaces;
      // La barre se glisse dans l'espace qu'on vient d'ouvrir, juste avant
      // le premier temps de la mesure suivante.
      barlines.add(xAvant + barlineGapSpaces / 2);
      barlineOffsets.add((mesures[k].startTicks, k * barlineGapSpaces));
    }
    double xDe(int tick, int k) =>
        avant + (tick - debut) * perTick + k * barlineGapSpaces;

    final int unite =
        passage.meter?.beatTicks(passage.ticksPerBeat) ?? passage.ticksPerBeat;
    final _Alterations alterations = _Alterations(passage.keyFifths);
    final List<PlacedNote> placed = <PlacedNote>[];
    final List<PlacedRest> rests = <PlacedRest>[];

    for (int k = 0; k < mesures.length; k++) {
      final Bar mesure = mesures[k];
      alterations.nouvelleMesure();
      // Ce que la mesure contient, dans l'ordre : on repere les trous au
      // passage pour y poser les silences.
      int couvert = mesure.startTicks;
      for (final ScoreNote note in passage.notes) {
        if (note.offsetTicks <= mesure.startTicks ||
            note.onsetTicks >= mesure.endTicks) {
          continue;
        }
        final int de = note.onsetTicks > mesure.startTicks
            ? note.onsetTicks
            : mesure.startTicks;
        final int a = note.offsetTicks < mesure.endTicks
            ? note.offsetTicks
            : mesure.endTicks;
        if (explicites && de > couvert) {
          rests.addAll(
            _silences(
                couvert, de, mesure, unite, passage, (int t) => xDe(t, k)),
          );
        }
        if (a > couvert) {
          couvert = a;
        }
        final List<int> morceaux = explicites
            ? _figures(de, a, mesure, unite, passage)
            : <int>[a - de];
        int t = de;
        for (int m = 0; m < morceaux.length; m++) {
          final bool suite = t > note.onsetTicks;
          final SpelledPitch ecrit =
              StaffGeometry.spell(note.midi, keyFifths: passage.keyFifths);
          final int step = passage.keyFifths == null
              ? StaffGeometry.stepOf(note.midi)
              : ecrit.step;
          placed.add(
            PlacedNote(
              note: note,
              step: step,
              accidental:
                  suite ? Accidental.none : alterations.pour(note.midi, ecrit),
              ledgerSteps: StaffGeometry.ledgerSteps(step),
              xSpaces: xDe(t, k),
              onsetTicks: t,
              durationTicks: morceaux[m],
              measure: mesure.number,
              barStartTicks: mesure.startTicks,
              tiedToNext: t + morceaux[m] < note.offsetTicks,
              isContinuation: suite,
            ),
          );
          t += morceaux[m];
        }
      }
      if (explicites && couvert < mesure.endTicks) {
        rests.addAll(
          _silences(
            couvert,
            mesure.endTicks,
            mesure,
            unite,
            passage,
            (int t) => xDe(t, k),
          ),
        );
      }
    }

    final double contentEnd = xDe(fin, mesures.length - 1);
    final double width = contentEnd + trailingSpaces;
    // Barre finale, calee sur le bord droit.
    barlines.add(width - trailingSpaces / 2);

    return StaffLayout._(
      notes: List<PlacedNote>.unmodifiable(placed),
      rests: List<PlacedRest>.unmodifiable(rests),
      barlineXSpaces: List<double>.unmodifiable(barlines),
      widthSpaces: width,
      ticksPerBeat: passage.ticksPerBeat,
      beamUnitTicks: unite,
      firstOnsetTicks: debut,
      lastOffsetTicks: fin,
      keyFifths: passage.keyFifths,
      meter: chiffrage,
      keySignatureXSpaces: keySignatureStartSpaces,
      timeSignatureXSpaces: keySignatureStartSpaces +
          (passage.keyFifths ?? 0).abs() * keyAccidentalSpaces +
          0.4,
      leadingSpaces: avant,
      spacesPerTick: perTick,
      barlineOffsets: List<(int, double)>.unmodifiable(barlineOffsets),
    );
  }

  /// Les mesures d'un passage : les siennes s'il les porte, sinon une par
  /// numero de mesure, du debut de sa premiere note au debut de la suivante.
  static List<Bar> barsOf(Passage passage) =>
      passage.bars ?? _mesuresDesNotes(passage);

  static List<Bar> _mesuresDesNotes(Passage passage) {
    final List<ScoreNote> notes = passage.notes;
    final List<Bar> mesures = <Bar>[];
    int debut = notes.first.onsetTicks;
    for (int i = 1; i <= notes.length; i++) {
      if (i == notes.length || notes[i].measure != notes[i - 1].measure) {
        final int fin =
            i == notes.length ? notes.last.offsetTicks : notes[i].onsetTicks;
        mesures.add(
          Bar(
            number: notes[i - 1].measure,
            startTicks: debut,
            durationTicks: fin - debut,
          ),
        );
        if (i < notes.length) {
          debut = notes[i].onsetTicks;
        }
      }
    }
    return mesures;
  }

  /// Les figures qui ecrivent la duree de [de] a [a], dans l'ordre.
  ///
  /// **Montrer le temps.** Une figure plus longue que le temps battu doit
  /// commencer sur un temps. En mesure composee, elle doit aussi durer un
  /// nombre entier de temps : une noire pointee liee a une croche, pas une
  /// blanche, sur le premier temps d'une 6/8. Et une note qui commence entre
  /// deux temps s'arrete au temps suivant -- une croche liee a une noire
  /// pointee, pas une blanche a cheval sur le milieu de la mesure.
  ///
  /// **Sauf si elle tient en une figure d'au plus un temps.** Trois noires
  /// dans une 6/8, l'hemiole, s'ecrivent en trois noires sur toutes les
  /// partitions : la couper en croches liees serait juste et illisible.
  static List<int> _figures(
    int de,
    int a,
    Bar mesure,
    int unite,
    Passage passage,
  ) {
    final List<int> valeurs = _valeurs(passage.ticksPerBeat);
    final bool composee = passage.meter?.isCompound ?? false;
    final List<int> morceaux = <int>[];
    int t = de;
    while (t < a) {
      final int dansLaMesure = t - mesure.startTicks;
      final bool surLeTemps = dansLaMesure % unite == 0;
      final int prochainTemps =
          mesure.startTicks + (dansLaMesure ~/ unite + 1) * unite;
      final bool dUnSeulTenant =
          composee && a - t <= unite && valeurs.contains(a - t);
      int? retenue;
      for (final int v in valeurs) {
        if (v > a - t) {
          continue;
        }
        if (v > unite && (!surLeTemps || (composee && v % unite != 0))) {
          continue;
        }
        if (composee &&
            !surLeTemps &&
            !dUnSeulTenant &&
            t + v > prochainTemps) {
          continue;
        }
        retenue = v;
        break;
      }
      // Un reste plus court qu'une double croche ne s'ecrit pas : il vient
      // d'un arrondi a l'import, et une tete de plus n'apprendrait rien.
      if (retenue == null) {
        if (morceaux.isEmpty) {
          morceaux.add(a - t);
        } else {
          morceaux[morceaux.length - 1] += a - t;
        }
        break;
      }
      morceaux.add(retenue);
      t += retenue;
    }
    return morceaux;
  }

  /// Les silences qui remplissent [de] a [a], selon la meme regle que les
  /// figures, sauf une : une mesure entierement vide prend une pause.
  static List<PlacedRest> _silences(
    int de,
    int a,
    Bar mesure,
    int unite,
    Passage passage,
    double Function(int) x,
  ) {
    if (de == mesure.startTicks && a == mesure.endTicks) {
      return <PlacedRest>[
        PlacedRest(
          onsetTicks: de,
          durationTicks: a - de,
          // Au milieu de la mesure, pas a son debut : c'est la convention, et
          // elle se lit mieux.
          xSpaces: (x(de) + x(a)) / 2,
          wholeBar: true,
        ),
      ];
    }
    final List<PlacedRest> silences = <PlacedRest>[];
    int t = de;
    for (final int v in _figures(de, a, mesure, unite, passage)) {
      if (v * 4 >= passage.ticksPerBeat) {
        silences
            .add(PlacedRest(onsetTicks: t, durationTicks: v, xSpaces: x(t)));
      }
      t += v;
    }
    return silences;
  }

  /// Figures gravables, de la plus longue a la plus courte : ronde, blanche
  /// pointee, blanche, noire pointee, noire, croche pointee, croche, double.
  static List<int> _valeurs(int tpb) => <int>[
        tpb * 4,
        tpb * 3,
        tpb * 2,
        tpb * 3 ~/ 2,
        tpb,
        tpb * 3 ~/ 4,
        tpb ~/ 2,
        tpb ~/ 4,
      ];

  /// Espacement a retenir pour que la ligne fasse [stretchToSpaces] de large.
  ///
  /// La largeur d'une portee vaut
  /// `leading + duree x espacement + barres x ecart + trailing`. Tout y est
  /// connu sauf l'espacement : il suffit donc de resoudre, sans tatonner.
  ///
  /// **On etire, on ne serre jamais.** [spacesPerBeat] est un plancher : une
  /// ligne trop longue pour la place disponible deborde et defile, elle ne se
  /// tasse pas jusqu'a devenir illisible.
  static double _espacesParTemps({
    required int duree,
    required int barres,
    required int ticksPerBeat,
    required double spacesPerBeat,
    required double leadingSpaces,
    required double trailingSpaces,
    required double barlineGapSpaces,
    required double? stretchToSpaces,
  }) {
    if (stretchToSpaces == null || !stretchToSpaces.isFinite || duree <= 0) {
      return spacesPerBeat;
    }
    final double utile = stretchToSpaces -
        leadingSpaces -
        trailingSpaces -
        barres * barlineGapSpaces;
    final double vise = utile * ticksPerBeat / duree;
    return vise > spacesPerBeat ? vise : spacesPerBeat;
  }

  final List<PlacedNote> notes;
  final List<PlacedRest> rests;

  /// Abscisses des barres de mesure, la derniere etant la barre finale.
  final List<double> barlineXSpaces;

  final double widthSpaces;

  /// Resolution du passage d'origine. Conservee ici parce que les hampes et
  /// les ligatures raisonnent en temps : une croche se ligature avec ses
  /// voisines du meme temps, pas avec ses voisines de l'ecran.
  final int ticksPerBeat;

  /// Duree du temps battu, unite de ligature : la noire pointee en 6/8.
  final int beamUnitTicks;

  /// Instant du debut de la ligne, en ticks.
  final int firstOnsetTicks;

  /// Instant de la fin de la ligne, en ticks.
  final int lastOffsetTicks;

  /// Armure a graver en tete de ligne, ou `null`.
  final int? keyFifths;

  /// Chiffrage a graver en tete de ligne, ou `null` s'il ne l'est pas ici.
  final Meter? meter;

  /// Bord gauche de l'armure et du chiffrage, en espaces.
  final double keySignatureXSpaces;
  final double timeSignatureXSpaces;

  final double _leadingSpaces;
  final double _spacesPerTick;
  final List<(int, double)> _barlineOffsets;

  /// Abscisse d'un instant quelconque, en espaces de portee.
  ///
  /// Sert au curseur, qui avance en continu et ne tombe pas sur les notes.
  /// Applique le meme decalage de barre de mesure que les notes : sans ca, le
  /// curseur prendrait de l'avance a chaque barre franchie.
  double xForTick(int tick) {
    double offset = 0;
    for (final (int depuis, double cumul) in _barlineOffsets) {
      if (tick >= depuis) {
        offset = cumul;
      } else {
        break;
      }
    }
    return _leadingSpaces + (tick - firstOnsetTicks) * _spacesPerTick + offset;
  }

  /// Pas le plus grave atteint, lignes supplementaires comprises. Sert a
  /// dimensionner la zone de dessin sans rogner les notes hors portee.
  int get lowestStep => notes
      .map((PlacedNote p) => p.step)
      .fold(StaffGeometry.bottomLineStep, (int a, int b) => a < b ? a : b);

  int get highestStep => notes
      .map((PlacedNote p) => p.step)
      .fold(StaffGeometry.topLineStep, (int a, int b) => a > b ? a : b);
}

/// Ce que la mesure en cours a deja altere.
///
/// **Une alteration vaut jusqu'a la barre.** Un do becarre ecrit en debut de
/// mesure vaut pour les do suivants de la meme octave ; la barre suivante
/// rend a l'armure ce qui lui appartient.
class _Alterations {
  _Alterations(this.keyFifths)
      : _armure = StaffGeometry.keyAlterations(keyFifths ?? 0);

  final int? keyFifths;
  final List<int> _armure;
  final Map<int, int> _enCours = <int, int>{};

  void nouvelleMesure() => _enCours.clear();

  Accidental pour(int midi, SpelledPitch ecrit) {
    if (keyFifths == null) {
      // Sans armure, la gravure historique : un diese devant chaque touche
      // noire, sans memoire de mesure.
      return StaffGeometry.accidentalOf(midi);
    }
    final int cle = ecrit.octave * 7 + ecrit.letter;
    final int attendue = _enCours[cle] ?? _armure[ecrit.letter];
    if (attendue == ecrit.alter) {
      return Accidental.none;
    }
    _enCours[cle] = ecrit.alter;
    return switch (ecrit.alter) {
      1 => Accidental.sharp,
      -1 => Accidental.flat,
      _ => Accidental.natural,
    };
  }
}
