import 'dart:math';

import 'package:dally/features/games/minesweeper/logic/minesweeper_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MinesweeperBoard', () {
    test('the first tapped cell and its neighbours are never mined', () {
      for (var seed = 0; seed < 20; seed++) {
        final b = MinesweeperBoard(width: 9, height: 9, mineCount: 10, guessFree: false, rng: Random(seed));
        const first = 40; // centre
        b.revealCell(first);
        expect(b.mine[first], isFalse);
        for (final n in b.neighbours(first)) {
          expect(b.mine[n], isFalse, reason: 'seed $seed neighbour $n');
        }
      }
    });

    test('revealing an empty cell floods a region', () {
      final b = MinesweeperBoard(width: 9, height: 9, mineCount: 1, guessFree: false, rng: Random(1));
      b.revealCell(0);
      final revealed = b.reveal.where((r) => r == CellReveal.revealed).length;
      expect(revealed, greaterThan(1));
    });

    test('hitting a mine reports a mine outcome', () {
      final b = MinesweeperBoard(width: 5, height: 5, mineCount: 5, guessFree: false, rng: Random(2));
      b.revealCell(12); // generate with centre safe
      final mineIdx = b.mine.indexWhere((m) => m);
      expect(mineIdx, isNot(-1));
      expect(b.revealCell(mineIdx), RevealOutcome.mine);
      expect(b.exploded, isTrue);
    });

    test('guess-free Beginner boards are fully solvable without guessing', () {
      for (var seed = 0; seed < 15; seed++) {
        final b = MinesweeperBoard(width: 9, height: 9, mineCount: 10, guessFree: true, rng: Random(seed));
        b.revealCell(40);
        expect(b.solvableFrom(40), isTrue, reason: 'seed $seed');
      }
    });

    test('winning requires every non-mine cell revealed', () {
      final b = MinesweeperBoard(width: 5, height: 5, mineCount: 3, guessFree: false, rng: Random(4));
      b.revealCell(12);
      expect(b.isWon, isFalse);
      for (var i = 0; i < b.cells; i++) {
        if (!b.mine[i]) b.revealCell(i);
      }
      expect(b.isWon, isTrue);
    });
  });
}
