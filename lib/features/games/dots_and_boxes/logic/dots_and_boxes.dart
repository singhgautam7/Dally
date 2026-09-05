/// Which way an edge runs. An edge is addressed by its orientation plus the
/// row/column of the dot at its top or left end.
enum EdgeKind { horizontal, vertical }

/// One drawable line on the board.
class BoxEdge {
  const BoxEdge(this.kind, this.row, this.col);

  final EdgeKind kind;
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is BoxEdge && other.kind == kind && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(kind, row, col);

  @override
  String toString() => '${kind.name}($row,$col)';
}

/// The outcome of one move.
class MoveResult {
  const MoveResult({required this.claimed, required this.extraTurn, required this.finished});

  /// How many boxes that single line closed — 0, 1, or 2.
  final int claimed;

  /// Closing a box grants another turn.
  final bool extraTurn;

  final bool finished;
}

/// Dots & Boxes for two to four players on one device, on a `cols × rows` grid
/// of boxes.
///
/// **Rows and columns are independent** (3–12 each, either way round): a 10 × 6
/// and a 6 × 10 are both legal boards, not two views of one. Nothing here
/// assumes a square, which is what let the shared board fitter replace the
/// hand-tuned constant the square version carried.
///
/// Pure logic: no widgets, no clock, no randomness. The board is addressed by
/// dots at `(row, col)` for `0 <= row <= rows`, `0 <= col <= cols`, and the
/// boxes between them.
class DotsAndBoxesGame {
  DotsAndBoxesGame({
    required this.cols,
    required this.rows,
    this.playerCount = 2,
    int firstPlayer = 0,
  })  : assert(cols >= 2 && rows >= 2, 'a board needs at least 2 boxes a side'),
        assert(playerCount >= 2 && playerCount <= 4),
        assert(firstPlayer >= 0 && firstPlayer < playerCount),
        _current = firstPlayer,
        // (rows + 1) rows of `cols` horizontal edges, and the mirror for vertical.
        _horizontal = List.generate(rows + 1, (_) => List.filled(cols, false)),
        _vertical = List.generate(rows, (_) => List.filled(cols + 1, false)),
        _owners = List.generate(rows, (_) => List.filled(cols, -1));

  /// Boxes across.
  final int cols;

  /// Boxes down.
  final int rows;

  /// Seats at the table, 2–4. Turn order is seat order.
  final int playerCount;

  final List<List<bool>> _horizontal;
  final List<List<bool>> _vertical;
  final List<List<int>> _owners;
  int _current;

  /// Whose turn it is, as a seat index.
  int get currentPlayer => _current;

  /// Box owner at `(row, col)`, or -1 while unclaimed.
  int ownerAt(int row, int col) => _owners[row][col];

  int scoreOf(int player) {
    var n = 0;
    for (final row in _owners) {
      for (final o in row) {
        if (o == player) n++;
      }
    }
    return n;
  }

  int get totalBoxes => cols * rows;

  int get claimedBoxes {
    var n = 0;
    for (final row in _owners) {
      for (final o in row) {
        if (o != -1) n++;
      }
    }
    return n;
  }

  bool get isFinished => claimedBoxes == totalBoxes;

  /// Every seat on the top score. One entry is a winner; more than one is a
  /// tie, which is declared as a tie rather than broken. Only meaningful once
  /// [isFinished].
  List<int> get leaders {
    final scores = [for (var p = 0; p < playerCount; p++) scoreOf(p)];
    final top = scores.reduce((a, b) => a > b ? a : b);
    return [for (var p = 0; p < playerCount; p++) if (scores[p] == top) p];
  }

  /// The sole winner, or null when the game is tied.
  int? get winner {
    final top = leaders;
    return top.length == 1 ? top.first : null;
  }

  bool isDrawn(BoxEdge edge) => switch (edge.kind) {
        EdgeKind.horizontal => _horizontal[edge.row][edge.col],
        EdgeKind.vertical => _vertical[edge.row][edge.col],
      };

