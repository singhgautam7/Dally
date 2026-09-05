/// The four directions a line can run in. Vertical is the one a player forgets;
/// both diagonals are the one a *rules engine* forgets, which is why they are
/// enumerated rather than special-cased.
const List<(int, int)> kLineDirections = [
  (0, 1), // across
  (1, 0), // down
  (1, 1), // down-right
  (1, -1), // down-left
];

/// A completed line: the cells that made it, in board order.
class WinLine {
  const WinLine(this.cells);

  /// Row-major `(row, col)` pairs, exactly [FourInARowGame.target] of them.
  final List<(int, int)> cells;

  bool contains(int row, int col) =>
      cells.any((c) => c.$1 == row && c.$2 == col);
}

/// Four-in-a-Row. Drop a disc down a column; it falls to the lowest free slot.
/// Four in a line — up, across or either diagonal — wins. A full board with no
/// line is a draw, declared on the last drop.
///
/// Pure rules: no widgets, no clock, no randomness. The grid is configurable
/// (7 × 6 by default, 6 × 5 and 8 × 7 offered) and the target is always four.
class FourInARowGame {
  FourInARowGame({required this.cols, required this.rows, int firstPlayer = 0})
      : assert(cols >= 4 && rows >= 4, 'four in a row needs four of each'),
        assert(firstPlayer == 0 || firstPlayer == 1),
        _current = firstPlayer,
        _cells = List.generate(rows, (_) => List.filled(cols, -1));

  /// Columns across and rows down.
  final int cols;
  final int rows;

  /// Discs in a line to win. Always four, at every board size.
  static const int target = 4;

  /// Row 0 is the **top**; a disc falls toward the highest row index.
  final List<List<int>> _cells;
  int _current;
  int _discs = 0;
  WinLine? _win;

  int get currentPlayer => _current;
  int get discs => _discs;
  WinLine? get winLine => _win;
  int? get winner => _win == null ? null : ownerAt(_win!.cells.first.$1, _win!.cells.first.$2);

  /// Owner of a cell, or -1 when empty.
  int ownerAt(int row, int col) => _cells[row][col];

  bool get isFull => _discs == cols * rows;

  /// A full board with no line. Only meaningful once [isOver].
  bool get isDrawn => _win == null && isFull;

  bool get isOver => _win != null || isFull;

  /// A column takes a disc while it is on the board and not yet full.
  bool canDrop(int col) {
    if (isOver || col < 0 || col >= cols) return false;
    return _cells[0][col] == -1;
  }

  /// The row a disc dropped into [col] would land in, or null when the column
  /// is full. The board is the authority on this, never the painter.
  int? landingRow(int col) {
    if (col < 0 || col >= cols) return null;
    for (var r = rows - 1; r >= 0; r--) {
      if (_cells[r][col] == -1) return r;
    }
    return null;
  }

  /// Drops a disc for the player on turn. Returns the row it settled in, or
  /// null when the move was refused — in which case nothing changed.
  int? drop(int col) {
    if (!canDrop(col)) return null;
    final row = landingRow(col);
    if (row == null) return null;
    _cells[row][col] = _current;
    _discs++;
    _win = _lineThrough(row, col);
    if (_win == null) _current = 1 - _current;
    return row;
  }

  /// The winning line through the disc just played, or null. Only the last
  /// disc can complete a line, so the whole board is never rescanned.
  WinLine? _lineThrough(int row, int col) {
    final player = _cells[row][col];
    for (final (dr, dc) in kLineDirections) {
      final cells = <(int, int)>[(row, col)];
      // Walk both ways along the direction.
      for (final sign in const [1, -1]) {
        var r = row + dr * sign, c = col + dc * sign;
        while (r >= 0 && r < rows && c >= 0 && c < cols && _cells[r][c] == player) {
          sign == 1 ? cells.add((r, c)) : cells.insert(0, (r, c));
          r += dr * sign;
          c += dc * sign;
        }
      }
      if (cells.length >= target) {
        // Exactly the four that include the new disc, in board order.
        final start = cells.indexWhere((p) => p.$1 == row && p.$2 == col);
        final from = (start - (target - 1)).clamp(0, cells.length - target);
        return WinLine(cells.sublist(from, from + target));
      }
    }
    return null;
  }

  // ── Snapshots (undo) ──────────────────────────────────────────────────────

  /// One step back is the last disc, plus the turn it took. The win line goes
  /// with it, though in practice a finished board clears the stack.
  FourSnapshot snapshot() => FourSnapshot(
        cells: [for (final r in _cells) List<int>.from(r)],
        current: _current,
        discs: _discs,
        win: _win,
      );

  void restore(FourSnapshot s) {
    for (var r = 0; r < rows; r++) {
      _cells[r].setAll(0, s.cells[r]);
    }
    _current = s.current;
    _discs = s.discs;
    _win = s.win;
  }
}

/// One restorable Four-in-a-Row position.
class FourSnapshot {
  const FourSnapshot({
    required this.cells,
    required this.current,
    required this.discs,
    required this.win,
  });

  final List<List<int>> cells;
  final int current;
  final int discs;
  final WinLine? win;
}
