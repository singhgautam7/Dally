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
}
