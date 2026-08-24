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

/// Dots & Boxes for two players on one device, on an `n × n` grid of boxes.
///
/// Pure logic: no widgets, no clock, no randomness. The board is addressed by
/// dots at `(row, col)` for `0 <= row, col <= size`, and the boxes between them.
class DotsAndBoxesGame {
  DotsAndBoxesGame({required this.size, int firstPlayer = 0})
      : assert(size >= 2, 'a board needs at least 2 boxes a side'),
        _current = firstPlayer,
        // (size + 1) rows of `size` horizontal edges, and the mirror for vertical.
        _horizontal = List.generate(size + 1, (_) => List.filled(size, false)),
        _vertical = List.generate(size, (_) => List.filled(size + 1, false)),
        _owners = List.generate(size, (_) => List.filled(size, -1));

  /// Boxes per side. 4, 5 or 6 in the shipped setup.
  final int size;

  final List<List<bool>> _horizontal;
  final List<List<bool>> _vertical;
  final List<List<int>> _owners;
  int _current;

  /// Whose turn it is: 0 or 1.
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

  int get totalBoxes => size * size;

  int get claimedBoxes => scoreOf(0) + scoreOf(1);

  bool get isFinished => claimedBoxes == totalBoxes;

  /// The winner, or null on a draw. Only meaningful once [isFinished].
  int? get winner {
    final a = scoreOf(0), b = scoreOf(1);
    if (a == b) return null;
    return a > b ? 0 : 1;
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
        if (edge.row > size || edge.col >= size) return false;
      case EdgeKind.vertical:
        if (edge.row >= size || edge.col > size) return false;
    }
    return !isDrawn(edge);
  }

  List<BoxEdge> get legalMoves => [
        for (var r = 0; r <= size; r++)
          for (var c = 0; c < size; c++)
            if (!_horizontal[r][c]) BoxEdge(EdgeKind.horizontal, r, c),
        for (var r = 0; r < size; r++)
          for (var c = 0; c <= size; c++)
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
    // Closing a box grants another turn; otherwise play passes.
    if (claimed == 0) _current = 1 - _current;
    return MoveResult(claimed: claimed, extraTurn: claimed > 0, finished: finished);
  }

  Iterable<(int, int)> _boxesTouching(BoxEdge edge) sync* {
    switch (edge.kind) {
      case EdgeKind.horizontal:
        if (edge.row > 0) yield (edge.row - 1, edge.col);
        if (edge.row < size) yield (edge.row, edge.col);
      case EdgeKind.vertical:
        if (edge.col > 0) yield (edge.row, edge.col - 1);
        if (edge.col < size) yield (edge.row, edge.col);
    }
  }

  bool _boxComplete(int r, int c) =>
      _horizontal[r][c] && _horizontal[r + 1][c] && _vertical[r][c] && _vertical[r][c + 1];

  /// Snapshot of the drawn edges, for the painter.
  bool horizontalAt(int r, int c) => _horizontal[r][c];
  bool verticalAt(int r, int c) => _vertical[r][c];
}
