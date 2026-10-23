import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/exercises/echo_game.dart';
import 'package:violon/core/exercises/long_tone_game.dart';
import 'package:violon/core/exercises/pulse_game.dart';
import 'package:violon/core/store/game_records.dart';

const List<int> premierePosition = <int>[
  55, 57, 59, 60, 62, 64, 66, 67, 69, 71, 72, 74, 76, 78, //
];

void main() {
  group('EchoGame', () {
    test('le meme motif s allonge, sans deux notes pareilles de suite', () {
      final EchoGame g = EchoGame(pool: premierePosition, seed: 3);
      expect(g.length, 2);
      final List<int> deux = g.motif;
      expect(g.judge(deux), isTrue);
      expect(g.length, 3);
      expect(g.motif.sublist(0, 2), deux, reason: 'le debut ne change pas');
      for (int i = 1; i < g.motif.length; i++) {
        expect(g.motif[i], isNot(g.motif[i - 1]));
        expect((g.motif[i] - g.motif[i - 1]).abs(), lessThanOrEqualTo(7));
      }
      expect(g.best, 2);
    });

    test('la meme graine donne le meme motif', () {
      expect(
        EchoGame(pool: premierePosition, seed: 9).motif,
        EchoGame(pool: premierePosition, seed: 9).motif,
      );
    });

    test('une erreur raccourcit d une note, jamais a zero, et le record reste',
        () {
      final EchoGame g = EchoGame(pool: premierePosition, seed: 1);
      g.judge(g.motif);
      g.judge(g.motif);
      expect(g.length, 4);
      expect(g.best, 3);
      expect(g.judge(<int>[1, 2, 3, 4]), isFalse);
      expect(g.length, 3);
      expect(g.best, 3);
      g.judge(<int>[]);
      g.judge(<int>[]);
      g.judge(<int>[]);
      expect(g.length, 2, reason: 'on ne descend pas sous le depart');
    });

    test('il sait combien des premieres notes etaient justes', () {
      final EchoGame g = EchoGame(pool: premierePosition, seed: 5);
      g.judge(g.motif);
      final List<int> m = g.motif;
      expect(g.matchedPrefix(<int>[m[0], m[1], 0]), 2);
      expect(g.matchedPrefix(<int>[]), 0);
    });
  });

  group('HeardNotes', () {
    test('une note tenue compte, un passage bref non, une repetition non', () {
      final HeardNotes h = HeardNotes();
      for (int t = 0; t <= 200; t += 20) {
        h.hear(62, t);
      }
      h.hear(63.5, 220); // un glissando, trop bref et entre deux
      for (int t = 240; t <= 500; t += 20) {
        h.hear(64.2, t);
      }
      for (int t = 520; t <= 800; t += 20) {
        h.hear(64, t);
      }
      expect(h.notes, <int>[62, 64]);
      expect(h.lastHeardMs, 800);
    });
  });

  group('LongToneGame', () {
    test('la tenue juste se compte, un bref ecart est pardonne', () {
      final LongToneGame g = LongToneGame(targetMidi: 69);
      for (int t = 0; t <= 1000; t += 20) {
        g.hear(69.05, t);
      }
      // 100 ms trop haut : pardonne.
      for (int t = 1020; t <= 1100; t += 20) {
        g.hear(69.3, t);
      }
      for (int t = 1120; t <= 2000; t += 20) {
        g.hear(68.95, t);
      }
      expect(g.currentMs(2000), 2000);
      expect(g.bestMs, 2000);
      expect(g.lastCents, closeTo(-5, 1e-9));
    });

    test('un ecart qui dure arrete la tenue, le record reste', () {
      final LongToneGame g = LongToneGame(targetMidi: 69);
      for (int t = 0; t <= 1500; t += 20) {
        g.hear(69, t);
      }
      for (int t = 1520; t <= 2000; t += 20) {
        g.hear(69.4, t);
      }
      expect(g.currentMs(2000), 0);
      expect(g.bestMs, 1500);
      for (int t = 2020; t <= 2500; t += 20) {
        g.hear(69, t);
      }
      expect(g.currentMs(2500), 480);
      expect(g.bestMs, 1500);
      g.rest(3000);
      expect(g.currentMs(3000), 0);
      expect(g.holding, isFalse);
    });
  });

  group('PulseGame', () {
    test('un tempo tenu et regulier vaut cent', () {
      final PulseGame g = PulseGame(bpm: 100);
      final PulseResult r =
          g.judge(<int>[for (int k = 0; k < 8; k++) 1000 + 600 * k])!;
      expect(r.heldBpm, closeTo(100, 1e-9));
      expect(r.driftPercent, closeTo(0, 1e-9));
      expect(r.jitterMs, 0);
      expect(r.score, 100);
      expect(g.best, 100);
    });

    test('presser se voit, l irregularite aussi, et le record reste', () {
      final PulseGame g = PulseGame(bpm: 100, best: 90);
      // 550 ms au lieu de 600 : 109 a la noire.
      final PulseResult r = g.judge(<int>[
        0, 550, 1100, 1650, 2200, 2760, 3290, 3850, //
      ])!;
      expect(r.heldBpm, closeTo(109.1, 0.2));
      expect(r.driftPercent, greaterThan(8));
      expect(r.score, lessThan(90));
      expect(g.best, 90);
    });

    test('une attaque entendue deux fois ne compte qu une fois', () {
      final PulseGame g = PulseGame(bpm: 60);
      final PulseResult r = g.judge(<int>[
        0, 40, 1000, 2000, 2030, 3000, 4000, //
      ])!;
      expect(r.heldBpm, closeTo(60, 1e-9));
    });

    test('trop peu d attaques, pas de verdict', () {
      expect(PulseGame(bpm: 60).judge(<int>[0, 1000, 2000]), isNull);
    });
  });

  group('GameRecords', () {
    test('un record ne baisse jamais, et se relit', () {
      const GameRecords r = GameRecords(echoBest: 5, pulseBest: 80);
      final GameRecords m = r.merge(
        echo: 3,
        longToneMs: 4200,
        pulse: 85,
        evenBowMs: 6100,
        vibratoMs: 3300,
      );
      expect(m.echoBest, 5);
      expect(m.longToneBestMs, 4200);
      expect(m.pulseBest, 85);
      final GameRecords lu = GameRecords.decode(m.encode());
      expect(lu.echoBest, 5);
      expect(lu.longToneBestMs, 4200);
      expect(lu.pulseBest, 85);
      expect(lu.evenBowBestMs, 6100);
      expect(lu.vibratoBestMs, 3300);
      expect(lu.merge(evenBowMs: 3000).evenBowBestMs, 6100);
      expect(GameRecords.decode('pas du json').echoBest, 0);
      expect(GameRecords.decode(null).pulseBest, 0);
    });
  });
}
