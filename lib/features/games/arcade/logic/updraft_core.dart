import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/game/arena_scale.dart';
import '../../../../core/util/dally_random.dart';
import 'updraft_token.dart';

/// Where an obstacle's solid parts sit.
enum PillarPlacement {
  /// A slab from the ceiling and one from the floor, with a gap between —
  /// the staple.
  both,

  /// Only a slab hanging from the ceiling. The floor is clear.
  top,

  /// Only a slab rising from the floor. The ceiling is clear.
  bottom,
}

/// One obstacle column.
///
/// The lane from [openTop] to [openBottom] is clear and everything else in the
/// column is solid, so all three [PillarPlacement]s are the same two rects —
/// one of which is simply empty for a one-sided pillar.
class Pillar {
  Pillar({
    required this.x,
    required this.openTop,
    required this.openBottom,
    required this.placement,
  });

  double x;

  /// The passable lane, in arena units.
  final double openTop;
  final double openBottom;

  final PillarPlacement placement;

  /// Set once the token has passed it, so a pillar scores exactly once.
  bool scored = false;

  double get gapHeight => openBottom - openTop;

  /// The middle of the passable lane — where a perfect driver aims.
  double get gapCentre => (openTop + openBottom) / 2;
}

/// Updraft — the one-tap flyer.
///
/// Gravity pulls the token down; every tap gives it one upward beat. It is
/// **mechanically distinct from Avoider**, which runs along a floor and dodges
/// obstacles with a single jump: here the token is airborne the whole run and
/// the obstacles leave one lane through a column — between two slabs, or under
/// one hanging from the ceiling, or over one rising from the floor — so the
/// failure mode is vertical rather than horizontal. Both stay.
///
/// Everything is expressed against the measured arena, so a tablet is the same
/// run at a larger scale rather than a different game. Generation draws from the
/// injected [DallyRandom], so a seeded instance replays a run exactly.
class UpdraftCore {
  UpdraftCore({
    required this.rng,
    required this.arenaWidth,
    required this.arenaHeight,
    this.token = UpdraftToken.dart,
  }) {
    reset();
  }

  final DallyRandom rng;

  /// The selected token style. Collision is tested against the silhouette this
  /// draws, so a dart is not punished for the corners of a box it does not
  /// have. Set from the screen when the style changes; it never affects
  /// generation, so a seeded run is the same run in every style.
  UpdraftToken token;
  final double arenaWidth;
  final double arenaHeight;

  /// The box every token style is drawn inside. The *silhouette* within it is
  /// what collides, so a dart is not punished for corners it does not have —
  /// see [silhouette].
  static const double tokenSize = 26;

  /// Tuning, authored against [kReferenceArena] and scaled from there.

  /// The gap starts generous and narrows over the first twenty pillars.
  static const double gapStartTokens = 4.2;
  static const double gapEndTokens = 3.2;
  static const int gapNarrowsOver = 20;

  /// Pillar spacing tightens from 2.4 to 1.8 arena widths per second.
  static const double spacingStartSeconds = 2.4;
  static const double spacingEndSeconds = 1.8;

  /// Spawn weights for the three placements. Two-sided stays the staple; the
  /// one-sided columns are the variety, and both are strictly easier to pass,
  /// which is why they get a narrower lane than a two-sided gap.
  static const double bothWeight = 0.5;
  static const double topOnlyWeight = 0.25;

  static const double gravityRef = 1500;
  static const double beatImpulseRef = -430;
  static const double speedRef = 150;

  /// Tilt follows vertical speed, capped — the only rotation anywhere in Dally,
  /// and it earns its place by reading as intent.
  static const double maxTiltDegrees = 24;

  /// The uniform size factor — the shared [arenaScale], so every arcade game
  /// answers to the same number.
  double get scale => arenaScale(Size(arenaWidth, arenaHeight));

  /// What one reference unit of *horizontal travel* costs on this arena. A
  /// pillar has to take the same seconds to arrive at every width, which the
  /// size factor alone does not give on a wide screen.
  double get travelScale => axisScale(arenaWidth, kReferenceArena.width);

  double get gravity => gravityRef * scale;
  double get beatImpulse => beatImpulseRef * scale;
  double get tokenHeight => tokenSize * scale;

  /// Horizontal speed, in arena units per second.
  double get speed => speedRef * travelScale;

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

  double get pillarWidth => 34 * travelScale;

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
    final roll = rng.nextDouble();
    final placement = roll < bothWeight
        ? PillarPlacement.both
        : (roll < bothWeight + topOnlyWeight
            ? PillarPlacement.top
            : PillarPlacement.bottom);

    double openTop, openBottom;
    if (placement == PillarPlacement.both) {
      // The gap centre stays clear of both edges by half a gap plus a margin,
      // so a pillar is never unflyable.
      final margin = gapHeight / 2 + tokenHeight * 0.6;
      final lo = margin;
      final hi = arenaHeight - margin;
      final centre = hi <= lo ? arenaHeight / 2 : lo + rng.nextDouble() * (hi - lo);
      openTop = centre - gapHeight / 2;
      openBottom = centre + gapHeight / 2;
    } else {
      // One slab, one open edge. The lane is a little wider than a two-sided
      // gap because you only get one edge to judge it against, and it is capped
      // so the slab is always a real obstacle rather than a stub.
      final lane = math.min(
        gapHeight * (1.15 + rng.nextDouble() * 0.45),
        arenaHeight - tokenHeight * 1.2,
      );
      if (placement == PillarPlacement.top) {
        openTop = arenaHeight - lane;
        openBottom = arenaHeight;
      } else {
        openTop = 0;
        openBottom = lane;
      }
    }

    pillars.add(Pillar(
      x: arenaWidth + pillarWidth,
      openTop: openTop,
      openBottom: openBottom,
      placement: placement,
    ));
    _spawned++;
  }

  /// The token's collision shape right now — the silhouette the painter draws.
  TokenSilhouette get silhouette => updraftSilhouette(
        token: token,
        centre: Offset(tokenX, y),
        size: tokenHeight,
        tiltRadians: updraftTokenTilts(token) ? tiltDegrees * math.pi / 180 : 0,
      );

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

    final shape = silhouette;

    for (final p in pillars) {
      // Scoring: the pillar is behind the token, once.
      if (!p.scored && p.x + pillarWidth < shape.left) {
        p.scored = true;
        score++;
      }
      // Both slabs, either of which may be empty on a one-sided pillar.
      if (shape.hitsRect(Rect.fromLTRB(p.x, 0, p.x + pillarWidth, p.openTop)) ||
          shape.hitsRect(
              Rect.fromLTRB(p.x, p.openBottom, p.x + pillarWidth, arenaHeight))) {
        dead = true;
        return;
      }
    }

    // The ceiling and the floor are the other two ways to end a run.
    if (shape.top <= 0 || shape.bottom >= arenaHeight) {
      y = y.clamp(y - shape.top, arenaHeight - (shape.bottom - y));
      dead = true;
    }
  }

  /// The token flies at a fixed x; the world moves past it.
  double get tokenX => arenaWidth * 0.28;
}
