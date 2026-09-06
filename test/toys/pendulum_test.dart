import 'dart:math' as math;

import 'package:dally/features/toys/double_pendulum/logic/pendulum.dart';
import 'package:flutter_test/flutter_test.dart';

/// The integrator is pure and driven at the fixed step, so nothing here touches
/// a clock or a widget tree.
void main() {
  const dt = 1 / 62.5;

  group('the pendulum integrator is stable', () {
    test('energy holds over a long run', () {
      final p = DoublePendulum(angle1: 2.2, angle2: 1.1);
      final start = p.energy;
      for (var i = 0; i < 60000; i++) {
        p.step(dt);
      }
      // Sixteen minutes of simulated swinging. An Euler step would have gained
      // many multiples of this by now; RK4 with a whisper of damping only ever
      // loses a little.
      expect(p.energy.isFinite, isTrue);
      expect(p.energy, lessThanOrEqualTo(start + 0.01));
      expect(p.angle1.isFinite && p.angle2.isFinite, isTrue);
      expect(p.velocity1.abs(), lessThan(60), reason: 'the arms did not fling');
    });

    test('a pendulum hanging straight down stays there', () {
      final p = DoublePendulum(angle1: 0, angle2: 0);
      for (var i = 0; i < 2000; i++) {
        p.step(dt);
      }
      expect(p.angle1.abs(), lessThan(1e-6));
      expect(p.angle2.abs(), lessThan(1e-6));
    });

    test('it actually swings when it is let go from the side', () {
      final p = DoublePendulum(angle1: math.pi / 2, angle2: math.pi / 2);
      final start = p.angle1;
      for (var i = 0; i < 30; i++) {
        p.step(dt);
      }
      expect(p.angle1, isNot(closeTo(start, 1e-6)));
    });

    test('the trail fades out of the far end rather than growing forever', () {
      final p = DoublePendulum(angle1: 2, angle2: 1);
      for (var i = 0; i < 3000; i++) {
        p.step(dt, trailLimit: DoublePendulum.shortTrail);
      }
      expect(p.trail.length, DoublePendulum.shortTrail);
      for (var i = 0; i < 3000; i++) {
        p.step(dt, trailLimit: DoublePendulum.longTrail);
      }
      expect(p.trail.length, DoublePendulum.longTrail);
    });

    test('reset is clean: posed, stopped, and no trail left', () {
      final p = DoublePendulum(angle1: 2, angle2: 1);
      for (var i = 0; i < 500; i++) {
        p.step(dt);
      }
      p.reset();
      expect(p.trail, isEmpty);
      expect(p.velocity1, 0);
      expect(p.velocity2, 0);
      expect(p.angle1, closeTo(math.pi / 2, 1e-9));
    });

    test('the same start gives the same motion — nothing here is random', () {
      List<double> run() {
        final p = DoublePendulum(angle1: 1.7, angle2: 0.4);
        final out = <double>[];
        for (var i = 0; i < 500; i++) {
          p.step(dt);
          out.add(p.angle1);
        }
        return out;
      }

      expect(run(), run());
    });

    test('dragging grabs the nearer bob and releases a physical pose', () {
      final p = DoublePendulum();
      // A point right on the tip must grab the tip, not the joint.
      expect(p.grabsTip(p.tip), isTrue);
      expect(p.grabsTip(p.joint), isFalse);

      p.velocity1 = 9;
      p.dragTo((0.5, 0.5), grabbedTip: false);
      expect(p.velocity1, 0, reason: 'a released pose starts from rest');
      expect(p.velocity2, 0);
      expect(p.energy.isFinite, isTrue);
    });

    test('the motion is the same physics at a different rate, not a coarser one',
        () {
      // Speed multiplies simulated time; halving the step and doubling the
      // count must land in the same place.
      double after(double step, int count) {
        final p = DoublePendulum(angle1: 1.2, angle2: 0.6);
        for (var i = 0; i < count; i++) {
          p.step(step);
        }
        return p.angle1;
      }

      expect(after(dt, 200), closeTo(after(dt / 2, 400), 0.02));
    });
  });
}
