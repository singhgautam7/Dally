import 'package:dally/core/game/arena_scale.dart';
import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/arcade/logic/avoider_core.dart';
import 'package:dally/features/games/arcade/logic/jumper_core.dart';
import 'package:dally/features/games/arcade/logic/racer_core.dart';
import 'package:dally/features/games/arcade/logic/tower_core.dart';
import 'package:dally/features/games/arcade/logic/updraft_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The v5 fix: every arcade game was tuned in absolute pixels somewhere, so a
/// tablet was not the same game at a larger size — Tower's sweep took 7 seconds
/// instead of 1.6, Racer gave 3.3 seconds of warning instead of 1.8, and an
/// Avoider obstacle took 4.7 seconds to arrive instead of 1.2.
///
/// These walk the whole viewport matrix and assert the *ratios* rather than the
/// pixels. Nothing here touches a clock: the sims are driven at the fixed step.
void main() {
  const dt = 1 / 62.5;

  const viewports = <(String, double, double)>[
    ('small phone', 320, 470),
    ('phone', 354, 560),
    ('large phone', 412, 700),
    ('phone landscape', 700, 300),
    ('tablet portrait', 768, 1000),
    ('tablet landscape', 1180, 700),
  ];

  /// Asserts every measured value sits within [tolerance] of the first one.
  void equivalent(String what, Iterable<(String, double)> values,
      {double tolerance = 0.15}) {
    final list = values.toList();
    final reference = list.first.$2;
    for (final (name, v) in list) {
      expect(v / reference, closeTo(1, tolerance),
          reason: '$what on $name is ${v.toStringAsFixed(3)} '
              'against ${reference.toStringAsFixed(3)} on ${list.first.$1}');
    }
  }

  group('Jumper', () {
    test('every generated band is inside one bounce of the one below', () {
      for (final (name, w, h) in viewports) {
        final c = JumperCore(rng: DallyRandom.seeded(7), arenaWidth: w, arenaHeight: h);
        // Climb far enough to exercise the generator well past the initial fill.
        for (var i = 0; i < 4000 && !c.dead; i++) {
          // A perfect driver: steer toward the next band up.
          final above = c.platforms.where((p) => p.y < c.playerY - 1).toList()
            ..sort((a, b) => b.y.compareTo(a.y));
          final target = above.isEmpty ? c.playerX : above.first.x + above.first.width / 2;
          c.steer = (target - c.playerX).abs() < c.playerSize
              ? 0
              : (target > c.playerX ? 1 : -1);
          c.step(dt);
        }
        expect(c.score, greaterThan(0), reason: '$name: the climb must be possible');

        final bands = [...c.platforms]..sort((a, b) => b.y.compareTo(a.y));
        for (var i = 1; i < bands.length; i++) {
          final gap = ((bands[i].x + bands[i].width / 2) -
                  (bands[i - 1].x + bands[i - 1].width / 2))
              .abs();
          expect(gap, lessThanOrEqualTo(c.reach + 0.001),
              reason: '$name: band $i is beyond one bounce of reach');
        }
      }
    });

    test('the bounce always clears the band, at every size', () {
      for (final (name, w, h) in viewports) {
        final c = JumperCore(rng: DallyRandom.seeded(1), arenaWidth: w, arenaHeight: h);
        expect(c.jumpApex / c.bandGap, closeTo(1.436, 0.001), reason: name);
      }
    });
  });

  group('Avoider', () {
    test('an obstacle takes the same seconds to arrive on every screen', () {
      equivalent('crossing time', [
        for (final (name, w, h) in viewports)
          (
            name,
            () {
              final c = AvoiderCore(
                  rng: DallyRandom.seeded(1), arenaWidth: w, arenaHeight: h)
                ..reset();
              return (w - c.playerX) / c.speed;
            }()
          ),
      ]);
    });

    test('a jump keeps the same airtime and clears the tallest obstacle', () {
      for (final (name, w, h) in viewports) {
        final c =
            AvoiderCore(rng: DallyRandom.seeded(1), arenaWidth: w, arenaHeight: h)
              ..reset();
        expect(c.airTime, closeTo(0.6, 0.001), reason: name);
        c.jump();
        var peak = 0.0;
        for (var i = 0; i < 100; i++) {
          c.step(dt);
          if (-c.y > peak) peak = -c.y;
        }
        expect(peak, greaterThan(c.heights.last), reason: name);
      }
    });

    test('a metre is the same distance on every screen', () {
      equivalent('metres in ten seconds', [
        for (final (name, w, h) in viewports)
          (
            name,
            () {
              final c = AvoiderCore(
                  rng: DallyRandom.seeded(1), arenaWidth: w, arenaHeight: h)
                ..reset();
              for (var i = 0; i < (10 / dt).round(); i++) {
                // Waved through an obstacle rather than reset, so the ramp's
                // clock keeps running and the comparison is like for like.
                c.dead = false;
                c.step(dt);
              }
              return c.distance;
            }()
          ),
        // Tighter than the default: the score has to be comparable, not merely
        // similar, or a tablet sets records a phone cannot.
      ], tolerance: 0.001);
    });
  });

  group('Racer', () {
    test('the car gets the same seconds of warning on every screen', () {
      equivalent('reaction time', [
        for (final (name, _, h) in viewports)
          (
            name,
            () {
              final c = RacerCore(rng: DallyRandom.seeded(1), arenaHeight: h)..reset();
              return (h * RacerCore.carY) / c.speed;
            }()
          ),
      ], tolerance: 0.001);
    });

    test('a kilometre is the same distance on every screen', () {
      equivalent('metres in ten seconds', [
        for (final (name, _, h) in viewports)
          (
            name,
            () {
              final c = RacerCore(rng: DallyRandom.seeded(1), arenaHeight: h)..reset();
              for (var i = 0; i < (10 / dt).round(); i++) {
                c.step(dt);
              }
              return c.distance;
            }()
          ),
      ], tolerance: 0.001);
    });
  });

  group('Tower Builder', () {
    test('one sweep takes the same seconds and covers the same share', () {
      equivalent('sweep seconds', [
        for (final (name, w, _) in viewports)
          (
            name,
            () {
              final c = TowerCore(arenaWidth: w)..reset();
              return (w - c.startWidth) / c.speed;
            }()
          ),
      ], tolerance: 0.001);

      equivalent('block share of the width', [
        for (final (name, w, _) in viewports)
          (name, TowerCore(arenaWidth: w).startWidth / w),
      ], tolerance: 0.001);
    });
  });

  group('Updraft', () {
    test('a pillar takes the same seconds to arrive on every screen', () {
      equivalent('crossing time', [
        for (final (name, w, h) in viewports)
          (
            name,
            () {
              final c = UpdraftCore(
                  rng: DallyRandom.seeded(1), arenaWidth: w, arenaHeight: h);
              return w / c.speed;
            }()
          ),
      ], tolerance: 0.001);
    });

    test('the gap stays the same multiple of the token', () {
      equivalent('gap in token heights', [
        for (final (name, w, h) in viewports)
          (
            name,
            () {
              final c = UpdraftCore(
                  rng: DallyRandom.seeded(1), arenaWidth: w, arenaHeight: h);
              return c.pillars.first.gapHeight / c.tokenHeight;
            }()
          ),
      ], tolerance: 0.001);
    });
  });

  group('the shared difficulty ramp', () {
    test('starts at 1 and eases toward its ceiling', () {
      expect(arcadeRamp(0, amount: 1), 1);
      expect(arcadeRamp(60, amount: 1), closeTo(1.632, 0.001));
      expect(arcadeRamp(600, amount: 1), closeTo(2.0, 0.001));
      expect(arcadeRamp(1e9, amount: 1), lessThanOrEqualTo(2));
    });

    test('is a pure function of simulated time, so refresh rate cannot move it',
        () {
      // Sixty seconds fed as 62.5 Hz steps and as 125 Hz steps land in the same
      // place, because a core accumulates the fixed dt rather than frame time.
      double after(double step) {
        final c = TowerCore(arenaWidth: 354)..reset();
        for (var i = 0; i < (60 / step).round(); i++) {
          c.step(step);
        }
        return c.speed;
      }

      expect(after(1 / 62.5), closeTo(after(1 / 125), 0.001));
    });
  });
}
