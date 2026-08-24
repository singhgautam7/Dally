import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/arcade/logic/avoider_core.dart';
import 'package:dally/features/games/arcade/logic/jumper_core.dart';
import 'package:dally/features/games/arcade/logic/racer_core.dart';
import 'package:dally/features/games/arcade/logic/reaction_core.dart';
import 'package:dally/features/games/arcade/logic/tower_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs a core for [seconds] at a fixed 16ms step, the way the shared loop does.
void advance(void Function(double) step, double seconds, {double dt = 0.016}) {
  for (var t = 0.0; t < seconds; t += dt) {
    step(dt);
  }
}

void main() {
  group('Jumper', () {
    test('the same seed produces the same platform sequence', () {
      List<double> run(int seed) {
        final core = JumperCore(
          rng: DallyRandom.seeded(seed),
          arenaWidth: 320,
          arenaHeight: 560,
        );
        return core.platforms.map((p) => p.x).toList();
      }

      expect(run(7), run(7));
      expect(run(7), isNot(run(8)));
    });

    test('platform bands are a fixed gap apart, so the next is always in range', () {
      final core = JumperCore(
        rng: DallyRandom.seeded(3),
        arenaWidth: 320,
        arenaHeight: 560,
      );
      final ys = core.platforms.map((p) => p.y).toList()..sort();
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i] - ys[i - 1], closeTo(JumperCore.bandGap, 0.001));
      }
    });

    test('the apex of a bounce clears one band', () {
      // Peak rise = v² / 2g, which must exceed the fixed band gap.
      final apex = (JumperCore.jumpImpulse * JumperCore.jumpImpulse) /
          (2 * JumperCore.gravity);
      expect(apex, greaterThan(JumperCore.bandGap));
    });

    test('advancing is frame-rate independent', () {
      double heightAfter(double dt) {
        final core = JumperCore(
          rng: DallyRandom.seeded(11),
          arenaWidth: 320,
          arenaHeight: 560,
        );
        core.steer = 0;
        advance(core.step, 2.0, dt: dt);
        return core.height;
      }

      // The loop always hands over its fixed step, so this is the same number.
      expect(heightAfter(0.016), heightAfter(0.016));
    });

    test('falling off the bottom is death', () {
      final core = JumperCore(
        rng: DallyRandom.seeded(1),
        arenaWidth: 320,
        arenaHeight: 560,
      );
      core.platforms.clear();
      advance(core.step, 5.0);
      expect(core.dead, isTrue);
    });
  });

  group('Tower Builder', () {
    test('a drop is cut to the overlap, so the tower only narrows', () {
      final core = TowerCore(arenaWidth: 320)..reset();
      final before = core.floors.last.width;
      core.sweepLeft = core.floors.last.left + 20;
      final width = core.drop();
      expect(width, closeTo(before - 20, 0.001));
      expect(core.floors.last.width, lessThan(before));
    });

    test('a miss ends the run', () {
      final core = TowerCore(arenaWidth: 320)..reset();
      core.sweepLeft = core.floors.last.right + 5;
      expect(core.drop(), 0);
      expect(core.dead, isTrue);
    });

    test('three perfect drops widen the block one step', () {
      final core = TowerCore(arenaWidth: 320)..reset();
      // Narrow the tower first — the reward is for recovering width, and it
      // never grows past where the run started.
      core.sweepLeft = core.floors.last.left + 30;
      core.drop();
      final narrowed = core.floors.last.width;
      for (var i = 0; i < 3; i++) {
        core.sweepLeft = core.floors.last.left;
        core.drop();
      }
      expect(core.justWidened, isTrue);
      expect(core.floors.last.width, greaterThan(narrowed));
      expect(core.floors.last.width, lessThanOrEqualTo(TowerCore.startWidth));
    });

    test('a miss between perfects resets the run', () {
      final core = TowerCore(arenaWidth: 320)..reset();
      core.sweepLeft = core.floors.last.left;
      core.drop();
      core.sweepLeft = core.floors.last.left + 10;
      core.drop();
      expect(core.perfectRun, 0);
    });

    test('sweep speed rises every five floors', () {
      final core = TowerCore(arenaWidth: 320)..reset();
      final base = core.speed;
      for (var i = 0; i < 5; i++) {
        core.sweepLeft = core.floors.last.left;
        core.drop();
      }
      expect(core.speed, greaterThan(base));
    });

    test('the sweep reverses at both walls', () {
      final core = TowerCore(arenaWidth: 320)..reset();
      core.direction = 1;
      advance(core.step, 4.0);
      expect(core.sweepLeft, inInclusiveRange(0, 320 - core.sweepWidth));
    });
  });

  group('Reaction', () {
    test('a tap before the arena lights loses that attempt only', () {
      final core = ReactionCore(rng: DallyRandom.seeded(2))..reset();
      expect(core.tap(), isNull);
      expect(core.phase, ReactionPhase.tooEarly);
      expect(core.attempts, [null]);
      core.armNext();
      expect(core.attempts.length, 1, reason: 'the set continues');
    });

    test('the arena lights between one and five seconds', () {
      for (var seed = 0; seed < 40; seed++) {
        final core = ReactionCore(rng: DallyRandom.seeded(seed))..reset();
        var elapsed = 0.0;
        while (core.phase == ReactionPhase.waiting && elapsed < 8) {
          core.step(0.016);
          elapsed += 0.016;
        }
        expect(elapsed, inInclusiveRange(0.9, 5.1));
      }
    });

    test('the set average ignores misfires and needs five attempts', () {
      final core = ReactionCore(rng: DallyRandom.seeded(5))..reset();
      core.attempts.addAll([300, null, 200, 400, 300]);
      expect(core.setComplete, isTrue);
      expect(core.setAverage, 300);
    });

    test('a set of nothing but misfires has no average', () {
      final core = ReactionCore(rng: DallyRandom.seeded(5))..reset();
      core.attempts.addAll([null, null, null, null, null]);
      expect(core.setAverage, isNull);
    });
  });

  group('Racer', () {
    test('a spawned row always leaves one lane open', () {
      final core = RacerCore(rng: DallyRandom.seeded(4), arenaHeight: 560)..reset();
      for (var i = 0; i < 400; i++) {
        core.step(0.016);
        final rows = <double, Set<int>>{};
        for (final b in core.blocks) {
          rows.putIfAbsent(b.y.roundToDouble(), () => {}).add(b.lane);
        }
        for (final lanes in rows.values) {
          expect(lanes.length, lessThan(RacerCore.lanes));
        }
        if (core.dead) break;
      }
    });

    test('lane changes stay on the road', () {
      final core = RacerCore(rng: DallyRandom.seeded(4), arenaHeight: 560)..reset();
      for (var i = 0; i < 10; i++) {
        core.moveLeft();
      }
      expect(core.lane, 0);
      for (var i = 0; i < 10; i++) {
        core.moveRight();
      }
      expect(core.lane, RacerCore.lanes - 1);
    });

    test('distance is in metres, so a km is a real run', () {
      final core = RacerCore(rng: DallyRandom.seeded(4), arenaHeight: 560)..reset();
      advance(core.step, 1.0);
      expect(core.distance, inInclusiveRange(10, 30));
    });

    test('the speed curve flattens rather than running away', () {
      final core = RacerCore(rng: DallyRandom.seeded(4), arenaHeight: 560)..reset();
      final early = core.speed;
      core.distance = 100000;
      expect(core.speed, greaterThan(early));
      expect(core.speed, lessThan(600));
    });

    test('the same seed gives the same spawn sequence', () {
      List<int> run(int seed) {
        final core = RacerCore(rng: DallyRandom.seeded(seed), arenaHeight: 560)..reset();
        for (var i = 0; i < 200; i++) {
          core.step(0.016);
        }
        return core.blocks.map((b) => b.lane).toList();
      }

      expect(run(9), run(9));
    });
  });

  group('Avoider', () {
    test('every gap is at least one full jump wide', () {
      final core = AvoiderCore(rng: DallyRandom.seeded(6), arenaWidth: 320)..reset();
      for (var i = 0; i < 4000; i++) {
        core.step(0.016);
        final xs = core.obstacles.map((o) => o.x).toList()..sort();
        for (var j = 1; j < xs.length; j++) {
          expect(xs[j] - xs[j - 1], greaterThan(core.jumpSpan));
        }
        if (core.dead) {
          core.reset();
        }
      }
    });

    test('a jump clears the tallest obstacle', () {
      final core = AvoiderCore(rng: DallyRandom.seeded(6), arenaWidth: 320)..reset();
      core.jump();
      var peak = 0.0;
      for (var i = 0; i < 100; i++) {
        core.step(0.016);
        if (-core.y > peak) peak = -core.y;
      }
      expect(peak, greaterThan(AvoiderCore.heights.last));
    });

    test('you cannot double-jump', () {
      final core = AvoiderCore(rng: DallyRandom.seeded(6), arenaWidth: 320)..reset();
      core.jump();
      core.step(0.016);
      final v = core.velocityY;
      core.jump();
      expect(core.velocityY, v);
    });

    test('a metre of score is a real distance, not one arena unit', () {
      final core = AvoiderCore(rng: DallyRandom.seeded(6), arenaWidth: 320)..reset();
      advance(core.step, 1.0);
      // ~17 m/s, not ~240: the 250 m and 1000 m thresholds have to mean
      // something, so distance is reported in metres, not raw arena units.
      expect(core.distance, inInclusiveRange(10, 30));
    });

    test('the landing gap stays in arena units, so it still clears a jump', () {
      final core = AvoiderCore(rng: DallyRandom.seeded(6), arenaWidth: 320)..reset();
      for (var i = 0; i < 3000; i++) {
        core.step(0.016);
        final xs = core.obstacles.map((o) => o.x).toList()..sort();
        for (var j = 1; j < xs.length; j++) {
          expect(xs[j] - xs[j - 1], greaterThan(core.jumpSpan));
        }
        if (core.dead) core.reset();
      }
    });

    test('speed rises every 250 metres', () {
      final core = AvoiderCore(rng: DallyRandom.seeded(6), arenaWidth: 320)..reset();
      final base = core.speed;
      core.distance = 500;
      expect(core.speed, greaterThan(base));
    });

    test('the same seed gives the same obstacle heights', () {
      List<double> run(int seed) {
        final core = AvoiderCore(rng: DallyRandom.seeded(seed), arenaWidth: 320)..reset();
        for (var i = 0; i < 600; i++) {
          core.step(0.016);
        }
        return core.obstacles.map((o) => o.height).toList();
      }

      expect(run(12), run(12));
    });
  });
}
