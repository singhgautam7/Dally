/// Which side a piece belongs to. [bottom] moves toward index 0 is *not* the
/// rule — see [FrogHopGame.direction]: bottom travels up the lane (index
/// increasing is toward the top), so the two sides pass through each other.
enum FrogSide { bottom, top }

/// How a piece got where it is.
enum FrogMoveKind { step, jump }

/// One legal move: a piece at [from] going to [to].
class FrogMove {
  const FrogMove({required this.from, required this.to, required this.kind});

  final int from;
  final int to;
  final FrogMoveKind kind;

  /// The cell jumped over, or null for a step.
  int? get over => kind == FrogMoveKind.jump ? (from + to) ~/ 2 : null;

  @override
  bool operator ==(Object other) =>
      other is FrogMove && other.from == from && other.to == to && other.kind == kind;

  @override
  int get hashCode => Object.hash(from, to, kind);

  @override
  String toString() => '${kind.name} $from→$to';
}

/// Frog Hop — a race down one lane.
///
/// Each side starts [perSide] pieces at its own end with a single empty cell
/// between the two blocks. A piece **steps** into the empty cell directly ahead
/// of it, or **jumps** over exactly one occupied neighbour — either colour —
/// into the empty cell beyond. Nothing moves backwards, nothing is captured,
/// and a jump is never forced. The first side to fill the opposite end wins.
///
/// Pure rules: no widgets, no clock, no randomness. The lane is a single list
/// of cells, so the geometry is one index and a rotation to landscape is a
/// rendering decision rather than a rules one.
class FrogHopGame {
  FrogHopGame({required this.perSide, FrogSide first = FrogSide.bottom})
      : assert(perSide >= 1),
        _turn = first,
        _cells = List<FrogSide?>.filled(perSide * 2 + 1, null) {
    _deal();
  }

  /// Pieces a side. 3 is the default; 4 and 5 are the longer games.
  final int perSide;

  final List<FrogSide?> _cells;
  FrogSide _turn;
  bool _passed = false;
  int _moves = 0;
  int _jumps = 0;
  int _jumpChain = 0;
  int _longestJumpChain = 0;

  /// The lane, low index to high. Bottom starts at the low end.
  int get length => _cells.length;

  FrogSide? at(int index) => _cells[index];

  FrogSide get turn => _turn;
  int get moves => _moves;
  int get jumps => _jumps;
  int get longestJumpChain => _longestJumpChain;

  void _deal() {
    for (var i = 0; i < perSide; i++) {
      _cells[i] = FrogSide.bottom;
      _cells[length - 1 - i] = FrogSide.top;
    }
    _cells[perSide] = null;
  }

  /// Bottom travels toward the high end, top toward the low end. Nothing ever
  /// moves the other way, which is what makes the game finite.
  static int direction(FrogSide side) => side == FrogSide.bottom ? 1 : -1;

  /// The cells a side has to fill to win: the far [perSide] cells.
  Iterable<int> homeCells(FrogSide side) sync* {
    for (var i = 0; i < perSide; i++) {
      yield side == FrogSide.bottom ? length - 1 - i : i;
    }
  }

  /// How many of a side's pieces are already home.
  int homeCount(FrogSide side) {
    var n = 0;
    for (final i in homeCells(side)) {
      if (_cells[i] == side) n++;
    }
    return n;
  }

  /// A side wins when every one of its pieces sits in the opposite end.
  FrogSide? get winner {
    for (final side in FrogSide.values) {
      if (homeCount(side) == perSide) return side;
    }
    return null;
  }

  bool get isOver => winner != null || isDeadlocked;

  /// Neither side can move — possible only when both are blocked, which ends
  /// the race as a draw.
  bool get isDeadlocked =>
      winner == null &&
      movesFor(FrogSide.bottom).isEmpty &&
      movesFor(FrogSide.top).isEmpty;

  /// The legal moves for the piece at [index], or empty when there is no piece
  /// there, it belongs to the other side, or it is blocked.
  List<FrogMove> movesFrom(int index) {
    final side = _cells[index];
    if (side == null) return const [];
    final d = direction(side);
    final out = <FrogMove>[];
    final ahead = index + d;
    if (ahead >= 0 && ahead < length && _cells[ahead] == null) {
      out.add(FrogMove(from: index, to: ahead, kind: FrogMoveKind.step));
    }
    final beyond = index + 2 * d;
    // A jump needs exactly one occupied neighbour — of either colour — and an
    // empty cell the other side of it.
    if (beyond >= 0 &&
        beyond < length &&
        _cells[ahead] != null &&
        _cells[beyond] == null) {
      out.add(FrogMove(from: index, to: beyond, kind: FrogMoveKind.jump));
    }
    return out;
  }

  /// Every legal move for [side].
  List<FrogMove> movesFor(FrogSide side) => [
        for (var i = 0; i < length; i++)
          if (_cells[i] == side) ...movesFrom(i),
      ];

