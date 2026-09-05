import 'dart:math' as math;

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
/// **Everything here scales with the arena.** The tuning below is authored
/// against a reference arena and multiplied by `scale = arenaHeight /
/// referenceHeight`, so a tablet is the same game at a larger size rather than
/// a different one. It used to be a set of pixel constants, and the failure
/// that produced was not subtle: on a large screen the arena grew but the
/// bounce did not, the horizontal slot for the next platform was drawn from the
/// *whole* width, and the gap between one platform and the next routinely
/// exceeded how far a player could travel in one bounce — so the player could
/// never ascend at all.
///
/// Two things keep that fixed:
///
/// 1. Gravity, impulse, band gap, run speed and every size are `scale`d.
/// 2. A new platform's x is drawn from the span the player can actually reach
///    from the one below it ([_reachX]), not from the arena width.
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

  /// The arena the tuning below is authored against. A 560-tall arena is a
  /// mid-size phone with the chrome removed.
  static const double referenceHeight = 560;

  // ── Authored tuning, in reference units ──────────────────────────────────

  static const double bandGapRef = 78;
  static const double gravityRef = 1400;
  static const double jumpImpulseRef = -560;
  static const double moveSpeedRef = 260;
  static const double playerSizeRef = 22;
  static const double platformHeightRef = 8;
  static const double platformWidthRef = 62;
  static const double platformWidthVarianceRef = 24;

  /// How the reference arena maps onto this one. Clamped so a very short or
  /// very tall arena stays playable rather than turning into a different game.
  double get scale => (arenaHeight / referenceHeight).clamp(0.6, 2.6);

  double get bandGap => bandGapRef * scale;
  double get gravity => gravityRef * scale;
  double get jumpImpulse => jumpImpulseRef * scale;
  double get moveSpeed => moveSpeedRef * scale;
  double get playerSize => playerSizeRef * scale;
  double get platformHeight => platformHeightRef * scale;

  /// How high one bounce carries: `v² / 2g`. Scale cancels in the ratio, so the
  /// apex is always the same multiple of [bandGap] — which is what makes the
  /// climb possible at every size.
  double get jumpApex => (jumpImpulse * jumpImpulse) / (2 * gravity);

  /// Seconds in the air for one whole bounce.
  double get airTime => 2 * -jumpImpulse / gravity;

  /// Seconds from leaving one platform to reaching the *next band's* height —
  /// the only part of a bounce that is any use for getting onto it.
  ///
  /// `bandGap = v·t − ½g·t²`, taking the first root. The apex always clears the
  /// gap ([jumpApex] > [bandGap]), so the root is always real.
  double get timeToBand {
    final v = -jumpImpulse;
    final disc = v * v - 2 * gravity * bandGap;
    if (disc <= 0) return airTime / 2;
    return (v - math.sqrt(disc)) / gravity;
  }

  /// How far sideways the player can travel while rising one band. This is the
  /// budget the generator has to stay inside, and the number the shipped
  /// version never had: it drew the next platform's x from the whole arena
  /// width, so on a wide screen the next band was routinely several times this
  /// far away and the climb was impossible.
  double get reach => moveSpeed * timeToBand;

  final List<Platform> platforms = [];

  double playerX = 0;
  double playerY = 0;
  double velocityY = 0;

  /// -1, 0 or 1 — the whole input surface.
  int steer = 0;

  /// How high the camera has climbed. This is the score.
  double height = 0;

  bool dead = false;

  /// The highest band generated so far, in world units, and where it sits.
  double _topBand = 0;
  double _topBandX = 0;

  int get score => height ~/ 10;

  void reset() {
    platforms.clear();
    dead = false;
    height = 0;
    velocityY = jumpImpulse;
    playerX = arenaWidth / 2;
    playerY = arenaHeight * 0.5;
    // A guaranteed platform directly under the start, then the bands above it.
    final startWidth = platformWidthRef * scale;
    platforms.add(Platform(
        x: playerX - startWidth / 2, y: playerY - playerSize, width: startWidth));
    _topBand = playerY - playerSize;
    _topBandX = playerX - startWidth / 2;
    for (var i = 1; i <= (arenaHeight / bandGap).ceil() + 4; i++) {
      _addBand(playerY - playerSize - i * bandGap);
    }
  }

  void _addBand(double y) {
    final width = (platformWidthRef + rng.nextDouble() * platformWidthVarianceRef) * scale;
    final x = _reachX(width);
    platforms.add(Platform(x: x, y: y, width: width));
    if (y < _topBand) {
      _topBand = y;
      _topBandX = x;
    }
  }

  /// A left edge the player can actually get to from the band below.
  ///
  /// The window is one bounce of horizontal travel either side of the previous
  /// platform, clamped to the arena. On a phone that window is most of the
  /// width and the draw is effectively uniform; on a tablet it is what stops
  /// the next platform being generated three bounces away.
  double _reachX(double width) {
    final maxLeft = math.max(0.0, arenaWidth - width);
    if (maxLeft <= 0) return 0;
    // Both platforms' centres, so the reach is measured between the two things
    // the player actually stands on.
    final fromCentre = _topBandX + width / 2;
    // The whole budget, and not a pixel more: the design's promise is that the
    // next platform is always in range, so a run is always survivable and never
    // memorised.
    final window = reach;
    final lo = (fromCentre - window - width / 2).clamp(0.0, maxLeft);
    final hi = (fromCentre + window - width / 2).clamp(0.0, maxLeft);
    if (hi <= lo) return lo;
    return lo + rng.nextDouble() * (hi - lo);
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
    // distance it pulls is the score. The threshold is a *fraction* of the
    // arena, so it lands in the same place on every screen.
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
