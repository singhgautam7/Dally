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
}

/// Reaches into the game to place food for a deterministic growth test.
void _setFood(SnakeGame g, int index) {
  // `food` is public on the game; set it directly.
  g.food = index;
}
