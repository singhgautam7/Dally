import 'dart:math';

/// Swipe direction.
enum Move2048 { up, down, left, right }

/// A tile with a stable [id] so the UI can animate it sliding between cells.
class Tile2048 {
  Tile2048({required this.id, required this.value, required this.row, required this.col});

  final int id;
  int value;
  int row;
  int col;

  /// Set on the turn this tile was produced by a merge (for the pop animation).
  bool mergedThisTurn = false;

  /// Set on the turn this tile spawned (for the fade-in).
  bool spawnedThisTurn = false;
}

/// The result of applying a move — whether anything shifted, points gained, and
/// the tiles that merged away (they slide into their target cell, then vanish).
class MoveResult {
  MoveResult({required this.moved, required this.gained, required this.mergedAway});

  final bool moved;
  final int gained;

  /// Tiles removed by a merge, carrying their *target* cell so the UI can slide
  /// them there before dropping them.
  final List<Tile2048> mergedAway;
}

/// A pure, deterministic 2048 engine. Seedable RNG makes games reproducible and
/// testable. Holds tile identity so the play screen can animate slides/merges;
/// serialises to just the value grid + score.
class Board2048 {
  Board2048({required this.size, Random? rng}) : _rng = rng ?? Random() {
    _grid = List<Tile2048?>.filled(size * size, null);
  }

  final int size;
  final Random _rng;
  late List<Tile2048?> _grid;
  int _nextId = 1;
  int score = 0;

  /// Highest tile value ever present. `2048` (or higher) means the win tile was
  /// reached; the player may keep going.
  int get maxTile {
    var m = 0;
    for (final t in _grid) {
      if (t != null && t.value > m) m = t.value;
    }
    return m;
  }

  List<Tile2048> get tiles => [for (final t in _grid) ?t];

  int _idx(int r, int c) => r * size + c;
  Tile2048? at(int r, int c) => _grid[_idx(r, c)];

  /// Starts a fresh game with two spawned tiles.
  void start() {
    _grid = List<Tile2048?>.filled(size * size, null);
    score = 0;
    _nextId = 1;
    spawn();
    spawn();
  }

  /// Spawns a 2 (90%) or 4 (10%) in a random empty cell. Returns the tile, or
  /// null if the board is full.
  Tile2048? spawn() {
    final empties = <int>[];
    for (var i = 0; i < _grid.length; i++) {
      if (_grid[i] == null) empties.add(i);
    }
    if (empties.isEmpty) return null;
    final pos = empties[_rng.nextInt(empties.length)];
    final tile = Tile2048(
      id: _nextId++,
      value: _rng.nextInt(10) == 0 ? 4 : 2,
      row: pos ~/ size,
      col: pos % size,
    )..spawnedThisTurn = true;
    _grid[pos] = tile;
    return tile;
  }

  /// Applies [move]. Slides and merges tiles, updates score, and spawns one new
  /// tile if anything moved.
  MoveResult apply(Move2048 move) {
    for (final t in tiles) {
      t.mergedThisTurn = false;
      t.spawnedThisTurn = false;
    }

    final (dr, dc) = switch (move) {
      Move2048.up => (-1, 0),
      Move2048.down => (1, 0),
      Move2048.left => (0, -1),
      Move2048.right => (0, 1),
    };

    // Traverse from the target edge inward so the leading tile settles first.
    final rows = [for (var i = 0; i < size; i++) i];
    final cols = [for (var i = 0; i < size; i++) i];
    if (dr > 0) rows.sort((a, b) => b - a);
    if (dc > 0) cols.sort((a, b) => b - a);

    var moved = false;
    var gained = 0;
    final mergedAway = <Tile2048>[];

    for (final r in rows) {
      for (final c in cols) {
        final tile = at(r, c);
        if (tile == null) continue;

        var nr = r, nc = c;
        // Slide to the farthest empty cell.
        while (true) {
          final tr = nr + dr, tc = nc + dc;
          if (tr < 0 || tr >= size || tc < 0 || tc >= size) break;
          if (at(tr, tc) == null) {
            nr = tr;
            nc = tc;
          } else {
            break;
          }
        }
        // Check for a merge into the next occupied cell.
        final tr = nr + dr, tc = nc + dc;
        final neighbour = (tr >= 0 && tr < size && tc >= 0 && tc < size) ? at(tr, tc) : null;
        if (neighbour != null && neighbour.value == tile.value && !neighbour.mergedThisTurn) {
          // Merge: neighbour doubles, this tile slides in and is removed.
          _grid[_idx(r, c)] = null;
          neighbour.value *= 2;
          neighbour.mergedThisTurn = true;
          score += neighbour.value;
          gained += neighbour.value;
          tile
            ..row = tr
            ..col = tc;
          mergedAway.add(tile);
          moved = true;
        } else if (nr != r || nc != c) {
          _grid[_idx(r, c)] = null;
          tile
            ..row = nr
            ..col = nc;
          _grid[_idx(nr, nc)] = tile;
          moved = true;
        }
      }
    }

    if (moved) spawn();
    return MoveResult(moved: moved, gained: gained, mergedAway: mergedAway);
  }

  /// True when no move can change the board.
  bool get isGameOver {
    if (_grid.contains(null)) return false;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = at(r, c)!.value;
        if (c + 1 < size && at(r, c + 1)!.value == v) return false;
        if (r + 1 < size && at(r + 1, c)!.value == v) return false;
      }
    }
    return true;
  }

  /// The value grid, row-major.
  List<int> toValues() => [for (final t in _grid) t?.value ?? 0];

  /// Restores from a value grid + score. Regenerates tile ids.
  void loadValues(List<int> values, int savedScore) {
    _grid = List<Tile2048?>.filled(size * size, null);
    _nextId = 1;
    for (var i = 0; i < values.length && i < _grid.length; i++) {
      final v = values[i];
      if (v > 0) {
        _grid[i] = Tile2048(id: _nextId++, value: v, row: i ~/ size, col: i % size);
      }
    }
    score = savedScore;
  }
}
