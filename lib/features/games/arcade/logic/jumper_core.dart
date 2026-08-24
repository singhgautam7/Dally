import '../../../../core/util/dally_random.dart';

/// One platform. Coordinates are in arena units: x across the arena width,
/// y as *world* height (grows upward, so the camera is a subtraction).
class Platform {
  const Platform({required this.x, required this.y, required this.width});
  final double x;
  final double y;
  final double width;
}

/// Jumper's simulation. Bouncing is automatic; the only input is left/right.
///
/// Platforms generate in bands of **fixed vertical gap** and random horizontal
/// slot, so the next platform is always within jump range — a run is always
/// survivable, and never memorised.
class JumperCore {
  JumperCore({
    required this.rng,
    required this.arenaWidth,
    required this.arenaHeight,
  }) {
    reset();
  }

  final DallyRandom rng;
  final double arenaWidth;
  final double arenaHeight;

  /// The fixed vertical spacing between platform bands. Chosen against
  /// [jumpImpulse] and [gravity] so the apex always clears it.
  static const double bandGap = 78;
  static const double gravity = 1400;
  static const double jumpImpulse = -560;
  static const double moveSpeed = 260;
  static const double playerSize = 22;
  static const double platformHeight = 8;

  final List<Platform> platforms = [];

  double playerX = 0;
  double playerY = 0;
  double velocityY = 0;

  /// -1, 0 or 1 — the whole input surface.
  int steer = 0;

  /// How high the camera has climbed. This is the score.
  double height = 0;

  bool dead = false;

  /// The highest band generated so far, in world units.
  double _topBand = 0;

  int get score => height ~/ 10;

  void reset() {
    platforms.clear();
    dead = false;
    height = 0;
    velocityY = jumpImpulse;
    playerX = arenaWidth / 2;
    playerY = arenaHeight * 0.5;
    _topBand = 0;
    // A guaranteed platform directly under the start, then the bands above it.
    platforms.add(Platform(x: playerX - 34, y: playerY - playerSize, width: 68));
    for (var i = 1; i <= (arenaHeight / bandGap).ceil() + 4; i++) {
      _addBand(playerY - playerSize - i * bandGap);
    }
  }

  void _addBand(double y) {
    final width = 62 + rng.nextDouble() * 24;
    platforms.add(Platform(
      x: rng.nextDouble() * (arenaWidth - width),
      y: y,
      width: width,
    ));
    if (y < _topBand) _topBand = y;
  }

  /// One fixed simulation step. [dt] is the loop's constant delta, so the climb
  /// is identical on a 60, 90 or 120 Hz panel.
  void step(double dt) {
    if (dead) return;

    playerX += steer * moveSpeed * dt;
    // Wrapping the sides keeps a run alive rather than trapping the player.
    if (playerX < -playerSize) playerX = arenaWidth;
    if (playerX > arenaWidth) playerX = -playerSize;

    velocityY += gravity * dt;
    playerY += velocityY * dt;

    // Landing is only tested while falling, so a platform can be jumped through
    // from below.
    if (velocityY > 0) {
      for (final p in platforms) {
        final feet = playerY + playerSize;
        if (feet >= p.y &&
            feet <= p.y + platformHeight + velocityY * dt &&
            playerX + playerSize > p.x &&
            playerX < p.x + p.width) {
          velocityY = jumpImpulse;
          break;
        }
      }
    }

    // The camera pulls the world down once the player passes the midline; the
    // distance it pulls is the score.
    final threshold = arenaHeight * 0.42;
    if (playerY < threshold) {
      final lift = threshold - playerY;
      playerY = threshold;
      height += lift;
      for (var i = 0; i < platforms.length; i++) {
        platforms[i] = Platform(
          x: platforms[i].x,
          y: platforms[i].y + lift,
          width: platforms[i].width,
        );
      }
      _topBand += lift;
      while (_topBand > -bandGap) {
        _addBand(_topBand - bandGap);
      }
      platforms.removeWhere((p) => p.y > arenaHeight + bandGap);
    }

    if (playerY > arenaHeight) dead = true;
  }
}
