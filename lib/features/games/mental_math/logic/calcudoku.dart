import '../../../../core/util/dally_random.dart';
import '../../../../core/util/expression.dart';
import '../math_difficulty.dart';

/// One cage: a group of cells that must combine to [target] under [op].
///
/// A single-cell cage has no operator — its target *is* its value.
class Cage {
  const Cage({required this.cells, required this.op, required this.target});

  /// Cell indices, row-major (`row * size + col`), in reading order. The first
  /// entry is the cage's top-left cell, which carries the target label.
  final List<int> cells;

  /// Null for a one-cell cage.
  final MathOp? op;

  final int target;

  int get size => cells.length;

  /// `"12×"`, `"3−"`, `"5"`.
  String get label => op == null ? '$target' : '$target${op!.symbol}';

  /// Whether [values] (in this cage's cell order) satisfy the constraint.
  /// Subtraction and division are order-free — a cage states a difference or a
  /// ratio, so any ordering that produces the target counts.
  bool isSatisfiedBy(List<int> values) {
    if (values.length != cells.length) return false;
    switch (op) {
      case null:
        return values.single == target;
      case MathOp.add:
        return values.fold(0, (a, b) => a + b) == target;
      case MathOp.multiply:
        return values.fold(1, (a, b) => a * b) == target;
      case MathOp.subtract:
        final sorted = [...values]..sort();
        return sorted.last - sorted.first == target;
      case MathOp.divide:
        final sorted = [...values]..sort();
        return sorted.first != 0 &&
            sorted.last % sorted.first == 0 &&
            sorted.last ~/ sorted.first == target;
    }
  }

  /// Cheap pruning while a cage is only partly filled. Returns false only when
  /// the partial assignment already cannot reach the target.
  bool couldStillHold(List<int> partial, int size) {
    if (partial.length == cells.length) return isSatisfiedBy(partial);
    switch (op) {
      case MathOp.add:
        final sum = partial.fold(0, (a, b) => a + b);
        final missing = cells.length - partial.length;
        return sum + missing <= target && sum + missing * size >= target;
      case MathOp.multiply:
        final product = partial.fold(1, (a, b) => a * b);
        return target % product == 0;
      default:
        return true;
    }
  }
}

/// A generated puzzle: the cages, the solution it was built from, and the grid
/// size. A puzzle is only ever returned once an internal solver has confirmed
/// it has **exactly one** solution.
class CalcudokuPuzzle {
  const CalcudokuPuzzle({
    required this.size,
    required this.cages,
    required this.solution,
  });

  final int size;
  final List<Cage> cages;

  /// Row-major solution values, `1 … size`.
  final List<int> solution;

  /// Which cage each cell belongs to, row-major — the painter's index.
  List<int> get cageOfCell {
    final out = List.filled(size * size, 0);
    for (var i = 0; i < cages.length; i++) {
      for (final cell in cages[i].cells) {
        out[cell] = i;
      }
    }
    return out;
  }
}

/// Generates a Calcudoku with a guaranteed unique solution.
///
/// The loop is bounded twice — by [maxAttempts] and by a wall-clock [deadline]
/// — and falls back to a known-good hand-checked 4×4 rather than spinning, so
/// generation can never hang the UI. Callers run it off the UI thread
/// (`compute`) for the larger sizes.
CalcudokuPuzzle generateCalcudoku(
  DallyRandom rng, {
  required int size,
  MathDifficulty difficulty = MathDifficulty.normal,
  int maxAttempts = 40,
  Duration deadline = const Duration(seconds: 3),
}) {
  assert(size >= 3 && size <= 6);
  final started = DateTime.now();

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (DateTime.now().difference(started) > deadline) break;

    final solution = _latinSquare(rng, size);
    final cages = _buildCages(rng, solution, size, difficulty);

    // The whole point: a puzzle with zero or several solutions is discarded.
    if (_countSolutions(cages, size, limit: 2) == 1) {
      return CalcudokuPuzzle(size: size, cages: cages, solution: solution);
    }
  }
  return _fallback4x4;
}

/// A random Latin square, built by shuffling a cyclic base — always valid, so
/// there is no failed-generation path here.
List<int> _latinSquare(DallyRandom rng, int n) {
  final symbols = List<int>.generate(n, (i) => i + 1);
  rng.shuffle(symbols);
  final rowOrder = List<int>.generate(n, (i) => i);
  rng.shuffle(rowOrder);
  final colOrder = List<int>.generate(n, (i) => i);
  rng.shuffle(colOrder);

  final grid = List<int>.filled(n * n, 0);
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      grid[r * n + c] = symbols[(rowOrder[r] + colOrder[c]) % n];
    }
  }
  return grid;
}

/// Grows cages of 1–4 cells by random adjacency, then assigns each an operation
/// that its own values actually satisfy — so the target is correct by
/// construction and never has to be searched for.
List<Cage> _buildCages(
  DallyRandom rng,
  List<int> solution,
  int n,
  MathDifficulty difficulty,
) {
  final assigned = List<int>.filled(n * n, -1);
  final cages = <Cage>[];
  final order = List<int>.generate(n * n, (i) => i);
  rng.shuffle(order);

  // Harder levels lean on larger cages: fewer, longer constraints.
  final maxSize = switch (difficulty) {
    MathDifficulty.easy => 3,
    MathDifficulty.normal => 4,
    MathDifficulty.hard => 4,
  };
  final singleChance = switch (difficulty) {
    MathDifficulty.easy => 0.18,
    MathDifficulty.normal => 0.08,
    MathDifficulty.hard => 0.04,
  };

  for (final seed in order) {
    if (assigned[seed] != -1) continue;
    final cells = <int>[seed];
    assigned[seed] = cages.length;

    final wanted = rng.chance(singleChance) ? 1 : rng.range(2, maxSize);
    while (cells.length < wanted) {
      final candidates = <int>[];
      for (final cell in cells) {
        for (final nb in _neighbours(cell, n)) {
          if (assigned[nb] == -1 && !candidates.contains(nb)) candidates.add(nb);
        }
      }
      if (candidates.isEmpty) break;
      final pick = rng.pick(candidates);
      assigned[pick] = cages.length;
      cells.add(pick);
    }

    cells.sort();
    cages.add(_cageFor(rng, cells, solution));
  }
  return cages;
}

