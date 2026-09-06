import 'dart:ui';

import '../../../../core/game/arena_scale.dart';
import '../../../../core/util/dally_random.dart';

/// One obstacle on the line. Heights come from a fixed set of three.
class Obstacle {
  const Obstacle({required this.x, required this.height});
  final double x;
  final double height;
}

/// Avoider's simulation: a square runs a hairline, a tap jumps.
///
/// Three obstacle heights × two spacings, mixed by a generator that
/// **guarantees a landing gap** — the spacing floor is derived from how far the
/// square travels during one whole jump, so a pair can never be unclearable.
///
/// **Everything is viewport-relative.** The tuning below is authored against
/// [kReferenceArena]; sizes are multiplied by the uniform [arenaScale] and the
/// run speed by the arena's *width* fraction, so an obstacle takes the same
/// number of seconds to arrive on a small phone and on a landscape tablet. It
/// used to be a set of absolute pixels: on a 1180-wide arena an obstacle took
/// 4.7s to cross instead of 1.2s, which is a different game.
class AvoiderCore {
  AvoiderCore({required this.rng, required this.arenaWidth, required this.arenaHeight});

  final DallyRandom rng;
  final double arenaWidth;
  final double arenaHeight;

  // ── Authored tuning, in reference units ──────────────────────────────────

  static const double gravityRef = 2600;
  static const double jumpImpulseRef = -780;
  static const double playerSizeRef = 24;
  static const double playerXRef = 60;
  static const double obstacleWidthRef = 18;
  static const double speedRef = 240;

  static const List<double> heightsRef = [22, 34, 46];

  /// How much faster the run gets over a long session — the shared curve, so
  /// the ramp reads the same in every arcade game.
  static const double speedRamp = 0.6;

  /// Reference units per metre. The score is computed from *reference* travel,
  /// never from arena pixels, so a metre is a metre on every screen.
  static const double unitsPerMetre = 14;

  /// The uniform size factor — a square stays a square.
  double get scale => arenaScale(Size(arenaWidth, arenaHeight));

  /// What one reference unit of forward travel costs on this arena.
  double get travelScale => axisScale(arenaWidth, kReferenceArena.width);

  double get playerSize => playerSizeRef * scale;
  double get playerX => playerXRef * scale;
  double get obstacleWidth => obstacleWidthRef * scale;

  /// Gravity and impulse both take the size factor, so the airtime is constant
  /// and the apex is always the same fraction of an obstacle's height.
  double get gravity => gravityRef * scale;
  double get jumpImpulse => jumpImpulseRef * scale;

  List<double> get heights => [for (final h in heightsRef) h * scale];

  final List<Obstacle> obstacles = [];

  /// Height above the line, 0 when grounded.
  double y = 0;
  double velocityY = 0;
  bool dead = false;

  /// Metres survived. This is the score and the only thing tracked.
  double distance = 0;

  double _sinceSpawn = 0;
  double _elapsed = 0;

  bool get grounded => y >= 0;

  /// Elapsed *simulated* seconds — the input to the shared ramp.
  double get elapsedSeconds => _elapsed;

  /// The run speed, in arena units per second.
  double get speed =>
      speedRef * travelScale * arcadeRamp(_elapsed, amount: speedRamp);

  /// Seconds in the air for one whole bounce. Constant at every size.
  double get airTime => 2 * -jumpImpulse / gravity;

  /// How far the square travels during one full jump — the floor for any gap.
  double get jumpSpan => speed * airTime;

  int get score => distance.round();

  void reset() {
    obstacles.clear();
    y = 0;
    velocityY = 0;
    dead = false;
    distance = 0;
    _sinceSpawn = 0;
    _elapsed = 0;
    _nextGap = jumpSpan * 1.4;
  }

  void jump() {
    if (dead || !grounded) return;
    velocityY = jumpImpulse;
    y = -0.01;
  }

  void step(double dt) {
    if (dead) return;
    _elapsed += dt;
    final travelled = speed * dt;
    // Metres come from *reference* travel, so a score means the same thing on
    // every screen and a tablet cannot inflate a record.
    distance += travelled / travelScale / unitsPerMetre;

    if (!grounded) {
      velocityY += gravity * dt;
      y += velocityY * dt;
      if (y >= 0) {
        y = 0;
        velocityY = 0;
      }
    }

    for (var i = 0; i < obstacles.length; i++) {
      obstacles[i] = Obstacle(x: obstacles[i].x - travelled, height: obstacles[i].height);
    }
    obstacles.removeWhere((o) => o.x < -obstacleWidth * 2);

    _sinceSpawn += travelled;
    if (_sinceSpawn >= _nextGap) {
      _sinceSpawn = 0;
      _spawn();
    }

    // A hit is only a hit when the square is low enough to catch the obstacle.
    for (final o in obstacles) {
      final overlapsX = o.x < playerX + playerSize && o.x + obstacleWidth > playerX;
      if (overlapsX && -y < o.height) {
        dead = true;
        return;
      }
    }
  }

  double _nextGap = 0;

  void _spawn() {
    final height = rng.pick(heights);
    obstacles.add(Obstacle(x: arenaWidth + obstacleWidth, height: height));

    // Past 1000 m obstacles arrive in pairs — still with a landing gap between
    // them, so the pair is always clearable in two jumps.
    if (distance > 1000 && rng.chance(0.4)) {
      obstacles.add(
          Obstacle(x: arenaWidth + obstacleWidth + jumpSpan * 1.15, height: rng.pick(heights)));
    }

    // Two spacings, both at least a full jump apart.
    final tight = rng.nextBool();
    _nextGap = jumpSpan * (tight ? 1.25 : 1.9);
  }
}