  /// True when [edge] is on the board and not already drawn.
  bool isLegal(BoxEdge edge) {
    if (edge.row < 0 || edge.col < 0) return false;
    switch (edge.kind) {
      case EdgeKind.horizontal:
        if (edge.row > rows || edge.col >= cols) return false;
      case EdgeKind.vertical:
        if (edge.row >= rows || edge.col > cols) return false;
    }
    return !isDrawn(edge);
  }

  List<BoxEdge> get legalMoves => [
        for (var r = 0; r <= rows; r++)
          for (var c = 0; c < cols; c++)
            if (!_horizontal[r][c]) BoxEdge(EdgeKind.horizontal, r, c),
        for (var r = 0; r < rows; r++)
          for (var c = 0; c <= cols; c++)
            if (!_vertical[r][c]) BoxEdge(EdgeKind.vertical, r, c),
      ];

  /// Draws [edge] for the current player. Returns null when the move is not
  /// legal, leaving the board untouched.
  MoveResult? play(BoxEdge edge) {
    if (isFinished || !isLegal(edge)) return null;
    switch (edge.kind) {
      case EdgeKind.horizontal:
        _horizontal[edge.row][edge.col] = true;
      case EdgeKind.vertical:
        _vertical[edge.row][edge.col] = true;
    }

    // A line can only ever close the one or two boxes it borders.
    var claimed = 0;
    for (final (r, c) in _boxesTouching(edge)) {
      if (_owners[r][c] == -1 && _boxComplete(r, c)) {
        _owners[r][c] = _current;
        claimed++;
      }
    }

    final finished = isFinished;
    // Closing a box grants another turn; otherwise play passes to the next seat.
    if (claimed == 0) _current = (_current + 1) % playerCount;
    return MoveResult(claimed: claimed, extraTurn: claimed > 0, finished: finished);
  }

  Iterable<(int, int)> _boxesTouching(BoxEdge edge) sync* {
    switch (edge.kind) {
      case EdgeKind.horizontal:
        if (edge.row > 0) yield (edge.row - 1, edge.col);
        if (edge.row < rows) yield (edge.row, edge.col);
      case EdgeKind.vertical:
        if (edge.col > 0) yield (edge.row, edge.col - 1);
        if (edge.col < cols) yield (edge.row, edge.col);
    }
  }

  bool _boxComplete(int r, int c) =>
      _horizontal[r][c] && _horizontal[r + 1][c] && _vertical[r][c] && _vertical[r][c + 1];

  /// Snapshot of the drawn edges, for the painter.
  bool horizontalAt(int r, int c) => _horizontal[r][c];
  bool verticalAt(int r, int c) => _vertical[r][c];

  // ── Snapshots (undo) ──────────────────────────────────────────────────────

  /// One step back is one line, plus any boxes it closed and the turn it took.
  /// Ownership and the turn cannot be inferred from the line alone, so undo
  /// restores a snapshot.
  DotsSnapshot snapshot() => DotsSnapshot(
        horizontal: [for (final r in _horizontal) List<bool>.from(r)],
        vertical: [for (final r in _vertical) List<bool>.from(r)],
        owners: [for (final r in _owners) List<int>.from(r)],
        current: _current,
      );

  void restore(DotsSnapshot s) {
    for (var r = 0; r < _horizontal.length; r++) {
      _horizontal[r].setAll(0, s.horizontal[r]);
    }
    for (var r = 0; r < _vertical.length; r++) {
      _vertical[r].setAll(0, s.vertical[r]);
    }
    for (var r = 0; r < _owners.length; r++) {
      _owners[r].setAll(0, s.owners[r]);
    }
    _current = s.current;
  }
}

/// One restorable Dots & Boxes position.
class DotsSnapshot {
  const DotsSnapshot({
    required this.horizontal,
    required this.vertical,
    required this.owners,
    required this.current,
  });

  final List<List<bool>> horizontal;
  final List<List<bool>> vertical;
  final List<List<int>> owners;
  final int current;
}
