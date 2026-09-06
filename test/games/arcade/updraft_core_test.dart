import 'dart:ui';

import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/arcade/logic/updraft_core.dart';
import 'package:dally/features/games/arcade/logic/updraft_token.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic: a fixed timestep and a seeded RNG, so nothing here depends on
/// the wall clock or on frame timing.
void main() {
  const dt = 1 / 62.5;

  UpdraftCore core({
    int seed = 5,
    double w = 354,
    double h = 560,
    UpdraftToken token = UpdraftToken.dart,
  }) =>
      UpdraftCore(
          rng: DallyRandom.seeded(seed),
          arenaWidth: w,
          arenaHeight: h,
          token: token);

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
      // The *silhouette* comes to rest on the floor, not its bounding box —
      // the dart's tilted point is what touches down.
      expect(c.silhouette.bottom, closeTo(560, 0.01));
    });

    test('beating into the ceiling ends the run too', () {
      final c = core();
      for (var i = 0; i < 400 && !c.dead; i++) {
        c.beat();
        c.step(dt);
      }
      expect(c.dead, isTrue);
      expect(c.silhouette.top, closeTo(0, 0.01));
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
        expect(p.openTop, greaterThanOrEqualTo(0), reason: 'lane runs off the ceiling');
        expect(p.openBottom, lessThanOrEqualTo(560), reason: 'lane runs off the floor');
        expect(p.gapHeight, greaterThanOrEqualTo(UpdraftCore.gapEndTokens * c.tokenHeight));
        // A two-sided pillar keeps both slabs off the edges; a one-sided one is
        // open at exactly one edge by construction.
        switch (p.placement) {
          case PillarPlacement.both:
            expect(p.openTop, greaterThan(0));
            expect(p.openBottom, lessThan(560));
          case PillarPlacement.top:
            expect(p.openBottom, 560);
            expect(p.openTop, greaterThan(0));
          case PillarPlacement.bottom:
            expect(p.openTop, 0);
            expect(p.openBottom, lessThan(560));
        }
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
      // Sit hard inside whichever slab this pillar actually has and wait for it
      // to arrive.
      final inSlab = p.openTop > 0
          ? p.openTop - c.tokenHeight
          : p.openBottom + c.tokenHeight;
      advance(c, 20, each: (_) {
        if (!c.dead) {
          c.y = inSlab;
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
      // Horizontal speed answers to the *width* instead, so a pillar takes the
      // same seconds to arrive however wide the arena is.
      expect(phone.speed / phone.arenaWidth,
          closeTo(tablet.speed / tablet.arenaWidth, 1e-9));
      expect(phone.pillarWidth / phone.arenaWidth,
          closeTo(tablet.pillarWidth / tablet.arenaWidth, 1e-9));
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

  group('collision matches the visible token', () {
    // The bug: a triangular token died on a wall its silhouette never touched,
    // because the hitbox was the bounding box. Every style now collides as the
    // shape it draws.

    /// A slab occupying the column right of [x], so the only question is when
    /// the shape first touches its left edge.
    Rect wallAt(double x) => Rect.fromLTRB(x, 0, x + 40, 200);

    test('a level dart clears a wall a block is already inside', () {
      const centre = Offset(100, 100);
      final dart = updraftSilhouette(
          token: UpdraftToken.dart, centre: centre, size: 26, tiltRadians: 0);
      final block = updraftSilhouette(
          token: UpdraftToken.block, centre: centre, size: 26, tiltRadians: 0);

      // A slab biting into the top-right corner of the 26×26 box: the block's
      // corner is in it, the dart's swept-back wing is not.
      const bite = Rect.fromLTRB(108, 80, 200, 90);
      expect(block.hitsRect(bite), isTrue);
      expect(dart.hitsRect(bite), isFalse);
    });

    test('every style is caught by a wall it overlaps and clears one it does not',
        () {
      for (final token in UpdraftToken.values) {
        final s = updraftSilhouette(
            token: token, centre: const Offset(100, 100), size: 26, tiltRadians: 0);
        expect(s.hitsRect(wallAt(95)), isTrue, reason: '$token');
        expect(s.hitsRect(wallAt(140)), isFalse, reason: '$token');
      }
    });

    test('the round styles are circles, not boxes', () {
      for (final token in [UpdraftToken.dot, UpdraftToken.ring]) {
        final s = updraftSilhouette(
            token: token, centre: const Offset(100, 100), size: 26, tiltRadians: 0);
        // The corner of the bounding box is outside a circle of radius 13…
        expect(s.hitsRect(const Rect.fromLTWH(111, 111, 4, 4)), isFalse,
            reason: '$token');
        // …while the same distance straight up is inside it.
        expect(s.hitsRect(const Rect.fromLTWH(98, 89, 4, 4)), isTrue,
            reason: '$token');
      }
    });

    test('an empty slab never hits — a one-sided pillar costs nothing', () {
      final s = updraftSilhouette(
          token: UpdraftToken.block,
          centre: const Offset(100, 100),
          size: 26,
          tiltRadians: 0);
      expect(s.hitsRect(const Rect.fromLTRB(90, 0, 130, 0)), isFalse);
    });

    test('a block never outlives the dart it circumscribes, on the same seed',
        () {
      int survive(UpdraftToken token) {
        final c = core(seed: 21, token: token);
        var steps = 0;
        while (!c.dead && steps < 4000) {
          if (steps % 26 == 0) c.beat();
          c.step(dt);
          steps++;
        }
        return steps;
      }

      expect(survive(UpdraftToken.dart),
          greaterThanOrEqualTo(survive(UpdraftToken.block)));
    });
  });

  group('obstacle placement', () {
    Set<Pillar> spawnedOver(UpdraftCore c, double seconds) {
      final seen = <Pillar>{};
      advance(c, seconds, each: (_) {
        seen.addAll(c.pillars);
        c.y = _nearestGapCentre(c);
        c.velocity = 0;
      });
      seen.addAll(c.pillars);
      return seen;
    }

    test('all three placements occur over a seeded run', () {
      final seen = spawnedOver(core(seed: 9), 120);
      expect(seen.map((p) => p.placement).toSet(),
          containsAll(PillarPlacement.values));
    });

    test('every spawned pillar leaves a passable lane', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final c = core(seed: seed);
        final seen = spawnedOver(c, 90);
        expect(seen.length, greaterThan(10), reason: 'seed $seed');
        for (final p in seen) {
          expect(p.gapHeight, greaterThan(c.tokenHeight),
              reason: 'seed $seed, ${p.placement}');
          expect(p.openTop, greaterThanOrEqualTo(0));
          expect(p.openBottom, lessThanOrEqualTo(c.arenaHeight));
        }
      }
    });

    test('a one-sided pillar is open at exactly one edge', () {
      final c = core(seed: 9);
      final seen = spawnedOver(c, 120);
      for (final p in seen.where((p) => p.placement != PillarPlacement.both)) {
        final openAtCeiling = p.openTop == 0;
        final openAtFloor = p.openBottom == c.arenaHeight;
        expect(openAtCeiling ^ openAtFloor, isTrue, reason: '${p.placement}');
      }
    });

    test('the placement sequence is the same for the same seed', () {
      List<PillarPlacement> run() =>
          spawnedOver(core(seed: 31), 60).map((p) => p.placement).toList();
      expect(run(), run());
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