Iterable<int> _neighbours(int cell, int n) sync* {
  final r = cell ~/ n, c = cell % n;
  if (r > 0) yield cell - n;
  if (r < n - 1) yield cell + n;
  if (c > 0) yield cell - 1;
  if (c < n - 1) yield cell + 1;
}

/// Picks an operation the cage's own values satisfy, preferring the ones that
/// constrain the most. Every returned cage is satisfied by the solution.
Cage _cageFor(DallyRandom rng, List<int> cells, List<int> solution) {
  final values = [for (final c in cells) solution[c]];
  if (values.length == 1) {
    return Cage(cells: cells, op: null, target: values.single);
  }

  final options = <(MathOp, int)>[];
  if (values.length == 2) {
    final sorted = [...values]..sort();
    options.add((MathOp.subtract, sorted.last - sorted.first));
    if (sorted.first != 0 && sorted.last % sorted.first == 0) {
      options.add((MathOp.divide, sorted.last ~/ sorted.first));
    }
  }
  options.add((MathOp.add, values.fold(0, (a, b) => a + b)));
  options.add((MathOp.multiply, values.fold(1, (a, b) => a * b)));

  final (op, target) = rng.pick(options);
  return Cage(cells: cells, op: op, target: target);
}

/// Backtracking solver over the Latin constraints plus the cages. Stops as soon
/// as [limit] solutions have been found — the generator only needs to know
/// whether the count is exactly one.
int _countSolutions(List<Cage> cages, int n, {required int limit}) {
  final grid = List<int>.filled(n * n, 0);
  final cageOf = List<int>.filled(n * n, 0);
  for (var i = 0; i < cages.length; i++) {
    for (final cell in cages[i].cells) {
      cageOf[cell] = i;
    }
  }

  var found = 0;

  bool rowOrColClash(int cell, int value) {
    final r = cell ~/ n, c = cell % n;
    for (var i = 0; i < n; i++) {
      if (grid[r * n + i] == value) return true;
      if (grid[i * n + c] == value) return true;
    }
    return false;
  }

  bool cageStillPossible(int cell) {
    final cage = cages[cageOf[cell]];
    final filled = <int>[];
    for (final c in cage.cells) {
      if (grid[c] != 0) filled.add(grid[c]);
    }
    if (filled.length == cage.size) return cage.isSatisfiedBy(filled);
    return cage.couldStillHold(filled, n);
  }

  void search(int cell) {
    if (found >= limit) return;
    if (cell == n * n) {
      found++;
      return;
    }
    for (var v = 1; v <= n; v++) {
      if (rowOrColClash(cell, v)) continue;
      grid[cell] = v;
      if (cageStillPossible(cell)) search(cell + 1);
      grid[cell] = 0;
      if (found >= limit) return;
    }
  }

  search(0);
  return found;
}

/// How many solutions [puzzle] has, capped at [limit]. Exposed so a test can
/// re-verify the uniqueness guarantee independently of generation.
int countSolutionsOf(CalcudokuPuzzle puzzle, {int limit = 2}) =>
    _countSolutions(puzzle.cages, puzzle.size, limit: limit);

/// Hand-checked 4×4 with a single solution, used only if generation is starved.
final CalcudokuPuzzle _fallback4x4 = CalcudokuPuzzle(
  size: 4,
  solution: const [1, 2, 3, 4, 2, 3, 4, 1, 3, 4, 1, 2, 4, 1, 2, 3],
  cages: const [
    Cage(cells: [0, 1], op: MathOp.add, target: 3),
    Cage(cells: [2, 3], op: MathOp.add, target: 7),
    Cage(cells: [4, 8], op: MathOp.add, target: 5),
    Cage(cells: [5, 6], op: MathOp.add, target: 7),
    Cage(cells: [7, 11], op: MathOp.add, target: 3),
    Cage(cells: [9, 10], op: MathOp.add, target: 5),
    Cage(cells: [12, 13], op: MathOp.add, target: 5),
    Cage(cells: [14, 15], op: MathOp.add, target: 5),
  ],
);

/// The two cells that disagree in [grid], or null when nothing conflicts.
/// Only reports a pair once **both** are filled, per the design.
(int, int)? findConflict(List<int> grid, int n) {
  for (var r = 0; r < n; r++) {
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        final ia = r * n + a, ib = r * n + b;
        if (grid[ia] != 0 && grid[ia] == grid[ib]) return (ia, ib);
      }
    }
  }
  for (var c = 0; c < n; c++) {
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        final ia = a * n + c, ib = b * n + c;
        if (grid[ia] != 0 && grid[ia] == grid[ib]) return (ia, ib);
      }
    }
  }
  return null;
}

/// Describes a conflict for the line under the board: "Two 4s in row 2".
String describeConflict(int cellA, int cellB, int n, int value) {
  final ra = cellA ~/ n, rb = cellB ~/ n;
  return ra == rb ? 'Two ${value}s in row ${ra + 1}' : 'Two ${value}s in column ${cellA % n + 1}';
}
