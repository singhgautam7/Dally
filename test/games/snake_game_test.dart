import 'dart:math';

import 'package:dally/features/games/snake/logic/snake_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SnakeGame', () {
    test('starts length 3 heading right', () {
      final g = SnakeGame(size: 15, wrap: false, rng: Random(1));
      expect(g.length, 3);
      expect(g.direction, Dir.right);
    });

    test('a plain step keeps the length and moves the head', () {
      final g = SnakeGame(size: 15, wrap: false, rng: Random(1));
      final head0 = g.head;
      final res = g.step();
      expect(res.dead, isFalse);
      expect(res.grew, isFalse);
      expect(g.length, 3);
      expect(g.head, head0 + 1); // moved one column right
    });

    test('cannot reverse straight into itself', () {
      final g = SnakeGame(size: 15, wrap: false, rng: Random(1));
      g.steer(Dir.left); // opposite of right — ignored
      expect(g.direction, Dir.right);
      final res = g.step();
      expect(res.dead, isFalse);
    });

    test('hitting a wall without wrap is a wall death', () {
      final g = SnakeGame(size: 5, wrap: false, rng: Random(1));
      // Head starts near centre heading right; drive into the right wall.
      StepResult res = const StepResult(grew: false, dead: false);
      for (var i = 0; i < 10 && !res.dead; i++) {
        res = g.step();
      }
      expect(res.dead, isTrue);
      expect(res.wall, isTrue);
    });

    test('wrap carries the head to the far side instead of dying', () {
      final g = SnakeGame(size: 5, wrap: true, rng: Random(1));
      var res = const StepResult(grew: false, dead: false);
      for (var i = 0; i < 4; i++) {
        res = g.step();
      }
      // With a 5-wide wrap arena the snake keeps going rather than dying at edge.
      expect(res.wall, isFalse);
    });

    test('eating food grows the snake and moves the food', () {
      final g = SnakeGame(size: 15, wrap: false, rng: Random(1));
      // Force food directly ahead of the head.
      final ahead = g.head + 1;
      _setFood(g, ahead);
      final res = g.step();
      expect(res.grew, isTrue);
      expect(g.length, 4);
      expect(g.food == ahead, isFalse); // relocated
    });
  });

  group('the tail has a cell to slide out of', () {
    // The v5 regression: the painter interpolated every segment from the cell
    // its successor occupies, but the *last* segment has no successor, so it
    // was interpolated from itself — it stood still for a whole tick and then
    // jumped a full cell. That is the flicker. The core now remembers the cell
    // the step vacated, which is the only thing the painter was missing.

    test('a plain step records the cell the tail left', () {
      final g = SnakeGame(size: 9, wrap: false, rng: Random(1));
      final tailBefore = g.snake.last;
      g.step();
      expect(g.prevTail, tailBefore);
      expect(g.snake.contains(g.prevTail), isFalse,
          reason: 'the vacated cell is no longer part of the body');
    });

    test('the tail slides exactly one cell, every tick', () {
      final g = SnakeGame(size: 11, wrap: true, rng: Random(2));
      for (var i = 0; i < 20; i++) {
        final tailBefore = g.snake.last;
        g.step();
        if (g.prevTail == null) continue; // grew: the tail genuinely held still
        final from = g.prevTail!, to = g.snake.last;
        expect(from, tailBefore);
        final dc = (from % 11) - (to % 11);
        final dr = (from ~/ 11) - (to ~/ 11);
        // One orthogonal step, or a wrap across the arena — never a stand-still.
        final steps = dc.abs() + dr.abs();
        expect(steps == 1 || steps == 10, isTrue,
            reason: 'tail moved $from → $to');
      }
    });

    test('growing leaves the tail where it is, and says so', () {
      final g = SnakeGame(size: 9, wrap: false, rng: Random(3));
      // Put the food directly ahead of the head so the next step grows.
      g.food = g.head + 1;
      final tailBefore = g.snake.last;
      final result = g.step();
      expect(result.grew, isTrue);
      expect(g.prevTail, isNull,
          reason: 'nothing was vacated, so the tail has nowhere to slide from');
      expect(g.snake.last, tailBefore);
    });

    test('a reset clears the remembered cell', () {
      final g = SnakeGame(size: 9, wrap: false, rng: Random(4));
      g.step();
      expect(g.prevTail, isNotNull);
      g.reset();
      expect(g.prevTail, isNull);
    });
  });
}

/// Reaches into the game to place food for a deterministic growth test.
void _setFood(SnakeGame g, int index) {
  // `food` is public on the game; set it directly.
  g.food = index;
}
