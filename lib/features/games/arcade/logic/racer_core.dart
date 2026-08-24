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
class RacerCore {
  RacerCore({required this.rng, required this.arenaHeight});

  final DallyRandom rng;
  final double arenaHeight;

  static const int lanes = 3;
  static const double carY = 0.78;
  static const double blockHeight = 46;

  /// Arena units per metre — see [AvoiderCore.unitsPerMetre]. Spawn spacing
  /// stays in arena units; distance and the speed curve are in metres.
  static const double unitsPerMetre = 14;

  final List<LaneBlock> blocks = [];

  int lane = 1;
  bool dead = false;

  /// Metres travelled. The score is this in km.
  double distance = 0;

  double _sinceSpawn = 0;

  /// Speed in arena units per second. Rises, then flattens out.
  double get speed => 240 + 320 * (1 - 1 / (1 + distance / 900));

  /// The moving lane dashes are the only motion cue; this is their offset.
  double dashOffset = 0;

  String get scoreLabel => '${(distance / 1000).toStringAsFixed(2)} km';

  void reset() {
    blocks.clear();
    lane = 1;
    dead = false;
    distance = 0;
    _sinceSpawn = 0;
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
    final travelled = speed * dt;
    distance += travelled / unitsPerMetre;
    dashOffset = (dashOffset + travelled) % 60;

    for (var i = 0; i < blocks.length; i++) {
      blocks[i] = LaneBlock(lane: blocks[i].lane, y: blocks[i].y + travelled);
    }
    blocks.removeWhere((b) => b.y > arenaHeight + blockHeight);

    // Spawn on distance rather than time, so the gap between rows is constant
    // in metres however fast the car is going.
    _sinceSpawn += travelled;
    final gap = 210 + 120 * (1 / (1 + distance / 1400));
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
