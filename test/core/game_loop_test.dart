import 'package:dally/core/game/game_loop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FixedStepLoop', () {
    test('drains whole steps only, banking the remainder', () {
      var steps = 0;
      final loop = FixedStepLoop(
        step: const Duration(milliseconds: 10),
        onStep: (_) => steps++,
      );
      loop.feed(const Duration(milliseconds: 25));
      expect(steps, 2);
      loop.feed(const Duration(milliseconds: 5));
      expect(steps, 3, reason: 'the banked 5ms plus 5ms makes a third step');
    });

    test('advances identically at 60, 90 and 120 Hz', () {
      int runFor(int hz) {
        var steps = 0;
        final loop = FixedStepLoop(
          step: const Duration(milliseconds: 10),
          onStep: (_) => steps++,
          maxCatchUpSteps: 100,
        );
        final frame = Duration(microseconds: 1000000 ~/ hz);
        for (var i = 0; i < hz; i++) {
          loop.feed(frame);
        }
        return steps;
      }

      // One second of frames is one second of simulation, whatever the panel.
      expect(runFor(60), 99);
      expect(runFor(90), 99);
      expect(runFor(120), 99);
    });

    test('the delta handed to the game is always the fixed step', () {
      final deltas = <double>[];
      final loop = FixedStepLoop(
        step: const Duration(milliseconds: 16),
        onStep: deltas.add,
      );
      loop.feed(const Duration(milliseconds: 33));
      loop.feed(const Duration(milliseconds: 7));
      expect(deltas, everyElement(closeTo(0.016, 1e-9)));
    });

    test('a long stall is capped rather than fast-forwarded', () {
      var steps = 0;
      final loop = FixedStepLoop(
        step: const Duration(milliseconds: 10),
        onStep: (_) => steps++,
        maxCatchUpSteps: 5,
      );
      loop.feed(const Duration(seconds: 30));
      expect(steps, 5);
    });

    test('elapsed time counts only simulated steps', () {
      final loop = FixedStepLoop(
        step: const Duration(milliseconds: 20),
        onStep: (_) {},
        maxCatchUpSteps: 100,
      );
      loop.feed(const Duration(milliseconds: 130));
      expect(loop.elapsedSeconds, closeTo(0.12, 1e-9));
    });

    test('reset clears the accumulator and the clock', () {
      var steps = 0;
      final loop = FixedStepLoop(
        step: const Duration(milliseconds: 10),
        onStep: (_) => steps++,
      );
      loop.feed(const Duration(milliseconds: 15));
      loop.reset();
      expect(loop.elapsedSeconds, 0);
      loop.feed(const Duration(milliseconds: 5));
      expect(steps, 1, reason: 'the banked 5ms was discarded by reset');
    });

    test('zero or negative deltas do nothing', () {
      var steps = 0;
      final loop = FixedStepLoop(
        step: const Duration(milliseconds: 10),
        onStep: (_) => steps++,
      );
      loop.feed(Duration.zero);
      loop.feed(const Duration(milliseconds: -50));
      expect(steps, 0);
    });
  });

  group('alpha — the sub-step progress a render interpolates on', () {
    // Snake slides its body between two grid cells using this. It must come
    // from the accumulated *simulation* time, never from a wall clock, or the
    // slide stutters at a frame rate the loop was not tuned for.

    test('is the fraction of one fixed step banked so far', () {
      final loop = FixedStepLoop(step: const Duration(milliseconds: 100), onStep: (_) {});
      expect(loop.alpha, 0);
      loop.feed(const Duration(milliseconds: 25));
      expect(loop.alpha, closeTo(0.25, 1e-9));
      loop.feed(const Duration(milliseconds: 50));
      expect(loop.alpha, closeTo(0.75, 1e-9));
      // Crossing a whole step drains it and leaves the remainder.
      loop.feed(const Duration(milliseconds: 50));
      expect(loop.alpha, closeTo(0.25, 1e-9));
    });

    test('the same wall time in different frame sizes lands on the same alpha',
        () {
      double alphaAfter(Duration frame, int frames) {
        final loop = FixedStepLoop(step: const Duration(milliseconds: 16), onStep: (_) {});
        for (var i = 0; i < frames; i++) {
          loop.feed(frame);
        }
        return loop.alpha;
      }

      // 240ms of run at 60, 120 and 240 Hz.
      final at60 = alphaAfter(const Duration(microseconds: 16667), 15);
      final at120 = alphaAfter(const Duration(microseconds: 8333), 30);
      final at240 = alphaAfter(const Duration(microseconds: 4167), 60);
      expect(at60, closeTo(at120, 0.02));
      expect(at60, closeTo(at240, 0.02));
    });

    test('never leaves the 0…1 range a lerp can use', () {
      final loop = FixedStepLoop(step: const Duration(milliseconds: 16), onStep: (_) {});
      for (final ms in [0, 1, 15, 16, 17, 100, 5000]) {
        loop.feed(Duration(milliseconds: ms));
        expect(loop.alpha, inInclusiveRange(0, 1), reason: 'after ${ms}ms');
      }
    });
  });
}
