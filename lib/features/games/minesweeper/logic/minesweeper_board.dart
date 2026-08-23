import 'dart:math';

enum CellReveal { hidden, revealed }

/// The result of revealing a cell.
enum RevealOutcome { ok, mine, alreadyOpen }

/// A Minesweeper board with optional guess-free generation: mines are placed on
/// the first tap so that spot is always safe, and (when [guessFree]) the layout
/// is accepted only if a deterministic solver can clear it without guessing.
class MinesweeperBoard {
  MinesweeperBoard({
    required this.width,
    required this.height,
    required this.mineCount,
    required this.guessFree,
    Random? rng,
  }) : _rng = rng ?? Random() {
    final n = width * height;
    mine = List.filled(n, false);
    reveal = List.filled(n, CellReveal.hidden);
    flagged = List.filled(n, false);
    count = List.filled(n, 0);
  }

  final int width;
  final int height;
  final int mineCount;
  final bool guessFree;
  final Random _rng;

  late List<bool> mine;
  late List<CellReveal> reveal;
  late List<bool> flagged;
  late List<int> count;

  bool _generated = false;
  bool exploded = false;

  int get cells => width * height;
  int _idx(int c, int r) => r * width + c;

  Iterable<int> neighbours(int i) sync* {
    final c = i % width, r = i ~/ width;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nc = c + dc, nr = r + dr;
        if (nc >= 0 && nc < width && nr >= 0 && nr < height) yield _idx(nc, nr);
      }
    }
  }

  int get flagsPlaced => flagged.where((f) => f).length;
  int get minesLeft => mineCount - flagsPlaced;

  bool get isWon {
    for (var i = 0; i < cells; i++) {
      if (!mine[i] && reveal[i] == CellReveal.hidden) return false;
    }
    return true;
  }

  /// Reveals [i], generating the board on the first reveal (keeping [i] safe).
  RevealOutcome revealCell(int i) {
    if (!_generated) _generate(i);
    if (flagged[i]) return RevealOutcome.alreadyOpen;
    if (reveal[i] == CellReveal.revealed) return RevealOutcome.alreadyOpen;
    if (mine[i]) {
      reveal[i] = CellReveal.revealed;
      exploded = true;
      return RevealOutcome.mine;
    }
    _flood(i);
    return RevealOutcome.ok;
  }

  /// Restores a saved mid-game position. [mines]/[revealed]/[flagged] are 0/1
  /// arrays of length [cells]. Counts are recomputed.
  void restore({required List<int> mines, required List<int> revealed, required List<int> flags}) {
    _generated = true;
    for (var i = 0; i < cells; i++) {
      mine[i] = mines[i] == 1;
      reveal[i] = revealed[i] == 1 ? CellReveal.revealed : CellReveal.hidden;
      flagged[i] = flags[i] == 1;
    }
    _computeCounts();
  }

  bool get generated => _generated;

  void toggleFlag(int i) {
    if (reveal[i] == CellReveal.revealed) return;
    flagged[i] = !flagged[i];
  }

  /// Reveals unflagged neighbours of an already-revealed number when its flag
  /// count matches (chording). Returns true if a mine was wrongly hit.
  bool chord(int i) {
    if (reveal[i] != CellReveal.revealed || count[i] == 0) return false;
    final flags = neighbours(i).where((n) => flagged[n]).length;
    if (flags != count[i]) return false;
    var hitMine = false;
    for (final n in neighbours(i).toList()) {
      if (!flagged[n] && reveal[n] == CellReveal.hidden) {
        if (revealCell(n) == RevealOutcome.mine) hitMine = true;
      }
    }
    return hitMine;
  }

  void _flood(int start) {
    final stack = [start];
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      if (reveal[i] == CellReveal.revealed || flagged[i] || mine[i]) continue;
      reveal[i] = CellReveal.revealed;
      if (count[i] == 0) stack.addAll(neighbours(i));
    }
  }

  void _computeCounts() {
    for (var i = 0; i < cells; i++) {
      count[i] = mine[i] ? 0 : neighbours(i).where((n) => mine[n]).length;
    }
  }

  void _placeMines(int safe) {
    mine = List.filled(cells, false);
    final forbidden = {safe, ...neighbours(safe)};
    final candidates = [for (var i = 0; i < cells; i++) if (!forbidden.contains(i)) i]..shuffle(_rng);
    final k = min(mineCount, candidates.length);
    for (var i = 0; i < k; i++) {
      mine[candidates[i]] = true;
    }
    _computeCounts();
  }

  void _generate(int safe) {
    _generated = true;
    final attempts = guessFree ? 300 : 1;
    for (var a = 0; a < attempts; a++) {
      _placeMines(safe);
      if (!guessFree || _isSolvable(safe)) break;
    }
  }

  /// Whether the current mine layout is fully deducible (no guessing) from a
  /// first click at [start], using single-point + subset logic. Exposed so the
  /// guess-free guarantee is testable.
  bool solvableFrom(int start) => _isSolvable(start);

  /// Deterministic solver used to certify a guess-free board. Uses single-point
  /// logic plus subset elimination. Returns true if every safe cell is
  /// deducible from the first click.
  bool _isSolvable(int start) {
    final known = List<int>.filled(cells, 0); // 0 unknown, 1 safe/open, 2 mine
    void open(int i) {
      final stack = [i];
      while (stack.isNotEmpty) {
        final j = stack.removeLast();
        if (known[j] == 1) continue;
        known[j] = 1;
        if (count[j] == 0) {
          for (final n in neighbours(j)) {
            if (known[n] == 0) stack.add(n);
          }
        }
      }
    }

    List<int> hiddenOf(int i) => [for (final n in neighbours(i)) if (known[n] == 0) n];
    int minesOf(int i) => neighbours(i).where((n) => known[n] == 2).length;

    open(start);
    var progress = true;
    while (progress) {
      progress = false;
      // Single-point: a number satisfied by flags opens its rest; a number
      // whose remaining mines fill its hidden set flags them all.
      for (var i = 0; i < cells; i++) {
        if (known[i] != 1 || count[i] == 0) continue;
        final hidden = hiddenOf(i);
        if (hidden.isEmpty) continue;
        final mines = minesOf(i);
        if (count[i] == mines) {
          for (final n in hidden) {
            open(n);
          }
          progress = true;
        } else if (count[i] - mines == hidden.length) {
          for (final n in hidden) {
            known[n] = 2;
          }
          progress = true;
        }
      }
      if (progress) continue;
      // Subset (1-2) elimination between overlapping numbers.
      for (var a = 0; a < cells && !progress; a++) {
        if (known[a] != 1 || count[a] == 0) continue;
        final ha = hiddenOf(a).toSet();
        if (ha.isEmpty) continue;
        final na = count[a] - minesOf(a);
        for (final b in neighbours(a)) {
          if (known[b] != 1 || count[b] == 0) continue;
          final hb = hiddenOf(b).toSet();
          if (hb.length <= ha.length || !hb.containsAll(ha)) continue;
          final nb = count[b] - minesOf(b);
          final diff = hb.difference(ha);
          if (nb - na == diff.length) {
            for (final n in diff) {
              known[n] = 2;
            }
            progress = true;
          } else if (nb - na == 0) {
            for (final n in diff) {
              open(n);
            }
            progress = true;
          }
        }
      }
    }
    // Solvable iff every non-mine cell is known-open.
    for (var i = 0; i < cells; i++) {
      if (!mine[i] && known[i] != 1) return false;
    }
    return true;
  }
}
