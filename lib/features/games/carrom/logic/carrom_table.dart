import 'dart:math' as math;
import 'dart:ui';

/// What a disc on the board is.
enum CoinKind {
  /// The heavy disc the player flicks.
  striker,

  /// One side's nine coins.
  light,

  /// The other side's nine.
  dark,

  /// The one coin worth covering.
  queen,
}

/// A disc in the simulation. Mutable by design — the table steps thousands of
/// these a second and allocating a new one per step would be the whole cost.
class Disc {
  Disc({
    required this.kind,
    required this.position,
    required this.radius,
    required this.mass,
    this.velocity = Offset.zero,
  });

  final CoinKind kind;
  Offset position;
  Offset velocity;
  final double radius;
  final double mass;

  /// Once pocketed a disc leaves the simulation entirely.
  bool pocketed = false;

  bool get isCoin => kind != CoinKind.striker;
  double get speed => velocity.distance;

  Disc copy() => Disc(
        kind: kind,
        position: position,
        radius: radius,
        mass: mass,
        velocity: velocity,
      )..pocketed = pocketed;
}

/// The physical constants, in board units where the playing surface is 1×1.
/// Grouped so a test can slow the board down or shrink the pockets without
/// touching the solver.
class CarromPhysics {
  const CarromPhysics({
    this.coinRadius = 0.024,
    this.strikerRadius = 0.032,
    this.pocketRadius = 0.045,
    this.deceleration = 0.62,
    this.restitution = 0.72,
    this.wallRestitution = 0.68,
    this.maxSpeed = 1.9,
    this.restSpeed = 0.008,
    this.substeps = 4,
  });

  final double coinRadius;
  final double strikerRadius;
  final double pocketRadius;

  /// Board units per second squared, applied against the direction of travel —
  /// felt slows a disc at a roughly constant rate rather than exponentially.
  final double deceleration;

  final double restitution;
  final double wallRestitution;
  final double maxSpeed;

  /// Below this a disc is treated as stopped, so a shot always terminates.
  final double restSpeed;

  /// Collision passes per fixed step. A striker at full speed covers more than
  /// its own radius in 16ms, so a single pass would let it pass through a coin.
  final int substeps;
}

/// The table: discs, walls, pockets, and the solver that moves them.
///
/// Pure and deterministic — same discs, same steps, same result, with no
/// randomness and no dependence on real time. That is what makes a shot
/// unit-testable without ever rendering a frame.
class CarromTable {
  CarromTable({this.physics = const CarromPhysics()});

  final CarromPhysics physics;
  final List<Disc> discs = [];

  /// Filled by [step] as discs go down, in the order they fell.
  final List<Disc> pocketedThisShot = [];

  /// Whether the striker has touched any coin since the shot began. A shot that
  /// touches nothing is a foul, and this is the cheapest place to notice.
  bool strikerTouchedCoin = false;

  /// The four pocket centres, at the corners of the playing area.
  static const List<Offset> pockets = [
    Offset(0, 0),
    Offset(1, 0),
    Offset(0, 1),
    Offset(1, 1),
  ];

  Disc? get striker {
    for (final d in discs) {
      if (d.kind == CoinKind.striker && !d.pocketed) return d;
    }
    return null;
  }

  Iterable<Disc> get live => discs.where((d) => !d.pocketed);

  bool get atRest => live.every((d) => d.speed <= physics.restSpeed);

  /// Advances the whole table by [dt] seconds. Called only from the fixed-step
  /// loop, so [dt] is always the same value.
  void step(double dt) {
    final sub = dt / physics.substeps;
    for (var i = 0; i < physics.substeps; i++) {
      _integrate(sub);
      _collideWalls();
      _collideDiscs();
      _sinkPocketed();
    }
  }

  void _integrate(double dt) {
    for (final disc in live) {
      final speed = disc.speed;
      if (speed <= physics.restSpeed) {
        disc.velocity = Offset.zero;
        continue;
      }
      disc.position += disc.velocity * dt;
      final slowed = math.max(0.0, speed - physics.deceleration * dt);
      disc.velocity = slowed == 0 ? Offset.zero : disc.velocity * (slowed / speed);
    }
  }

  void _collideWalls() {
    for (final disc in live) {
      final r = disc.radius;
      var (x, y) = (disc.position.dx, disc.position.dy);
      var (vx, vy) = (disc.velocity.dx, disc.velocity.dy);
      if (x < r) {
        x = r;
        vx = vx.abs() * physics.wallRestitution;
      } else if (x > 1 - r) {
        x = 1 - r;
        vx = -vx.abs() * physics.wallRestitution;
      }
      if (y < r) {
        y = r;
        vy = vy.abs() * physics.wallRestitution;
      } else if (y > 1 - r) {
        y = 1 - r;
        vy = -vy.abs() * physics.wallRestitution;
      }
      disc.position = Offset(x, y);
      disc.velocity = Offset(vx, vy);
    }
  }

  void _collideDiscs() {
    final active = live.toList();
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        _resolvePair(active[i], active[j]);
      }
    }
  }

  /// An equal-restitution impulse along the contact normal, plus a positional
  /// push-apart. Without the push, two discs that arrive overlapping stay
  /// overlapped and jitter against each other forever.
  void _resolvePair(Disc a, Disc b) {
    final delta = b.position - a.position;
    final distance = delta.distance;
    final minimum = a.radius + b.radius;
    if (distance >= minimum || distance == 0) return;

    final normal = delta / distance;
    final overlap = minimum - distance;
    final totalMass = a.mass + b.mass;
    a.position -= normal * (overlap * (b.mass / totalMass));
    b.position += normal * (overlap * (a.mass / totalMass));

    final relative = b.velocity - a.velocity;
    final along = relative.dx * normal.dx + relative.dy * normal.dy;
    if (along > 0) return; // already separating

    if (a.kind == CoinKind.striker || b.kind == CoinKind.striker) {
      strikerTouchedCoin = true;
    }

    final impulse = -(1 + physics.restitution) * along / (1 / a.mass + 1 / b.mass);
    a.velocity -= normal * (impulse / a.mass);
    b.velocity += normal * (impulse / b.mass);
  }

  void _sinkPocketed() {
    for (final disc in live) {
      for (final pocket in pockets) {
        if ((disc.position - pocket).distance <= physics.pocketRadius) {
          disc.pocketed = true;
          disc.velocity = Offset.zero;
          pocketedThisShot.add(disc);
          break;
        }
      }
    }
  }

  /// Flicks the striker. [direction] need not be normalised; [power] is 0–1 and
  /// maps onto the physics' speed ceiling.
  void shoot(Offset direction, double power) {
    final s = striker;
    if (s == null) return;
    final length = direction.distance;
    if (length == 0) return;
    pocketedThisShot.clear();
    strikerTouchedCoin = false;
    s.velocity = direction / length * (physics.maxSpeed * power.clamp(0.0, 1.0));
  }

  /// Runs the table forward until everything stops, capped so a pathological
  /// state can never hang. Returns the steps taken.
  int settle({double dt = 1 / 62.5, int maxSteps = 2000}) {
    var steps = 0;
    while (!atRest && steps < maxSteps) {
      step(dt);
      steps++;
    }
    return steps;
  }
}
