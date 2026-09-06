import '../../../../core/game/arena_scale.dart';
import '../../../../core/util/dally_random.dart';

/// A blocker sitting in one lane. `y` is measured down the arena.
class LaneBlock {
  const LaneBlock({required this.lane, required this.y});
  final int lane;
  final double y;
}

/// Racer's simulation: three lanes, a fixed car, tap a side to change lane.
/// No steering and no acceleration — the speed curve flattens, so a good run is
/// long rather than endless.
///
/// The spawner **always leaves one open lane**, so the road is never blocked.
///
/// **Everything down the road is viewport-relative.** Block height, speed and
/// spawn spacing are fractions of the measured arena height, so the car has the
/// same seconds to react on a small phone and on a tall tablet — it used to be
/// absolute pixels, which swung reaction time from 1.0s to 3.3s.
class RacerCore {
  RacerCore({required this.rng, required this.arenaHeight});

  final DallyRandom rng;
  final double arenaHeight;

  static const int lanes = 3;
  static const double carY = 0.78;

  // ── Authored tuning, in reference units ──────────────────────────────────

  static const double blockHeightRef = 46;
  static const double speedRef = 240;
  static const double spawnGapRef = 210;
  static const double spawnGapEaseRef = 120;
  static const double dashPeriodRef = 60;

  /// How much faster the road gets over a long session — the shared curve.
  static const double speedRamp = 1.33;

  /// Reference units per metre — see [AvoiderCore.unitsPerMetre]. Distance is
  /// measured in *reference* travel, so a kilometre is a kilometre on every
  /// screen and a tablet cannot inflate a record.
  static const double unitsPerMetre = 14;

  /// What one reference unit of travel down the road costs on this arena.
  double get travelScale => axisScale(arenaHeight, kReferenceArena.height);

  double get blockHeight => blockHeightRef * travelScale;

  final List<LaneBlock> blocks = [];

  int lane = 1;
  bool dead = false;

  /// Metres travelled. The score is this in km.
  double distance = 0;

  double _sinceSpawn = 0;
  double _elapsed = 0;

  /// Elapsed *simulated* seconds — the input to the shared ramp.
  double get elapsedSeconds => _elapsed;

  /// Speed in arena units per second. Rises, then flattens out.
  double get speed =>
      speedRef * travelScale * arcadeRamp(_elapsed, amount: speedRamp);

  /// The moving lane dashes are the only motion cue; this is their offset.
  double dashOffset = 0;

  String get scoreLabel => '${(distance / 1000).toStringAsFixed(2)} km';

  void reset() {
    blocks.clear();
    lane = 1;
    dead = false;
    distance = 0;
    _sinceSpawn = 0;
    _elapsed = 0;
    dashOffset = 0;
  }

  void moveLeft() {
    if (!dead && lane > 0) lane--;
  }

  void moveRight() {
    if (!dead && lane < lanes - 1) lane++;
  }

  void step(double dt) {
    if (dead) return;
    _elapsed += dt;
    final travelled = speed * dt;
    distance += travelled / travelScale / unitsPerMetre;
    dashOffset = (dashOffset + travelled) % (dashPeriodRef * travelScale);

    for (var i = 0; i < blocks.length; i++) {
      blocks[i] = LaneBlock(lane: blocks[i].lane, y: blocks[i].y + travelled);
    }
    blocks.removeWhere((b) => b.y > arenaHeight + blockHeight);

    // Spawn on distance rather than time, so the gap between rows is constant
    // in metres however fast the car is going.
    _sinceSpawn += travelled;
    final gap =
        (spawnGapRef + spawnGapEaseRef * (1 / (1 + distance / 1400))) * travelScale;
    if (_sinceSpawn >= gap) {
      _sinceSpawn = 0;
      _spawnRow();
    }

    final carTop = arenaHeight * carY;
    for (final b in blocks) {
      if (b.lane == lane && b.y + blockHeight > carTop && b.y < carTop + blockHeight * 0.8) {
        dead = true;
        return;
      }
    }
  }

  /// One or two blockers, never all three — there is always a way through.
  void _spawnRow() {
    final open = rng.nextInt(lanes);
    final pair = distance > 800 && rng.chance(0.45);
    for (var l = 0; l < lanes; l++) {
      if (l == open) continue;
      if (!pair && l != (open + 1) % lanes) continue;
      blocks.add(LaneBlock(lane: l, y: -blockHeight));
    }
  }
}
