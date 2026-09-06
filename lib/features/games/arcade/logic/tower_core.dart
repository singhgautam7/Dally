import '../../../../core/game/arena_scale.dart';

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
///
/// **Every horizontal number is a fraction of the arena width**, so one sweep
/// takes the same ~1.6 seconds and the block covers the same third of the
/// screen at any size. They used to be absolute pixels, and a landscape tablet
/// got a 7-second sweep of a sliver a tenth of the width — a different game.
class TowerCore {
  TowerCore({required this.arenaWidth}) {
    sweepWidth = startWidth;
  }

  final double arenaWidth;

  // ── Authored tuning, in reference units ──────────────────────────────────

  /// Floors are thin so a good tower reads tall.
  static const double floorHeightRef = 14;
  static const double startWidthRef = 120;
  static const double baseSpeedRef = 150;
  static const double speedStepRef = 28;
  static const double widenStepRef = 12;
  static const double perfectToleranceRef = 1.5;

  /// How much faster the sweep gets over a long tower — the shared curve, fed
  /// by elapsed sim time rather than a floor count, so it is smooth.
  static const double speedRamp = 0.9;

  /// What one reference unit costs on this arena. The sweep is horizontal, so
  /// there is only one axis to answer to.
  double get travelScale => axisScale(arenaWidth, kReferenceArena.width);

  double get floorHeight => floorHeightRef * travelScale;
  double get startWidth => startWidthRef * travelScale;
  double get widenStep => widenStepRef * travelScale;
  double get perfectTolerance => perfectToleranceRef * travelScale;

  final List<Floor> floors = [];

  /// The sweeping block's left edge.
  double sweepLeft = 0;
  late double sweepWidth;
  int direction = 1;
  bool dead = false;

  /// Three consecutive perfect drops widen the block one step — the only accent
  /// flash in the game.
  int perfectRun = 0;
  bool justWidened = false;

  int get score => floors.length;

  double _elapsed = 0;

  /// Elapsed *simulated* seconds — the input to the shared ramp.
  double get elapsedSeconds => _elapsed;

  /// Sweep speed, easing up over a run on the shared arcade curve.
  double get speed =>
      baseSpeedRef * travelScale * arcadeRamp(_elapsed, amount: speedRamp);

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
    _elapsed = 0;
  }

  void step(double dt) {
    if (dead) return;
    _elapsed += dt;
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
    final perfect = (sweepLeft - below.left).abs() < perfectTolerance;
    perfectRun = perfect ? perfectRun + 1 : 0;

    var width = overlap;
    if (perfectRun >= 3) {
      // One step wider, never past where it started.
      width = (width + widenStep).clamp(0.0, startWidth);
      perfectRun = 0;
      justWidened = true;
    }

    floors.add(Floor(left: left, width: width));
    sweepWidth = width;
    sweepLeft = direction > 0 ? 0 : arenaWidth - width;
    return width;
  }
}
