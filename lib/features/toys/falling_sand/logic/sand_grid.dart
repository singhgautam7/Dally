import 'dart:typed_data';

import '../../../../core/util/dally_random.dart';

/// What a cell is made of. The byte stored in [SandGrid.cells] is this index,
/// so the whole canvas is one compact buffer rather than a list of objects.
enum Substance {
  empty,
  sand,
  water,
  wall,
  fire,
  oil,
  plant,
  smoke;

  /// How readily a substance sinks. A heavier one swaps places with a lighter
  /// one below it, which is the whole of "sand sinks through water" and "oil
  /// floats on water".
  int get density => switch (this) {
        Substance.sand => 4,
        Substance.wall => 5,
        Substance.plant => 5,
        Substance.water => 3,
        Substance.oil => 2,
        Substance.smoke => 1,
        Substance.fire => 1,
        Substance.empty => 0,
      };

  /// A liquid finds its level: it spreads sideways when it cannot fall.
  bool get isLiquid => this == Substance.water || this == Substance.oil;

  /// Fire spreads into these.
  bool get burns => this == Substance.oil || this == Substance.plant;

  /// Nothing moves these.
  bool get isStatic => this == Substance.wall || this == Substance.plant;
}

/// The Falling Sand sandbox: one grid, one rule per substance, nobody wins.
///
/// **The step is a pure function of (grid, rng).** Every draw comes from the
/// injected [DallyRandom], so a seeded grid replays exactly and the whole
/// automaton is unit-testable without a widget tree
/// (`.agents/CLAUDE.md` §8, §13).
///
/// Storage is two `Uint8List`s — the substance and a per-cell age that only
/// fire and smoke read — plus a moved-mask so nothing is stepped twice in one
/// pass. No per-cell objects, and nothing here allocates per frame.
class SandGrid {
  SandGrid({required this.cols, required this.rows, required this.rng})
      : cells = Uint8List(cols * rows),
        age = Uint8List(cols * rows),
        _moved = Uint8List(cols * rows);

  final int cols;
  final int rows;
  final DallyRandom rng;

  /// Substance index per cell, row-major from the top-left.
  final Uint8List cells;

  /// Per-cell age. Only fire and smoke read it; everything else leaves it at 0.
  final Uint8List age;

  final Uint8List _moved;

  /// Fixed lifetimes, in steps.
  static const int fireLife = 42;
  static const int smokeLife = 90;

  /// How eagerly plant creeps along damp cells, per step per candidate.
  static const double plantGrowthChance = 0.02;

  /// How often smoke drifts sideways rather than straight up.
  static const double smokeDriftChance = 0.35;

  int index(int c, int r) => r * cols + c;
  bool inside(int c, int r) => c >= 0 && c < cols && r >= 0 && r < rows;

  Substance at(int c, int r) =>
      inside(c, r) ? Substance.values[cells[index(c, r)]] : Substance.wall;

