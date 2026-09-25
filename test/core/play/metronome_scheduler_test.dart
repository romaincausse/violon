import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/play/metronome_clock.dart';
import 'package:violon/core/play/metronome_scheduler.dart';

void main() {
  const MetronomeClock aSoixante = MetronomeClock(tempoBpm: 60);

  group('MetronomeClock, l instant des pulsations', () {
    test('a soixante, une pulsation par seconde', () {
      expect(aSoixante.pulseTime(0), Duration.zero);
      expect(aSoixante.pulseTime(1), const Duration(seconds: 1));
      expect(aSoixante.pulseTime(4), const Duration(seconds: 4));
    });

    test('les subdivisions tombent entre les temps', () {
      const MetronomeClock croches =
          MetronomeClock(tempoBpm: 60, subdivision: 2);
      expect(croches.pulseTime(1), const Duration(milliseconds: 500));
      expect(croches.pulseTime(2), const Duration(seconds: 1));
    });

    test('rien ne derive, meme apres mille pulsations', () {
      // A 92 a la noire en triolets, une pulsation ne tombe sur aucun entier
      // de microseconde. Cumuler la duree d'une pulsation ferait deriver ;
      // multiplier puis diviser, non.
      const MetronomeClock triolets =
          MetronomeClock(tempoBpm: 92, subdivision: 3);
      for (final int n in <int>[1, 10, 1000, 100000]) {
        final double exact = n * 60 * 1000000 / (92 * 3);
        expect(
          (triolets.pulseTime(n).inMicroseconds - exact).abs(),
          lessThan(1),
          reason: 'pulsation $n',
        );
      }
    });

    test('l accent se lit aussi bien par instant que par numero', () {
      const MetronomeClock croches = MetronomeClock(
        tempoBpm: 60,
        beatsPerMeasure: 4,
        subdivision: 2,
      );
      expect(croches.accentOf(0), PulseAccent.downbeat);
      expect(croches.accentOf(1), PulseAccent.subdivision);
      expect(croches.accentOf(2), PulseAccent.beat);
      expect(croches.accentOf(8), PulseAccent.downbeat);
      for (int i = 0; i < 20; i++) {
        expect(
          croches
              .accentAt(croches.pulseTime(i) + const Duration(milliseconds: 1)),
          croches.accentOf(i),
          reason: 'pulsation $i',
        );
      }
    });
  });

  group('MetronomeScheduler', () {
    test('au depart, il pose ce qui tient dans l horizon', () {
      final MetronomeScheduler planificateur = MetronomeScheduler(
        clock: aSoixante,
        lookahead: const Duration(milliseconds: 1500),
      );
      final List<ScheduledPulse> aPoser = planificateur.due(Duration.zero);
      expect(aPoser.map((ScheduledPulse p) => p.index), <int>[0, 1]);
      expect(aPoser.first.at, Duration.zero);
      expect(aPoser.first.accent, PulseAccent.downbeat);
      expect(aPoser.last.at, const Duration(seconds: 1));
      expect(aPoser.last.accent, PulseAccent.beat);
    });

    test('appele deux fois sans avancer, il ne repose rien', () {
      // Un clic double s'entend autant qu'un clic manquant.
      final MetronomeScheduler planificateur =
          MetronomeScheduler(clock: aSoixante);
      planificateur.due(Duration.zero);
      expect(planificateur.due(Duration.zero), isEmpty);
      expect(planificateur.due(const Duration(milliseconds: 100)), isEmpty);
    });

    test('il reprend exactement ou il s etait arrete', () {
      final MetronomeScheduler planificateur = MetronomeScheduler(
        clock: aSoixante,
        lookahead: const Duration(milliseconds: 1500),
      );
      planificateur.due(Duration.zero);
      final List<ScheduledPulse> suite =
          planificateur.due(const Duration(milliseconds: 600));
      expect(suite.map((ScheduledPulse p) => p.index), <int>[2]);
      expect(suite.single.at, const Duration(seconds: 2));
    });

    test('aucune pulsation ne se perd, meme si le remplissage traine', () {
      // Le scenario redoute : l'interface bloque une seconde entiere. Les
      // clics deja poses sonnent a l'heure, et ceux qui manquent sont rendus
      // d'un coup -- aucun numero ne saute.
      final MetronomeScheduler planificateur = MetronomeScheduler(
        clock: aSoixante,
        lookahead: const Duration(milliseconds: 500),
      );
      final List<int> vus = <int>[];
      for (final Duration maintenant in <Duration>[
        Duration.zero,
        const Duration(milliseconds: 4000),
        const Duration(milliseconds: 4100),
      ]) {
        vus.addAll(
            planificateur.due(maintenant).map((ScheduledPulse p) => p.index));
      }
      expect(vus, <int>[0, 1, 2, 3, 4]);
    });

    test('le delai se compte depuis maintenant', () {
      const ScheduledPulse pulsation = ScheduledPulse(
        index: 2,
        at: Duration(seconds: 2),
        accent: PulseAccent.beat,
      );
      expect(
        MetronomeScheduler.delayFor(
            pulsation, const Duration(milliseconds: 400)),
        const Duration(milliseconds: 1600),
      );
    });

    test('une pulsation en retard sonne tout de suite, elle n est pas perdue',
        () {
      // C'est le seul endroit ou la charge de l'interface peut s'entendre, et
      // elle s'entend comme un clic en avance -- jamais comme une derive qui
      // s'accumule.
      const ScheduledPulse pulsation = ScheduledPulse(
        index: 1,
        at: Duration(seconds: 1),
        accent: PulseAccent.beat,
      );
      expect(
        MetronomeScheduler.delayFor(pulsation, const Duration(seconds: 3)),
        Duration.zero,
      );
    });

    test('reset fait repartir de la premiere pulsation', () {
      final MetronomeScheduler planificateur =
          MetronomeScheduler(clock: aSoixante);
      planificateur.due(const Duration(seconds: 10));
      expect(planificateur.lastScheduledIndex, greaterThan(0));
      planificateur.reset();
      expect(planificateur.lastScheduledIndex, -1);
      expect(planificateur.due(Duration.zero).first.index, 0);
    });

    test('les subdivisions sont posees avec leur accent', () {
      final MetronomeScheduler planificateur = MetronomeScheduler(
        clock: const MetronomeClock(
          tempoBpm: 60,
          beatsPerMeasure: 2,
          subdivision: 2,
        ),
        lookahead: const Duration(milliseconds: 1600),
      );
      expect(
        planificateur.due(Duration.zero).map((ScheduledPulse p) => p.accent),
        <PulseAccent>[
          PulseAccent.downbeat,
          PulseAccent.subdivision,
          PulseAccent.beat,
          PulseAccent.subdivision,
        ],
      );
    });
  });
}
