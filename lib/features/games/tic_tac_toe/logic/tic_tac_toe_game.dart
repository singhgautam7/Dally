/// Marks. 0 = empty, 1 = X (player 1), 2 = O (player 2).
class Ttt {
  static const int empty = 0;
  static const int x = 1;
  static const int o = 2;
}

/// The outcome of a finished board.
class TttResult {
  const TttResult({required this.winner, required this.line});

  /// [Ttt.x], [Ttt.o], or 0 for a draw.
  final int winner;

  /// Winning cell indices (empty for a draw).
  final List<int> line;
}

/// Pass-and-play tic-tac-toe on an [size]×[size] board where [winLength] in a
/// row wins. Pure logic — no AI.
class TicTacToeGame {
  TicTacToeGame({required this.size, required this.winLength, required int firstPlayer})
      : cells = List<int>.filled(size * size, Ttt.empty),
        current = firstPlayer;

  final int size;
  final int winLength;
  List<int> cells;

  /// Whose turn it is: [Ttt.x] or [Ttt.o].
  int current;

  bool get isFull => !cells.contains(Ttt.empty);

  /// Places the current player's mark at [index] if empty and no result yet.
  /// Returns true if the move was made.
  bool play(int index) {
    if (cells[index] != Ttt.empty) return false;
    if (result != null) return false;
    cells[index] = current;
    _cachedResult = _compute();
    if (_cachedResult == null) {
      current = current == Ttt.x ? Ttt.o : Ttt.x;
    }
    return true;
  }

  TttResult? _cachedResult;

  /// The result, or null while the game is still in progress.
  TttResult? get result => _cachedResult;

  TttResult? _compute() {
    // Direction vectors: right, down, down-right, down-left.
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final start = cells[r * size + c];
        if (start == Ttt.empty) continue;
        for (final d in dirs) {
          final line = <int>[r * size + c];
          var rr = r, cc = c;
          var ok = true;
          for (var k = 1; k < winLength; k++) {
            rr += d[0];
            cc += d[1];
            if (rr < 0 || rr >= size || cc < 0 || cc >= size) {
              ok = false;
              break;
            }
            if (cells[rr * size + cc] != start) {
              ok = false;
              break;
            }
            line.add(rr * size + cc);
          }
          if (ok) return TttResult(winner: start, line: line);
        }
      }
    }
    if (isFull) return const TttResult(winner: 0, line: []);
    return null;
  }
}
