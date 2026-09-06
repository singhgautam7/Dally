import 'dart:math' as math;

/// Two arms, one pivot, and no repetition.
///
/// Integrated with **RK4** on the fixed timestep. The naive Euler step this
/// replaced gains energy every frame and eventually flings the arms — the
/// classic double-pendulum blow-up. RK4 at 16ms holds the total energy flat for
/// as long as anyone will watch, which is the whole stability requirement.
///
/// Everything is in radians and unit lengths, so the renderer scales it to the
/// arena and the physics never knows a pixel.
class DoublePendulum {
  DoublePendulum({
    this.angle1 = 40 * math.pi / 180,
    this.angle2 = 10 * math.pi / 180,
  });

  /// Arm angles from straight down, and their angular velocities.
  double angle1;
  double angle2;
  double velocity1 = 0;
  double velocity2 = 0;

  /// Arm lengths and bob masses, in the sim's own units. Fixed: the toy has no
  /// knob for them, so the motion always reads as the same object.
  static const double length1 = 1;
  static const double length2 = 0.85;
  static const double mass1 = 1;
  static const double mass2 = 1;
  static const double gravity = 9.81;

  /// A whisper of damping. Without it the pendulum is a perpetual motion
  /// machine, which reads as a bug however correct it is.
  static const double damping = 0.9995;

  /// Where the trail has been, oldest first, in unit coordinates.
  final List<(double, double)> trail = [];

  /// Trail lengths, in samples.
  static const int shortTrail = 120;
  static const int longTrail = 600;

  /// The joint between the two arms, in unit coordinates from the pivot.
  (double, double) get joint =>
      (length1 * math.sin(angle1), length1 * math.cos(angle1));

  /// The tip — what the trail traces.
  (double, double) get tip {
    final (x, y) = joint;
    return (x + length2 * math.sin(angle2), y + length2 * math.cos(angle2));
  }

  /// Total energy. Constant motion means a constant number here, which is what
  /// makes "the integrator is stable" testable rather than a matter of taste.
  double get energy {
    final v1 = length1 * velocity1;
    final v2 = length2 * velocity2;
    final kinetic = 0.5 * mass1 * v1 * v1 +
        0.5 *
            mass2 *
            (v1 * v1 +
                v2 * v2 +
                2 * v1 * v2 * math.cos(angle1 - angle2));
    final potential = -(mass1 + mass2) * gravity * length1 * math.cos(angle1) -
        mass2 * gravity * length2 * math.cos(angle2);
    return kinetic + potential;
  }

  /// Puts the arms somewhere and stops them dead. What releasing a drag does.
  void set({required double a1, required double a2}) {
    angle1 = a1;
    angle2 = a2;
    velocity1 = 0;
    velocity2 = 0;
  }

  void reset() {
    // Both arms horizontal, per the design — an empty canvas would mean no
    // pendulum, so Reset is a pose rather than a clear.
    angle1 = math.pi / 2;
    angle2 = math.pi / 2;
    velocity1 = 0;
    velocity2 = 0;
    trail.clear();
  }

  /// The equations of motion: angular accelerations from the current state.
  (double, double) _accelerations(double a1, double a2, double w1, double w2) {
    const m1 = mass1, m2 = mass2, l1 = length1, l2 = length2, g = gravity;
    final delta = a1 - a2;
    final den = 2 * m1 + m2 - m2 * math.cos(2 * delta);

    final acc1 = (-g * (2 * m1 + m2) * math.sin(a1) -
            m2 * g * math.sin(a1 - 2 * a2) -
            2 * math.sin(delta) * m2 * (w2 * w2 * l2 + w1 * w1 * l1 * math.cos(delta))) /
        (l1 * den);
    final acc2 = (2 *
            math.sin(delta) *
            (w1 * w1 * l1 * (m1 + m2) +
                g * (m1 + m2) * math.cos(a1) +
                w2 * w2 * l2 * m2 * math.cos(delta))) /
        (l2 * den);
    return (acc1, acc2);
  }

  /// One fixed step, RK4. [dt] is the loop's constant delta, so the motion is
  /// identical on a 60, 90 or 120 Hz panel.
  void step(double dt, {int trailLimit = shortTrail, bool recordTrail = true}) {
    final y = [angle1, angle2, velocity1, velocity2];

    List<double> derivative(List<double> s) {
      final (a1, a2) = _accelerations(s[0], s[1], s[2], s[3]);
      return [s[2], s[3], a1, a2];
    }

    List<double> add(List<double> a, List<double> b, double scale) =>
        [for (var i = 0; i < 4; i++) a[i] + b[i] * scale];

    final k1 = derivative(y);
    final k2 = derivative(add(y, k1, dt / 2));
    final k3 = derivative(add(y, k2, dt / 2));
    final k4 = derivative(add(y, k3, dt));

    for (var i = 0; i < 4; i++) {
      y[i] += dt / 6 * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]);
    }

    angle1 = y[0];
    angle2 = y[1];
    velocity1 = y[2] * damping;
    velocity2 = y[3] * damping;

    if (!recordTrail) return;
    trail.add(tip);
    while (trail.length > trailLimit) {
      trail.removeAt(0);
    }
  }

  /// Grabs whichever bob is nearer [point] (unit coordinates) and hangs the
  /// rest from it, so the pose released is always a physical one.
  void dragTo((double, double) point, {required bool grabbedTip}) {
    final (px, py) = point;
    if (!grabbedTip) {
      angle1 = math.atan2(px, py);
      // The lower arm hangs from wherever the upper one now points.
      angle2 = angle1;
    } else {
      final (jx, jy) = joint;
      angle2 = math.atan2(px - jx, py - jy);
    }
    velocity1 = 0;
    velocity2 = 0;
  }

  /// Which bob a touch at [point] is reaching for.
  bool grabsTip((double, double) point) {
    final (px, py) = point;
    final (jx, jy) = joint;
    final (tx, ty) = tip;
    final toJoint = (px - jx) * (px - jx) + (py - jy) * (py - jy);
    final toTip = (px - tx) * (px - tx) + (py - ty) * (py - ty);
    return toTip <= toJoint;
  }
}
