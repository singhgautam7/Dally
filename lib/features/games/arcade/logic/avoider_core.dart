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
class AvoiderCore {
  AvoiderCore({required this.rng, required this.arenaWidth});

  final DallyRandom rng;
  final double arenaWidth;

  static const double gravity = 2600;
  static const double jumpImpulse = -780;
  static const double playerSize = 24;
  static const double playerX = 60;

  static const List<double> heights = [22, 34, 46];

  /// Arena units per metre. Physics stays in arena units (so the guaranteed
  /// landing gap is a geometric fact); only the score and the difficulty
  /// thresholds are expressed in metres.
  static const double unitsPerMetre = 14;

  final List<Obstacle> obstacles = [];

  /// Height above the line, 0 when grounded.
  double y = 0;
  double velocityY = 0;
  bool dead = false;

  /// Metres survived. This is the score and the only thing tracked.
  double distance = 0;

  double _sinceSpawn = 0;

  bool get grounded => y >= 0;

  /// Speed rises every 250 m.
  double get speed => 240 + (distance ~/ 250) * 22;

  /// How far the square travels during one full jump — the floor for any gap.
  double get jumpSpan => speed * (2 * -jumpImpulse / gravity);

  int get score => distance.round();

  void reset() {
    obstacles.clear();
    y = 0;
    velocityY = 0;
    dead = false;
    distance = 0;
    _sinceSpawn = 0;
  }

  void jump() {
    if (dead || !grounded) return;
    velocityY = jumpImpulse;
    y = -0.01;
  }

  void step(double dt) {
    if (dead) return;
    final travelled = speed * dt;
    distance += travelled / unitsPerMetre;

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
    obstacles.removeWhere((o) => o.x < -40);

    _sinceSpawn += travelled;
    if (_sinceSpawn >= _nextGap) {
      _sinceSpawn = 0;
      _spawn();
    }

    // A hit is only a hit when the square is low enough to catch the obstacle.
    for (final o in obstacles) {
      final overlapsX = o.x < playerX + playerSize && o.x + 18 > playerX;
      if (overlapsX && -y < o.height) {
        dead = true;
        return;
      }
    }
  }

  double _nextGap = 260;

  void _spawn() {
    final height = rng.pick(heights);
    obstacles.add(Obstacle(x: arenaWidth + 20, height: height));

    // Past 1000 m obstacles arrive in pairs — still with a landing gap between
    // them, so the pair is always clearable in two jumps.
    if (distance > 1000 && rng.chance(0.4)) {
      obstacles.add(Obstacle(x: arenaWidth + 20 + jumpSpan * 1.15, height: rng.pick(heights)));
    }

    // Two spacings, both at least a full jump apart.
    final tight = rng.nextBool();
    _nextGap = jumpSpan * (tight ? 1.25 : 1.9);
  }
}
