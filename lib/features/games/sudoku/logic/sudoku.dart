import 'dart:math';

/// Sudoku difficulty, defined by how many clues (givens) remain. Fewer clues =
/// harder. Grading by clue count is a pragmatic proxy for v1.
enum SudokuDifficulty {
  beginner('Beginner', 44),
  easy('Easy', 38),
  medium('Medium', 32),
  hard('Hard', 28),
  master('Master', 24);

  const SudokuDifficulty(this.label, this.clues);
  final String label;
  final int clues;
}

/// A generated puzzle: the [givens] (0 = blank) and its unique [solution].
class SudokuPuzzle {
  const SudokuPuzzle({required this.givens, required this.solution});
  final List<int> givens;
  final List<int> solution;
}

/// Pure Sudoku engine: a randomised full-grid generator, a uniqueness-checking
/// solver, and a difficulty-graded puzzle generator. Seedable for reproducible,
/// testable puzzles. Grid is 81 cells row-major, 0 = empty.
class Sudoku {
  Sudoku({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  static const int n = 9;

  bool _valid(List<int> g, int idx, int v) {
    final r = idx ~/ n, c = idx % n;
    for (var i = 0; i < n; i++) {
      if (g[r * n + i] == v) return false;
      if (g[i * n + c] == v) return false;
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (var dr = 0; dr < 3; dr++) {
      for (var dc = 0; dc < 3; dc++) {
        if (g[(br + dr) * n + bc + dc] == v) return false;
      }
    }
    return true;
  }

  /// Fills [g] completely with a valid solution via randomised backtracking.
  bool _fill(List<int> g, int pos) {
    if (pos == 81) return true;
    if (g[pos] != 0) return _fill(g, pos + 1);
    final candidates = [for (var v = 1; v <= 9; v++) v]..shuffle(_rng);
    for (final v in candidates) {
      if (_valid(g, pos, v)) {
        g[pos] = v;
        if (_fill(g, pos + 1)) return true;
        g[pos] = 0;
      }
    }
    return false;
  }

  /// Counts solutions of [g] up to [limit] (uses MRV for speed).
  int countSolutions(List<int> g, {int limit = 2}) {
    final work = List<int>.from(g);
    var count = 0;
    void solve() {
      if (count >= limit) return;
      // Find the empty cell with the fewest candidates.
      var best = -1;
      List<int>? bestCands;
      for (var i = 0; i < 81; i++) {
        if (work[i] != 0) continue;
        final cands = [for (var v = 1; v <= 9; v++) if (_valid(work, i, v)) v];
        if (cands.isEmpty) return; // dead end
        if (bestCands == null || cands.length < bestCands.length) {
          best = i;
          bestCands = cands;
          if (cands.length == 1) break;
        }
      }
      if (best == -1) {
        count++; // no empties → a full solution
        return;
      }
      for (final v in bestCands!) {
        work[best] = v;
        solve();
        work[best] = 0;
        if (count >= limit) return;
      }
    }

    solve();
    return count;
  }

  /// A full valid grid.
  List<int> fullGrid() {
    final g = List<int>.filled(81, 0);
    _fill(g, 0);
    return g;
  }

  /// Generates a puzzle for [difficulty] with a guaranteed unique solution.
  SudokuPuzzle generate(SudokuDifficulty difficulty) {
    final solution = fullGrid();
    final puzzle = List<int>.from(solution);
    final order = [for (var i = 0; i < 81; i++) i]..shuffle(_rng);
    var clues = 81;
    for (final idx in order) {
      if (clues <= difficulty.clues) break;
      final backup = puzzle[idx];
      if (backup == 0) continue;
      puzzle[idx] = 0;
      // Keep the removal only if the puzzle stays uniquely solvable.
      if (countSolutions(puzzle) != 1) {
        puzzle[idx] = backup;
      } else {
        clues--;
      }
    }
    return SudokuPuzzle(givens: puzzle, solution: solution);
  }

  /// Whether [v] can be placed at [idx] of [g] without breaking a row/col/box.
  bool canPlace(List<int> g, int idx, int v) => _valid(g, idx, v);

  /// The cells that conflict with the value at [idx] (same row/col/box, equal
  /// value). Empty when there's no conflict.
  static Set<int> conflicts(List<int> g, int idx) {
    final v = g[idx];
    if (v == 0) return const {};
    final r = idx ~/ n, c = idx % n;
    final out = <int>{};
    for (var i = 0; i < n; i++) {
      final row = r * n + i, col = i * n + c;
      if (row != idx && g[row] == v) out.add(row);
      if (col != idx && g[col] == v) out.add(col);
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (var dr = 0; dr < 3; dr++) {
      for (var dc = 0; dc < 3; dc++) {
        final b = (br + dr) * n + bc + dc;
        if (b != idx && g[b] == v) out.add(b);
      }
    }
    return out;
  }
}
