/// The shared undo capability: one bounded stack, one behaviour, in every game
/// where a move can be taken back (`Dally v4`, phase 20).
///
/// A game holds one of these over its own snapshot type — whatever restores its
/// state exactly, and nothing more. The stack never interprets a snapshot, so
/// Solitaire's deep-copied piles and 2048's flat value grid share the same
/// implementation.
///
/// ```dart
/// final _undo = UndoStack<Board2048Snapshot>();
/// …
/// _undo.push(board.snapshot());   // before the move
/// board.apply(move);
/// …
/// final s = _undo.pop();          // on the undo tap
/// if (s != null) board.restore(s);
/// ```
class UndoStack<S> {
  UndoStack({this.limit = kUndoLimit}) : assert(limit > 0);

  /// Five is enough to walk out of a misclick or a bad chain and short enough
  /// that nobody plays the game backwards; it also bounds the state a save file
  /// has to carry.
  static const int kUndoLimit = 5;

  final int limit;

  final List<S> _stack = [];

  /// True once at least one step has been taken back **this game**.
  ///
  /// This is the record-integrity flag: a session that used undo still counts
  /// as a game played and still counts toward wins, losses and play time, but
  /// it does not set a *clean* record — best time, best score, fewest moves.
  /// It survives [clear] on purpose, because clearing the stack at the end of a
  /// game must not launder the run that used it.
  bool _used = false;

  bool get canUndo => _stack.isNotEmpty;
  int get depth => _stack.length;
  bool get used => _used;

  /// Records the state *before* a move. The oldest snapshot is dropped silently
  /// once the cap is reached — no warning, because the cap is not a resource
  /// the player is spending.
  void push(S snapshot) {
    _stack.add(snapshot);
    if (_stack.length > limit) _stack.removeAt(0);
  }

  /// One tap is one step. Returns null when there is nothing to take back.
  S? pop() {
    if (_stack.isEmpty) return null;
    _used = true;
    return _stack.removeLast();
  }

  /// Drops the history without clearing the record-integrity flag. Called the
  /// moment a game ends — a finished board cannot be un-finished — and whenever
  /// the history stops being valid.
  void clear() => _stack.clear();

  /// A whole new game: history gone and the flag with it.
  void reset() {
    _stack.clear();
    _used = false;
  }
}
