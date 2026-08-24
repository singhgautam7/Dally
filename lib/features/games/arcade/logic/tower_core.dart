/// One placed floor of the tower.
class Floor {
  const Floor({required this.left, required this.width});
  final double left;
  final double width;

  double get right => left + width;
}

/// Tower Builder's simulation. A block sweeps the top; a tap drops it. The
/// overhang is cut, so the tower narrows and the game ends itself — there is no
/// timer and no fail state to write.
class TowerCore {
  TowerCore({required this.arenaWidth});

  final double arenaWidth;

  /// Floors are thin so a good tower reads tall.
  static const double floorHeight = 14;
  static const double startWidth = 120;
  static const double baseSpeed = 150;

  final List<Floor> floors = [];

  /// The sweeping block's left edge.
  double sweepLeft = 0;
  double sweepWidth = startWidth;
  int direction = 1;
  bool dead = false;

  /// Three consecutive perfect drops widen the block one step — the only accent
  /// flash in the game.
  int perfectRun = 0;
  bool justWidened = false;

  int get score => floors.length;

  /// Sweep speed rises every five floors.
  double get speed => baseSpeed + (floors.length ~/ 5) * 28;

  void reset() {
    floors
      ..clear()
      ..add(Floor(left: (arenaWidth - startWidth) / 2, width: startWidth));
    sweepWidth = startWidth;
    sweepLeft = 0;
    direction = 1;
    dead = false;
    perfectRun = 0;
    justWidened = false;
  }

  void step(double dt) {
    if (dead) return;
    sweepLeft += direction * speed * dt;
    if (sweepLeft <= 0) {
      sweepLeft = 0;
      direction = 1;
    } else if (sweepLeft + sweepWidth >= arenaWidth) {
      sweepLeft = arenaWidth - sweepWidth;
      direction = -1;
    }
  }

  /// Drops the sweeping block onto the tower. Returns the width that survived;
  /// zero means the drop missed entirely and the run is over.
  double drop() {
    if (dead) return 0;
    justWidened = false;
    final below = floors.last;
    final left = sweepLeft > below.left ? sweepLeft : below.left;
    final right = (sweepLeft + sweepWidth) < below.right ? sweepLeft + sweepWidth : below.right;
    final overlap = right - left;

    if (overlap <= 0) {
      dead = true;
      return 0;
    }

    // A drop within a pixel of flush counts as perfect.
    final perfect = (sweepLeft - below.left).abs() < 1.5;
    perfectRun = perfect ? perfectRun + 1 : 0;

    var width = overlap;
    if (perfectRun >= 3) {
      // One step wider, never past where it started.
      width = (width + 12).clamp(0.0, startWidth);
      perfectRun = 0;
      justWidened = true;
    }

    floors.add(Floor(left: left, width: width));
    sweepWidth = width;
    sweepLeft = direction > 0 ? 0 : arenaWidth - width;
    return width;
  }
}
