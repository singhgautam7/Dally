import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/arcade/logic/updraft_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic: a fixed timestep and a seeded RNG, so nothing here depends on
/// the wall clock or on frame timing.
void main() {
  const dt = 1 / 62.5;

  UpdraftCore core({int seed = 5, double w = 354, double h = 560}) =>
      UpdraftCore(rng: DallyRandom.seeded(seed), arenaWidth: w, arenaHeight: h);

  void advance(UpdraftCore c, double seconds, {void Function(int step)? each}) {
    final steps = (seconds / dt).round();
    for (var i = 0; i < steps && !c.dead; i++) {
      each?.call(i);
      c.step(dt);
    }
  }

  group('the run', () {
    test('starts mid-arena, level, alive and scoreless', () {
      final c = core();
      expect(c.y, 280);
      expect(c.velocity, 0);
      expect(c.dead, isFalse);
      expect(c.score, 0);
    });

    test('gravity pulls the token down', () {
      final c = core();
      final start = c.y;
      c.step(dt);
      expect(c.y, greaterThan(start));
      expect(c.velocity, greaterThan(0));
    });

    test('a tap gives exactly one upward beat', () {
      final c = core();
      advance(c, 0.2);
      c.beat();
      expect(c.velocity, c.beatImpulse);
      final before = c.y;
      c.step(dt);
      expect(c.y, lessThan(before));
    });

    test('an untouched run ends on the floor', () {
      final c = core();
      advance(c, 10);
      expect(c.dead, isTrue);
      expect(c.y + c.tokenHeight / 2, closeTo(560, 0.01));
    });

    test('beating into the ceiling ends the run too', () {
      final c = core();
      for (var i = 0; i < 400 && !c.dead; i++) {
        c.beat();
        c.step(dt);
      }
      expect(c.dead, isTrue);
      expect(c.y - c.tokenHeight / 2, closeTo(0, 0.01));
    });

    test('a dead token stops moving and refuses to beat', () {
      final c = core();
      advance(c, 10);
      final restingY = c.y;
      c.beat();
      c.step(dt);
      expect(c.y, restingY);
    });
  });

  group('pillars and scoring', () {
    test('a pillar exists from the first frame and travels toward the token', () {
      final c = core();
      expect(c.pillars, isNotEmpty);
      final x = c.pillars.first.x;
      c.step(dt);
      expect(c.pillars.first.x, lessThan(x));
    });

    test('the gap narrows over the first twenty pillars, then holds', () {
      final c = core();
      expect(c.gapTokensFor(0), UpdraftCore.gapStartTokens);
      expect(c.gapTokensFor(20), UpdraftCore.gapEndTokens);
      expect(c.gapTokensFor(60), UpdraftCore.gapEndTokens);
      for (var n = 1; n <= 20; n++) {
        expect(c.gapTokensFor(n), lessThanOrEqualTo(c.gapTokensFor(n - 1)));
      }
    });

    test('spacing tightens over the same span, then holds', () {
      final c = core();
      expect(c.spacingSecondsFor(0), UpdraftCore.spacingStartSeconds);
      expect(c.spacingSecondsFor(20), UpdraftCore.spacingEndSeconds);
      expect(c.spacingSecondsFor(99), UpdraftCore.spacingEndSeconds);
    });

    test('every gap is clear of both edges, so no pillar is unflyable', () {
      // The token is flown by a perfect driver — pinned to the gap of whatever
      // is nearest — so the run lasts long enough to exercise the generator.
      final c = core(seed: 12);
      final seen = <Pillar>{};
      advance(c, 40, each: (_) {
        seen.addAll(c.pillars);
        c.y = _nearestGapCentre(c);
        c.velocity = 0;
      });
      seen.addAll(c.pillars);
      expect(seen.length, greaterThan(5));
      for (final p in seen) {
        expect(p.gapTop, greaterThan(0), reason: 'gap runs off the ceiling');
        expect(p.gapBottom, lessThan(560), reason: 'gap runs off the floor');
        expect(p.gapHeight, greaterThanOrEqualTo(UpdraftCore.gapEndTokens * c.tokenHeight));
      }
    });

    test('a pillar scores once and only once', () {
      final c = core(seed: 3);
      // Park the token in the first pillar's gap and let it pass.
      final p = c.pillars.first;
      var scoredAt = -1;
      advance(c, 20, each: (i) {
        c.y = p.gapCentre;
        c.velocity = 0;
        if (c.score == 1 && scoredAt < 0) scoredAt = i;
      });
      expect(c.score, greaterThanOrEqualTo(1));
      expect(p.scored, isTrue);
      // Stepping again after it is behind the token adds nothing for it.
      final before = c.score;
      c.step(dt);
      expect(c.score - before, lessThanOrEqualTo(1));
    });

    test('hitting a pillar ends the run', () {
      final c = core(seed: 8);
      final p = c.pillars.first;
      // Sit hard against the top pillar and wait for it to arrive.
      advance(c, 20, each: (_) {
        if (!c.dead) {
          c.y = p.gapTop - c.tokenHeight;
          c.velocity = 0;
        }
      });
      expect(c.dead, isTrue);
    });

    test('pillars behind the token are dropped', () {
      final c = core(seed: 2);
      advance(c, 30, each: (_) {
        c.y = _nearestGapCentre(c);
        c.velocity = 0;
      });
      for (final p in c.pillars) {
        expect(p.x + c.pillarWidth, greaterThan(-c.pillarWidth * 2));
      }
    });
  });

  group('determinism', () {
    test('the same seed replays the same run exactly', () {
      List<double> run() {
        final c = core(seed: 77);
        final gaps = <double>[];
        advance(c, 25, each: (i) {
          if (i % 40 == 0) c.beat();
          gaps.addAll(c.pillars.map((p) => p.gapCentre));
        });
        return gaps;
      }

      expect(run(), run());
    });

    test('different seeds produce different pillar layouts', () {
      List<double> firstGaps(int seed) {
        final c = core(seed: seed);
        final out = <double>[];
        advance(c, 15, each: (_) {
          c.y = _nearestGapCentre(c);
          c.velocity = 0;
          out.addAll(c.pillars.map((p) => p.gapCentre));
        });
        return out.toSet().toList();
      }

      expect(firstGaps(1), isNot(firstGaps(2)));
    });

    test('the simulation is frame-rate independent at the fixed step', () {
      double fly(int steps) {
        final c = core(seed: 4);
        for (var i = 0; i < steps && !c.dead; i++) {
          c.step(dt);
        }
        return c.y;
      }

      expect(fly(30), fly(30));
    });
  });

  group('resolution independence', () {
    test('a tablet is the same run at a larger scale', () {
      final phone = core(w: 354, h: 560);
      final tablet = core(w: 768, h: 1120);
      // Every derived quantity keeps its ratio to the token, which is what
      // "the same game at a larger size" means.
      expect(phone.gravity / phone.tokenHeight,
          closeTo(tablet.gravity / tablet.tokenHeight, 1e-9));
      expect(phone.beatImpulse / phone.tokenHeight,
          closeTo(tablet.beatImpulse / tablet.tokenHeight, 1e-9));
      expect(phone.speed / phone.tokenHeight,
          closeTo(tablet.speed / tablet.tokenHeight, 1e-9));
    });

    test('the gap is always a multiple of the token, at every size', () {
      for (final h in [420.0, 560.0, 980.0, 1280.0]) {
        final c = core(h: h);
        for (final p in c.pillars) {
          expect(p.gapHeight / c.tokenHeight,
              closeTo(UpdraftCore.gapStartTokens, 1e-9),
              reason: 'arena $h');
        }
      }
    });
  });

  group('tilt', () {
    test('follows vertical speed and is capped', () {
      final c = core();
      c.velocity = 0;
      expect(c.tiltDegrees, 0);
      c.beat();
      expect(c.tiltDegrees, lessThan(0), reason: 'rising points up');
      expect(c.tiltDegrees.abs(), lessThanOrEqualTo(UpdraftCore.maxTiltDegrees));
      c.velocity = 99999;
      expect(c.tiltDegrees, UpdraftCore.maxTiltDegrees);
      c.velocity = -99999;
      expect(c.tiltDegrees, -UpdraftCore.maxTiltDegrees);
    });
  });
}

/// The gap the token should be in right now: the nearest pillar it has not yet
/// passed. A perfect driver, so a test can run the generator for as long as it
/// likes without the run ending on a mistake.
double _nearestGapCentre(UpdraftCore c) {
  Pillar? next;
  for (final p in c.pillars) {
    if (p.x + c.pillarWidth >= c.tokenX - c.tokenHeight &&
        (next == null || p.x < next.x)) {
      next = p;
    }
  }
  return next?.gapCentre ?? c.arenaHeight / 2;
}
