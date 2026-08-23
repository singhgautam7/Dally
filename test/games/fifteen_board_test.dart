import 'dart:math';

import 'package:dally/features/games/fifteen_puzzle/logic/fifteen_board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts inversions to decide solvability, independent of the shuffle method.
bool isSolvable(List<int> cells, int size) {
  final tiles = [for (final v in cells) if (v != 0) v];
  var inversions = 0;
  for (var i = 0; i < tiles.length; i++) {
    for (var j = i + 1; j < tiles.length; j++) {
      if (tiles[i] > tiles[j]) inversions++;
    }
  }
  if (size.isOdd) return inversions.isEven;
  final blankRowFromBottom = size - (cells.indexOf(0) ~/ size);
  return blankRowFromBottom.isEven ? inversions.isOdd : inversions.isEven;
}

void main() {
  group('FifteenBoard', () {
    test('fresh board is solved', () {
      final b = FifteenBoard(size: 4);
      expect(b.isSolved, isTrue);
    });

    test('shuffle produces an unsolved but solvable position', () {
      for (final size in [3, 4, 5]) {
        for (var seed = 0; seed < 20; seed++) {
          final b = FifteenBoard(size: size, rng: Random(seed))..shuffle();
          expect(b.isSolved, isFalse, reason: 'size $size seed $seed');
          expect(isSolvable(b.cells, size), isTrue, reason: 'size $size seed $seed');
        }
      }
    });

    test('shuffle resets the move counter', () {
      final b = FifteenBoard(size: 4, rng: Random(1))..shuffle();
      expect(b.moves, 0);
    });

    test('tapping a tile next to the gap slides it and counts a move', () {
      final b = FifteenBoard(size: 3);
      // Solved 3x3: [1,2,3,4,5,6,7,8,0]. Tap tile 8 (index 7) into the gap (8).
      final shifted = b.tapAt(7);
      expect(shifted, 1);
      expect(b.moves, 1);
      expect(b.cells[8], 8);
      expect(b.cells[7], 0);
    });

    test('tapping a tile not in the gap row/col does nothing', () {
      final b = FifteenBoard(size: 3);
      // Tile 1 (index 0) is not in row/col of the gap (index 8).
      final shifted = b.tapAt(0);
      expect(shifted, 0);
      expect(b.moves, 0);
    });

    test('sliding a whole row shifts every tile between tile and gap', () {
      final b = FifteenBoard(size: 3);
      // Gap at index 8 (row 2, col 2). Tap tile at index 6 (row 2, col 0):
      // whole bottom row shifts right by one.
      final shifted = b.tapAt(6);
      expect(shifted, 2);
      expect(b.cells[6], 0);
      expect(b.cells[7], 7);
      expect(b.cells[8], 8);
      expect(b.moves, 1);
    });

    test('solving from a scramble is reachable', () {
      final b = FifteenBoard(size: 3, rng: Random(5))..shuffle(steps: 50);
      expect(isSolvable(b.cells, 3), isTrue);
    });
  });
}