  /// Whose move it is, given automatic passing: a side with no legal move
  /// passes, because there is no choice to make.
  List<FrogMove> get legalMoves => movesFor(_turn);

  bool isLegal(FrogMove move) => movesFrom(move.from).contains(move);

  /// Applies [move] if it is legal for the side on turn. Returns false and
  /// changes nothing otherwise.
  bool play(FrogMove move) {
    if (isOver) return false;
    if (_cells[move.from] != _turn || !isLegal(move)) return false;
    _cells[move.to] = _cells[move.from];
    _cells[move.from] = null;
    _moves++;
    if (move.kind == FrogMoveKind.jump) {
      _jumps++;
      _jumpChain++;
      if (_jumpChain > _longestJumpChain) _longestJumpChain = _jumpChain;
    } else {
      _jumpChain = 0;
    }
    _passTurn();
    return true;
  }

  /// Hands the turn over, skipping a side that cannot move. A side with no
  /// legal move passes automatically — there is no Pass button, because there
  /// is no choice to make.
  void _passTurn() {
    _passed = false;
    if (winner != null) return;
    final other = _turn == FrogSide.bottom ? FrogSide.top : FrogSide.bottom;
    if (movesFor(other).isNotEmpty) {
      _turn = other;
      return;
    }
    if (movesFor(_turn).isEmpty) {
      // Neither side can move: the lane is deadlocked and the race is a draw.
      return;
    }
    // The other side has nothing to play, so it passes and the turn stays put.
    _passed = true;
  }

  /// True when the last move left the *other* side with nothing to play, so it
  /// was skipped. The strip says so; there is no Pass button, because there is
  /// no choice to make.
  bool get otherSidePassed => _passed && !isOver;

  // ── Snapshots (undo) ──────────────────────────────────────────────────────

  FrogSnapshot snapshot() => FrogSnapshot(
        cells: List<FrogSide?>.from(_cells),
        turn: _turn,
        passed: _passed,
        moves: _moves,
        jumps: _jumps,
        jumpChain: _jumpChain,
        longestJumpChain: _longestJumpChain,
      );

  void restore(FrogSnapshot s) {
    _cells.setAll(0, s.cells);
    _turn = s.turn;
    _passed = s.passed;
    _moves = s.moves;
    _jumps = s.jumps;
    _jumpChain = s.jumpChain;
    _longestJumpChain = s.longestJumpChain;
  }
}

/// One restorable lane position.
class FrogSnapshot {
  const FrogSnapshot({
    required this.cells,
    required this.turn,
    required this.passed,
    required this.moves,
    required this.jumps,
    required this.jumpChain,
    required this.longestJumpChain,
  });

  final List<FrogSide?> cells;
  final FrogSide turn;
  final bool passed;
  final int moves;
  final int jumps;
  final int jumpChain;
  final int longestJumpChain;
}

/// The solo variant: the classic leapfrog puzzle. One player moves both sides
/// in any order, and the goal is to swap them — every bottom piece into the top
/// end and back. The minimum is `n² + 2n` moves (15 for three a side).
class FrogPuzzle {
  FrogPuzzle({required this.perSide}) : game = FrogHopGame(perSide: perSide);

  final int perSide;
  final FrogHopGame game;

  /// `n² + 2n`: every piece steps once per opposing piece it must pass, plus
  /// one step each way. 15 for three a side, 24 for four, 35 for five.
  int get minimumMoves => perSide * perSide + 2 * perSide;

  int get moves => game.moves;

  /// Solved when the two blocks have swapped ends completely.
  bool get isSolved =>
      game.homeCount(FrogSide.bottom) == perSide &&
      game.homeCount(FrogSide.top) == perSide;

  /// Every move on the board, from either side — there is no turn order here.
  List<FrogMove> get legalMoves => [
        for (var i = 0; i < game.length; i++) ...game.movesFrom(i),
      ];

  /// Stuck: no move left and not solved. The puzzle is restartable, never lost.
  bool get isStuck => !isSolved && legalMoves.isEmpty;

  bool play(FrogMove move) {
    if (isSolved || !game.isLegal(move)) return false;
    // The turn order is what the solo mode drops, so the move is applied
    // directly rather than through [FrogHopGame.play].
    final side = game.at(move.from)!;
    game._cells[move.to] = side;
    game._cells[move.from] = null;
    game._moves++;
    if (move.kind == FrogMoveKind.jump) {
      game._jumps++;
      game._jumpChain++;
      if (game._jumpChain > game._longestJumpChain) {
        game._longestJumpChain = game._jumpChain;
      }
    } else {
      game._jumpChain = 0;
    }
    return true;
  }

  FrogSnapshot snapshot() => game.snapshot();
  void restore(FrogSnapshot s) => game.restore(s);
}
