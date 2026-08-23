import 'dart:math';

import 'package:dally/features/games/game_2048/logic/board_2048.dart';
import 'package:flutter_test/flutter_test.dart';

Board2048 boardWith(List<int> values, {int size = 4, int score = 0, int seed = 1}) {
  final b = Board2048(size: size, rng: Random(seed));
  b.loadValues(values, score);
  return b;
}

void main() {
  group('Board2048 merges', () {
    test('two equal tiles merge into one, scoring the sum', () {
      final b = boardWith([
        2, 2, 0, 0, //
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);
      final res = b.apply(Move2048.left);
      expect(res.moved, isTrue);
      expect(res.gained, 4);
      expect(b.at(0, 0)!.value, 4);
      expect(b.score, 4);
    });

    test('a tile merges at most once per move (no triple)', () {
      final b = boardWith([
        2, 2, 2, 0, //
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);
      final res = b.apply(Move2048.left);
      expect(b.at(0, 0)!.value, 4);
      expect(b.at(0, 1)!.value, 2);
      expect(res.gained, 4);
    });

    test('four equal tiles make two pairs', () {
      final b = boardWith([
        2, 2, 2, 2, //
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);
      final res = b.apply(Move2048.left);
      expect(b.at(0, 0)!.value, 4);
      expect(b.at(0, 1)!.value, 4);
      expect(res.gained, 8);
    });

    test('right move settles against the right edge', () {
      final b = boardWith([
        2, 2, 0, 0, //
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);
      b.apply(Move2048.right);
      expect(b.at(0, 3)!.value, 4);
    });

    test('a no-op move does not shift or spawn', () {
      final b = boardWith([
        2, 4, 2, 4, //
        4, 2, 4, 2,
        2, 4, 2, 4,
        4, 2, 4, 2,
      ]);
      final res = b.apply(Move2048.left);
      expect(res.moved, isFalse);
      expect(res.gained, 0);
    });
  });

  group('Board2048 state', () {
    test('a fresh game spawns exactly two tiles', () {
      final b = Board2048(size: 4, rng: Random(7))..start();
      expect(b.tiles, hasLength(2));
      expect(b.score, 0);
    });

    test('spawned values are only 2 or 4', () {
      final b = Board2048(size: 4, rng: Random(3))..start();
      for (final t in b.tiles) {
        expect(t.value == 2 || t.value == 4, isTrue);
      }
    });

    test('a moving board spawns one new tile', () {
      final b = boardWith([
        2, 2, 0, 0, //
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);
      final before = b.tiles.length; // 2 tiles
      b.apply(Move2048.left); // merges to 1, then spawns 1 → 2
      expect(b.tiles.length, before);
    });

    test('game over when full with no adjacent equals', () {
      final b = boardWith([
        2, 4, 2, 4, //
        4, 2, 4, 2,
        2, 4, 2, 4,
        4, 2, 4, 2,
      ]);
      expect(b.isGameOver, isTrue);
    });

    test('not game over when a merge is still possible', () {
      final b = boardWith([
        2, 2, 2, 4, //
        4, 2, 4, 2,
        2, 4, 2, 4,
        4, 2, 4, 2,
      ]);
      expect(b.isGameOver, isFalse);
    });

    test('deterministic under a fixed seed', () {
      final a = Board2048(size: 4, rng: Random(42))..start();
      final b = Board2048(size: 4, rng: Random(42))..start();
      for (final m in [Move2048.left, Move2048.up, Move2048.right, Move2048.down]) {
        a.apply(m);
        b.apply(m);
      }
      expect(a.toValues(), b.toValues());
    });
  });
}
