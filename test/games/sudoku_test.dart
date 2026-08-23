import 'dart:math';

import 'package:dally/features/games/sudoku/logic/sudoku.dart';
import 'package:flutter_test/flutter_test.dart';

bool isValidComplete(List<int> g) {
  for (var r = 0; r < 9; r++) {
    final row = <int>{}, col = <int>{};
    for (var c = 0; c < 9; c++) {
      if (!row.add(g[r * 9 + c]) || !col.add(g[c * 9 + r])) return false;
    }
    if (row.length != 9 || col.length != 9) return false;
  }
  for (var br = 0; br < 9; br += 3) {
    for (var bc = 0; bc < 9; bc += 3) {
      final box = <int>{};
      for (var dr = 0; dr < 3; dr++) {
        for (var dc = 0; dc < 3; dc++) {
          box.add(g[(br + dr) * 9 + bc + dc]);
        }
      }
      if (box.length != 9) return false;
    }
  }
  return true;
}

void main() {
  group('Sudoku', () {
    test('fullGrid produces a valid complete solution', () {
      final s = Sudoku(rng: Random(1));
      for (var seed = 0; seed < 5; seed++) {
        expect(isValidComplete(Sudoku(rng: Random(seed)).fullGrid()), isTrue);
      }
      expect(s, isNotNull);
    });

    test('countSolutions is 1 for a full grid and >1 for an empty grid', () {
      final s = Sudoku(rng: Random(3));
      final full = s.fullGrid();
      expect(s.countSolutions(full), 1);
      expect(s.countSolutions(List<int>.filled(81, 0)), greaterThan(1));
    });

    test('generated puzzles have a unique solution matching their solution', () {
      for (final d in [SudokuDifficulty.beginner, SudokuDifficulty.medium, SudokuDifficulty.master]) {
        final s = Sudoku(rng: Random(d.index + 10));
        final p = s.generate(d);
        expect(s.countSolutions(p.givens), 1, reason: '${d.label} uniqueness');
        expect(isValidComplete(p.solution), isTrue, reason: '${d.label} solution valid');
        // Givens must agree with the solution.
        for (var i = 0; i < 81; i++) {
          if (p.givens[i] != 0) expect(p.givens[i], p.solution[i]);
        }
      }
    });

    test('harder difficulties keep no more clues than easier ones', () {
      final s = Sudoku(rng: Random(7));
      final easy = s.generate(SudokuDifficulty.beginner).givens.where((v) => v != 0).length;
      final hard = s.generate(SudokuDifficulty.master).givens.where((v) => v != 0).length;
      expect(hard, lessThanOrEqualTo(easy));
    });

    test('conflicts finds same-value peers', () {
      final g = List<int>.filled(81, 0);
      g[0] = 5; // r0c0
      g[1] = 5; // r0c1 — same row, conflict
      expect(Sudoku.conflicts(g, 0), contains(1));
      expect(Sudoku.conflicts(g, 1), contains(0));
    });
  });
}
