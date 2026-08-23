import 'dart:math';

enum CardState { faceDown, faceUp, matched }

enum FlipKind { firstUp, match, miss, ignored }

class FlipOutcome {
  const FlipOutcome(this.kind, {this.a, this.b, this.complete = false});
  final FlipKind kind;
  final int? a;
  final int? b;
  final bool complete;
}

/// A match-pairs game. [rows]×[cols] cards (even count) hold `rows*cols/2`
/// symbol ids, each appearing twice. Pure logic; the UI animates the flips.
class MemoryGame {
  MemoryGame({required this.rows, required this.cols, Random? rng})
      : _rng = rng ?? Random() {
    _deal();
  }

  final int rows;
  final int cols;
  final Random _rng;

  late List<int> symbols; // card index -> symbol id
  late List<CardState> states;
  int moves = 0;
  int _firstUp = -1;
  bool busy = false;

  int get pairCount => rows * cols ~/ 2;

  void _deal() {
    final ids = <int>[];
    for (var i = 0; i < pairCount; i++) {
      ids..add(i)..add(i);
    }
    ids.shuffle(_rng);
    symbols = ids;
    states = List<CardState>.filled(ids.length, CardState.faceDown);
    moves = 0;
    _firstUp = -1;
    busy = false;
  }

  void reset() => _deal();

  bool get isComplete => states.every((s) => s == CardState.matched);

  /// Flips card [i] face-up if allowed and reports what happened. On a [miss]
  /// the caller must call [resolveMiss] after a short delay.
  FlipOutcome flip(int i) {
    if (busy || states[i] != CardState.faceDown) {
      return const FlipOutcome(FlipKind.ignored);
    }
    states[i] = CardState.faceUp;
    if (_firstUp == -1) {
      _firstUp = i;
      return FlipOutcome(FlipKind.firstUp, a: i);
    }
    final a = _firstUp;
    _firstUp = -1;
    moves++;
    if (symbols[a] == symbols[i]) {
      states[a] = CardState.matched;
      states[i] = CardState.matched;
      return FlipOutcome(FlipKind.match, a: a, b: i, complete: isComplete);
    }
    busy = true;
    return FlipOutcome(FlipKind.miss, a: a, b: i);
  }

  void resolveMiss(int a, int b) {
    if (states[a] == CardState.faceUp) states[a] = CardState.faceDown;
    if (states[b] == CardState.faceUp) states[b] = CardState.faceDown;
    busy = false;
  }
}
