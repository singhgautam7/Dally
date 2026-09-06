import 'dart:math' as math;
import 'dart:ui';

/// The virtual arena every real-time game is authored against: a mid-size phone
/// with the chrome removed.
const Size kReferenceArena = Size(354, 560);

/// The uniform scale of the virtual arena inside a measured one.
///
/// This is the factor every *thing* is measured at — a player, an obstacle, a
/// platform — so shapes never distort and a tablet is the same game at a larger
/// size. It is deliberately **not** what a *journey* across the arena costs:
/// travel along an axis is a fraction of that axis ([axisScale]), which is what
/// keeps reaction time the same on a wide screen as on a narrow one.
///
/// Clamped so a very short or very wide arena stays playable rather than
/// turning into a different game.
double arenaScale(Size arena, {double min = 0.6, double max = 2.6}) => math
    .min(arena.width / kReferenceArena.width, arena.height / kReferenceArena.height)
    .clamp(min, max);

/// How much of the real arena one reference unit of travel covers along an
/// axis. Multiply an authored speed, spacing or spawn gap by this and the
/// player gets the same seconds to react at every size.
double axisScale(double measured, double reference) => measured / reference;

/// The shared arcade difficulty curve.
///
/// A multiplier that starts at 1 and eases toward `1 + amount`, reaching about
/// 63% of the rise at [overSeconds]. [elapsedSeconds] comes from the fixed-step
/// loop's accumulated `dt`, so the progression is identical wall-clock time on a
/// 60, 90 or 120 Hz panel — and a test can assert its value at a given moment
/// without touching a clock.
double arcadeRamp(double elapsedSeconds, {required double amount, double overSeconds = 60}) =>
    1 + amount * (1 - math.exp(-elapsedSeconds / overSeconds));
