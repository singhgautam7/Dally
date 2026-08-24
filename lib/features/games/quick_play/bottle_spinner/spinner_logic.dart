import 'dart:math' as math;

import '../../../../core/util/dally_random.dart';

/// A spin result. The target is chosen *first* and the animation follows — an
/// overshoot or a near-miss bias would read as rigging the result, so there is
/// neither: ease-out only, no weighting.
class SpinResult {
  const SpinResult({required this.seatIndex, required this.turns, required this.endAngle});

  /// The winning seat, or -1 in no-names mode where the pointer just lands on a
  /// free angle.
  final int seatIndex;

  /// Whole turns before the offset, 3–5.
  final int turns;

  /// Final pointer angle in radians, measured clockwise from straight up.
  final double endAngle;
}

/// Spins for a ring of [seatCount] players. With no seats the pointer lands
/// anywhere in 0–360° and whoever it faces is it.
SpinResult spin(DallyRandom rng, int seatCount) {
  final turns = rng.range(3, 5);
  if (seatCount <= 0) {
    return SpinResult(
      seatIndex: -1,
      turns: turns,
      endAngle: turns * 2 * math.pi + rng.nextDouble() * 2 * math.pi,
    );
  }
  final seat = rng.nextInt(seatCount);
  return SpinResult(
    seatIndex: seat,
    turns: turns,
    endAngle: turns * 2 * math.pi + seatAngle(seat, seatCount),
  );
}

/// Where seat [i] of [count] sits on the ring, radians clockwise from up.
double seatAngle(int i, int count) => count == 0 ? 0 : 2 * math.pi * i / count;

/// Bottle Spinner needs at least two players; Skip is always the escape.
const int minSpinnerPlayers = 2;
const int maxSpinnerPlayers = 12;

/// Names longer than this truncate with an ellipsis on the ring.
const int spinnerNameLimit = 10;

String seatLabel(String name, {required bool initialsOnly}) {
  if (name.isEmpty) return '?';
  if (initialsOnly) return name.substring(0, 1).toUpperCase();
  return name.length <= spinnerNameLimit
      ? name
      : '${name.substring(0, spinnerNameLimit)}…';
}
