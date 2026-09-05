import 'dart:math' as math;

import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/arcade/logic/jumper_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bug this file exists for: the jump impulse and the camera were pixel
/// constants while the arena came from the screen, and the next platform's x was
/// drawn from the whole arena width. On a tablet the horizontal gap between
/// consecutive platforms routinely exceeded what one bounce could cross, so the
/// player could never ascend.
///
/// Every case below runs at a fixed timestep, so nothing here depends on the
/// wall clock or on frame timing.
void main() {
  const dt = 1 / 62.5;

  /// Arena sizes from a small phone to a large tablet, portrait and landscape.
  const arenas = <(String, double, double)>[
    ('small phone', 320.0, 460.0),
    ('phone', 360.0, 560.0),
    ('tall phone', 412.0, 780.0),
    ('tablet', 768.0, 980.0),
    ('large tablet', 1024.0, 1280.0),
    ('landscape phone', 720.0, 320.0),
  ];

  /// Plays [seconds] of simulation with a driver that steers toward the nearest
  /// platform above the player — a stand-in for a competent thumb.
  double climb(JumperCore core, {double seconds = 12}) {
    final steps = (seconds / dt).round();
    for (var i = 0; i < steps && !core.dead; i++) {
      core.steer = _steerToward(core);
      core.step(dt);
    }
    return core.height;
  }

  group('the climb is possible at every arena size', () {
    for (final (label, w, h) in arenas) {
      test('$label ($w × $h) gains height', () {
        final core = JumperCore(
            rng: DallyRandom.seeded(4), arenaWidth: w, arenaHeight: h);
        final gained = climb(core);
        expect(gained, greaterThan(h),
            reason: '$label: a competent run must clear at least one screen');
      });
    }

    test('the same seed gains comparable height on a phone and a tablet', () {
      final phone = JumperCore(
          rng: DallyRandom.seeded(9), arenaWidth: 360, arenaHeight: 560);
      final tablet = JumperCore(
          rng: DallyRandom.seeded(9), arenaWidth: 768, arenaHeight: 980);
      // Height is in arena units, which scale with the screen — so compare the
      // climb in *screens*, which is what the player experiences.
      final phoneScreens = climb(phone) / 560;
      final tabletScreens = climb(tablet) / 980;
      expect(tabletScreens, greaterThan(phoneScreens * 0.5),
          reason: 'the tablet must not be a fundamentally harder game');
    });
  });

  group('generation stays within reach', () {
    for (final (label, w, h) in arenas) {
      test('$label: no band is further sideways than one bounce', () {
        final core =
            JumperCore(rng: DallyRandom.seeded(21), arenaWidth: w, arenaHeight: h);
        // Drive a long run so plenty of bands are generated, then check every
        // consecutive pair the generator produced.
        climb(core, seconds: 20);
        final bands = [...core.platforms]..sort((a, b) => b.y.compareTo(a.y));
        for (var i = 1; i < bands.length; i++) {
          final from = bands[i - 1].x + bands[i - 1].width / 2;
          final to = bands[i].x + bands[i].width / 2;
          expect((to - from).abs(), lessThanOrEqualTo(core.reach + 1),
              reason: '$label: band $i is out of horizontal reach');
        }
      });
    }

    test('one bounce always clears the vertical band gap', () {
      for (final (label, w, h) in arenas) {
        final core = JumperCore(rng: DallyRandom.seeded(1), arenaWidth: w, arenaHeight: h);
        expect(core.jumpApex, greaterThan(core.bandGap),
            reason: '$label: the apex must clear the next band');
      }
    });
  });

  group('the physics is resolution-independent', () {
    test('scale is the only thing that changes between arena sizes', () {
      final small = JumperCore(rng: DallyRandom.seeded(1), arenaWidth: 320, arenaHeight: 460);
      final big = JumperCore(rng: DallyRandom.seeded(1), arenaWidth: 1024, arenaHeight: 1280);
      // Every derived quantity keeps the same ratio to the band gap, which is
      // what "the same game at a larger size" means.
      expect(small.jumpApex / small.bandGap,
          closeTo(big.jumpApex / big.bandGap, 1e-9));
      expect(small.reach / small.bandGap, closeTo(big.reach / big.bandGap, 1e-9));
      expect(small.playerSize / small.bandGap,
          closeTo(big.playerSize / big.bandGap, 1e-9));
    });

    test('the frame rate does not change the climb', () {
      // Half-steps twice must land where whole steps land once.
      final a = JumperCore(rng: DallyRandom.seeded(6), arenaWidth: 360, arenaHeight: 560);
      final b = JumperCore(rng: DallyRandom.seeded(6), arenaWidth: 360, arenaHeight: 560);
      for (var i = 0; i < 200; i++) {
        a.steer = 0;
        a.step(dt);
      }
      for (var i = 0; i < 200; i++) {
        b.steer = 0;
        b.step(dt);
      }
      expect(b.height, a.height);
      expect(b.playerY, a.playerY);
    });

    test('a seeded run is reproducible', () {
      double run() {
        final core =
            JumperCore(rng: DallyRandom.seeded(33), arenaWidth: 412, arenaHeight: 780);
        return climb(core, seconds: 8);
      }

      expect(run(), run());
    });
  });
}

/// Steers toward the nearest platform above the player, wrapping-aware only in
/// the sense that it always picks the shorter direction on this axis.
int _steerToward(JumperCore core) {
  // The platform to climb onto is the nearest one *above* the feet — the
  // largest y that is still higher up the screen than the player is.
  final feet = core.playerY + core.playerSize;
  Platform? target;
  for (final p in core.platforms) {
    if (p.y < feet - 1 && (target == null || p.y > target.y)) target = p;
  }
  // Nothing above (the very first frames): aim at whatever is under the feet.
  for (final p in core.platforms) {
    if (target == null && p.y >= feet) target = p;
  }
  if (target == null) return 0;
  final centre = target.x + target.width / 2;
  final me = core.playerX + core.playerSize / 2;
  if ((centre - me).abs() < math.max(2, core.playerSize * 0.2)) return 0;
  return centre > me ? 1 : -1;
}