  /// How much of the canvas is not empty, `0…1`. The Clear control uses it to
  /// decide whether the action is worth offering to reverse.
  double get fillRatio {
    var filled = 0;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != 0) filled++;
    }
    return filled / cells.length;
  }

  void clear() {
    cells.fillRange(0, cells.length, 0);
    age.fillRange(0, age.length, 0);
  }

  /// Restores a previously captured buffer — what the Clear reversal hands back.
  void restore(Uint8List snapshot, Uint8List ages) {
    cells.setAll(0, snapshot);
    age.setAll(0, ages);
  }

  Uint8List snapshot() => Uint8List.fromList(cells);
  Uint8List ageSnapshot() => Uint8List.fromList(age);

  /// Paints a filled disc of [substance] with radius [radius] cells. The eraser
  /// is `Substance.empty`, so painting and erasing are one path.
  void paint(int c, int r, Substance substance, int radius) {
    final rr = radius * radius;
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy > rr) continue;
        final x = c + dx, y = r + dy;
        if (!inside(x, y)) continue;
        final i = index(x, y);
        cells[i] = substance.index;
        age[i] = 0;
      }
    }
  }

  /// Paints a stroke from (c0, r0) to (c1, r1), dabbing every cell along the
  /// way. A finger moving quickly only reports a handful of positions, so at
  /// the finest brush a stroke would otherwise land as a row of dots. Bresenham
  /// between samples is what makes the fine brush usable.
  void paintLine(int c0, int r0, int c1, int r1, Substance substance, int radius) {
    var x = c0, y = r0;
    final dx = (c1 - c0).abs(), dy = -(r1 - r0).abs();
    final sx = c0 < c1 ? 1 : -1, sy = r0 < r1 ? 1 : -1;
    var err = dx + dy;
    // Bounded by the line's own length, so the loop always terminates — and
    // still covers a stroke whose ends are outside the grid, which a bound of
    // the grid's own diagonal would cut short.
    final steps = (dx > -dy ? dx : -dy) + 1;
    for (var guard = 0; guard < steps; guard++) {
      paint(x, y, substance, radius);
      if (x == c1 && y == r1) return;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y += sy;
      }
    }
  }

  void _set(int i, Substance s, {int cellAge = 0}) {
    cells[i] = s.index;
    age[i] = cellAge;
  }

  void _swap(int a, int b) {
    final cell = cells[a];
    final years = age[a];
    cells[a] = cells[b];
    age[a] = age[b];
    cells[b] = cell;
    age[b] = years;
    _moved[a] = 1;
    _moved[b] = 1;
  }

  /// One simulation step.
  ///
  /// The scan runs **bottom-up** so a falling column resolves in one pass
  /// rather than smearing, and each row alternates its left/right preference so
  /// a pile does not lean. Nothing depends on wall-clock time: the caller
  /// drives this from the fixed-step loop.
  void step() {
    _moved.fillRange(0, _moved.length, 0);
    for (var r = rows - 1; r >= 0; r--) {
      final leftFirst = rng.nextBool();
      for (var k = 0; k < cols; k++) {
        final c = leftFirst ? k : cols - 1 - k;
        final i = index(c, r);
        if (_moved[i] == 1) continue;
        switch (Substance.values[cells[i]]) {
          case Substance.empty:
          case Substance.wall:
            break;
          case Substance.sand:
            _stepSand(c, r, i);
          case Substance.water:
          case Substance.oil:
            _stepLiquid(c, r, i);
          case Substance.fire:
            _stepFire(c, r, i);
          case Substance.smoke:
            _stepSmoke(c, r, i);
          case Substance.plant:
            _stepPlant(c, r, i);
        }
      }
    }
  }

  /// Sand falls, and piles at its angle of repose: straight down where it can,
  /// otherwise one cell diagonally, otherwise it rests.
  void _stepSand(int c, int r, int i) {
    if (_sink(c, r, i, Substance.sand)) return;
    final first = rng.nextBool() ? -1 : 1;
    for (final dx in [first, -first]) {
      if (_sink(c + dx, r, i, Substance.sand)) return;
    }
  }

  /// Moves the cell at [i] into (c, r+1) when what is there is lighter.
  bool _sink(int c, int r, int i, Substance self) {
    if (!inside(c, r + 1)) return false;
    final target = index(c, r + 1);
    if (_moved[target] == 1) return false;
    final there = Substance.values[cells[target]];
    if (there.isStatic || there.density >= self.density) return false;
    _swap(i, target);
    return true;
  }

  /// A liquid falls, then slides, then spreads sideways to find its level.
  void _stepLiquid(int c, int r, int i) {
    final self = Substance.values[cells[i]];
    if (_sink(c, r, i, self)) return;
    final first = rng.nextBool() ? -1 : 1;
    for (final dx in [first, -first]) {
      if (_sink(c + dx, r, i, self)) return;
    }
    // Level-finding: one step sideways into anything lighter.
    for (final dx in [first, -first]) {
      final x = c + dx;
      if (!inside(x, r)) continue;
      final target = index(x, r);
      if (_moved[target] == 1) continue;
      final there = Substance.values[cells[target]];
      if (there.isStatic || there.density >= self.density) continue;
      _swap(i, target);
      return;
    }
  }

  /// Fire consumes what burns, is put out by water, and leaves smoke behind.
  void _stepFire(int c, int r, int i) {
    var doused = false;
    for (final (dx, dy) in const [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
      final x = c + dx, y = r + dy;
      if (!inside(x, y)) continue;
      final n = index(x, y);
      final there = Substance.values[cells[n]];
      if (there == Substance.water) {
        doused = true;
      } else if (there.burns && _moved[n] == 0) {
        _set(n, Substance.fire);
        _moved[n] = 1;
      }
    }
    final years = age[i] + 1;
    if (doused || years >= fireLife) {
      _set(i, Substance.smoke);
    } else {
      age[i] = years;
    }
    _moved[i] = 1;
  }

  /// Smoke rises and thins out. It is the only substance that expires into
  /// nothing.
  void _stepSmoke(int c, int r, int i) {
    final years = age[i] + 1;
    if (years >= smokeLife) {
      _set(i, Substance.empty);
      _moved[i] = 1;
      return;
    }
    age[i] = years;
    final dx = rng.nextDouble() < smokeDriftChance ? (rng.nextBool() ? -1 : 1) : 0;
    for (final (x, y) in [(c + dx, r - 1), (c, r - 1)]) {
      if (!inside(x, y)) continue;
      final target = index(x, y);
      if (_moved[target] == 1) continue;
      final there = Substance.values[cells[target]];
      if (there == Substance.empty) {
        _swap(i, target);
        return;
      }
    }
    _moved[i] = 1;
  }

  /// Plant creeps along damp cells: it grows into water it is touching.
  void _stepPlant(int c, int r, int i) {
    _moved[i] = 1;
    for (final (dx, dy) in const [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
      final x = c + dx, y = r + dy;
      if (!inside(x, y)) continue;
      final n = index(x, y);
      if (_moved[n] == 1) continue;
      if (Substance.values[cells[n]] != Substance.water) continue;
      if (rng.nextDouble() < plantGrowthChance) {
        _set(n, Substance.plant);
        _moved[n] = 1;
      }
    }
  }
}
