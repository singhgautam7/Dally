import '../../../../core/util/dally_random.dart';

/// A pair of pillars with a gap between them. [gapCentre] and [gapHeight] are
/// in arena units; the pillars are everything above and below.
class Pillar {
  Pillar({required this.x, required this.gapCentre, required this.gapHeight});

  double x;
  final double gapCentre;
  final double gapHeight;

  /// Set once the token has passed it, so a pillar scores exactly once.
  bool scored = false;

  double get gapTop => gapCentre - gapHeight / 2;
  double get gapBottom => gapCentre + gapHeight / 2;
}

/// Updraft — the one-tap flyer.
///
/// Gravity pulls the token down; every tap gives it one upward beat. It is
/// **mechanically distinct from Avoider**, which runs along a floor and dodges
/// obstacles with a single jump: here the token is airborne the whole run and
/// the pillars come in pairs with a gap between them, so the failure mode is
/// vertical rather than horizontal. Both stay.
///
/// Everything is expressed against the measured arena, so a tablet is the same
/// run at a larger scale rather than a different game. Generation draws from the
/// injected [DallyRandom], so a seeded instance replays a run exactly.
class UpdraftCore {
  UpdraftCore({
    required this.rng,
    required this.arenaWidth,
    required this.arenaHeight,
  }) {
    reset();
  }

  final DallyRandom rng;
  final double arenaWidth;
  final double arenaHeight;

  /// The token's box. Every style shares it, so no style is easier.
  static const double tokenSize = 26;

  /// Tuning, authored against a 560-tall arena and scaled from there.
  static const double referenceHeight = 560;

  /// The gap starts generous and narrows over the first twenty pillars.
  static const double gapStartTokens = 4.2;
  static const double gapEndTokens = 3.2;
  static const int gapNarrowsOver = 20;

  /// Pillar spacing tightens from 2.4 to 1.8 arena widths per second.
  static const double spacingStartSeconds = 2.4;
  static const double spacingEndSeconds = 1.8;

  static const double gravityRef = 1500;
  static const double beatImpulseRef = -430;
  static const double speedRef = 150;

  /// Tilt follows vertical speed, capped — the only rotation anywhere in Dally,
  /// and it earns its place by reading as intent.
  static const double maxTiltDegrees = 24;

  double get scale => (arenaHeight / referenceHeight).clamp(0.6, 2.6);

  double get gravity => gravityRef * scale;
  double get beatImpulse => beatImpulseRef * scale;
  double get tokenHeight => tokenSize * scale;

  /// Horizontal speed, in arena units per second.
  double get speed => speedRef * scale;

  final List<Pillar> pillars = [];

  /// The token's centre height, and its vertical speed.
  double y = 0;
  double velocity = 0;

  bool dead = false;
  int score = 0;

  double _sinceSpawn = 0;
  int _spawned = 0;

  /// Tilt in degrees, `-maxTilt … +maxTilt`, from the current vertical speed.
  double get tiltDegrees {
    // A full-strength beat reads as the full upward tilt; terminal fall as the
    // full downward one.
    final t = (velocity / (-beatImpulse * 1.6)).clamp(-1.0, 1.0);
    return t * maxTiltDegrees;
  }

  /// The gap, in token heights, for the [n]th pillar.
  double gapTokensFor(int n) {
    final t = (n / gapNarrowsOver).clamp(0.0, 1.0);
    return gapStartTokens + (gapEndTokens - gapStartTokens) * t;
  }

  /// Seconds between pillars at the [n]th one.
  double spacingSecondsFor(int n) {
    final t = (n / gapNarrowsOver).clamp(0.0, 1.0);
    return spacingStartSeconds + (spacingEndSeconds - spacingStartSeconds) * t;
  }

  double get pillarWidth => 34 * scale;

  void reset() {
    pillars.clear();
    dead = false;
    score = 0;
    y = arenaHeight / 2;
    velocity = 0;
    _sinceSpawn = 0;
    _spawned = 0;
    _spawn();
  }

  /// One upward beat. It always clears a full gap from the bottom of one, which
  /// is what makes the tuning generous rather than punishing.
  void beat() {
    if (dead) return;
    velocity = beatImpulse;
  }

  void _spawn() {
    final gapHeight = gapTokensFor(_spawned) * tokenHeight;
    // The gap centre stays clear of both edges by half a gap plus a margin, so
    // a pillar is never unflyable.
    final margin = gapHeight / 2 + tokenHeight * 0.6;
    final lo = margin;
    final hi = arenaHeight - margin;
    final centre = hi <= lo ? arenaHeight / 2 : lo + rng.nextDouble() * (hi - lo);
    pillars.add(Pillar(
      x: arenaWidth + pillarWidth,
      gapCentre: centre,
      gapHeight: gapHeight,
    ));
    _spawned++;
  }

  /// One fixed simulation step. [dt] is the loop's constant delta, so the run is
  /// identical on a 60, 90 or 120 Hz panel.
  void step(double dt) {
    if (dead) return;

    velocity += gravity * dt;
    y += velocity * dt;

    final travelled = speed * dt;
    for (final p in pillars) {
      p.x -= travelled;
    }
    pillars.removeWhere((p) => p.x + pillarWidth < -pillarWidth);

    _sinceSpawn += dt;
    if (_sinceSpawn >= spacingSecondsFor(_spawned)) {
      _sinceSpawn = 0;
      _spawn();
    }

    final half = tokenHeight / 2;
    final left = tokenX - half;
    final right = tokenX + half;

    for (final p in pillars) {
      // Scoring: the pillar is behind the token, once.
      if (!p.scored && p.x + pillarWidth < left) {
        p.scored = true;
        score++;
      }
      final overlapsX = p.x < right && p.x + pillarWidth > left;
      if (overlapsX && (y - half < p.gapTop || y + half > p.gapBottom)) {
        dead = true;
        return;
      }
    }

    // The ceiling and the floor are the other two ways to end a run.
    if (y - half <= 0 || y + half >= arenaHeight) {
      y = y.clamp(half, arenaHeight - half);
      dead = true;
    }
  }

  /// The token flies at a fixed x; the world moves past it.
  double get tokenX => arenaWidth * 0.28;
}
