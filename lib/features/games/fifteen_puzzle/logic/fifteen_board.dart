import 'dart:math';

/// A sliding-tile puzzle of side [size]. Cells hold 1..n²-1 with 0 as the blank.
/// Shuffling is done by random legal moves from the solved state, which
/// guarantees the position is always solvable.
class FifteenBoard {
  FifteenBoard({required this.size, Random? rng})
      : _rng = rng ?? Random(),
        cells = List<int>.generate(size * size, (i) => (i + 1) % (size * size));

  final int size;
  final Random _rng;

  /// Row-major cells; 0 is the blank.
  List<int> cells;

  int moves = 0;

  int get _blank => cells.indexOf(0);

  int rowOf(int index) => index ~/ size;
  int colOf(int index) => index % size;

  bool get isSolved {
    for (var i = 0; i < cells.length - 1; i++) {
      if (cells[i] != i + 1) return false;
    }
    return cells.last == 0;
  }

  /// Resets to solved then shuffles with [steps] random legal moves (never
  /// leaving the board solved).
  void shuffle({int? steps}) {
    cells = List<int>.generate(size * size, (i) => (i + 1) % (size * size));
    moves = 0;
    final n = steps ?? size * size * 20;
    var last = -1;
    for (var i = 0; i < n; i++) {
      final options = _blankNeighbours().where((p) => p != last).toList();
      final pick = options[_rng.nextInt(options.length)];
      last = _blank;
      _swap(pick, _blank);
    }
    // Guard against an accidental solved shuffle.
    if (isSolved) shuffle(steps: steps);
    moves = 0;
  }

  List<int> _blankNeighbours() {
    final b = _blank;
    final r = rowOf(b), c = colOf(b);
    final out = <int>[];
    if (r > 0) out.add(b - size);
    if (r < size - 1) out.add(b + size);
    if (c > 0) out.add(b - 1);
    if (c < size - 1) out.add(b + 1);
    return out;
  }

  void _swap(int a, int b) {
    final tmp = cells[a];
    cells[a] = cells[b];
    cells[b] = tmp;
  }

  /// Attempts to slide the tile at [index] toward the blank. Supports sliding a
  /// whole row/column: tapping any tile in the blank's row or column shifts the
  /// tiles between it and the blank. Returns the number of tiles that moved (0
  /// if the tap wasn't a legal slide). Counts as one [moves] increment.
  int tapAt(int index) {
    if (cells[index] == 0) return 0;
    final b = _blank;
    final br = rowOf(b), bc = colOf(b);
    final tr = rowOf(index), tc = colOf(index);

    var shifted = 0;
    if (tr == br) {
      final step = tc < bc ? 1 : -1;
      var pos = b;
      while (pos != index) {
        final next = pos - step;
        _swap(pos, next);
        pos = next;
        shifted++;
      }
    } else if (tc == bc) {
      final step = tr < br ? size : -size;
      var pos = b;
      while (pos != index) {
        final next = pos - step;
        _swap(pos, next);
        pos = next;
        shifted++;
      }
    }
    if (shifted > 0) moves++;
    return shifted;
  }
}
