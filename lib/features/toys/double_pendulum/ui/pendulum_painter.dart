import 'package:flutter/material.dart';

import '../logic/pendulum.dart';

/// The pendulum: thin accent arms, a hairline pivot ring, filled bobs, and a
/// trail that fades to nothing over its length.
class PendulumPainter extends CustomPainter {
  PendulumPainter({
    required this.sim,
    required this.showTrail,
    required this.accent,
    required this.trailColour,
    required this.revision,
  });

  final DoublePendulum sim;
  final bool showTrail;
  final Color accent;

  /// Mono, low opacity — the trail is a record, never a second accent.
  final Color trailColour;

  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height * 0.36);
    // Scale so both arms fully extended still fit the shorter axis.
    final unit = (size.shortestSide * 0.42) /
        (DoublePendulum.length1 + DoublePendulum.length2);
    Offset place((double, double) p) => pivot + Offset(p.$1 * unit, p.$2 * unit);

    if (showTrail && sim.trail.length > 1) {
      // Fades over its length: the oldest sample is invisible, the newest is
      // the full trail colour.
      final n = sim.trail.length;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      for (var i = 1; i < n; i++) {
        stroke.color = trailColour.withValues(alpha: (i / n) * 0.55);
        canvas.drawLine(place(sim.trail[i - 1]), place(sim.trail[i]), stroke);
      }
    }

    final joint = place(sim.joint);
    final tip = place(sim.tip);
    final arm = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(pivot, joint, arm);
    canvas.drawLine(joint, tip, arm);

    canvas.drawCircle(
      pivot,
      5,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );
    final bob = Paint()
      ..color = accent
      ..isAntiAlias = true;
    canvas.drawCircle(joint, 7, bob);
    canvas.drawCircle(tip, 9, bob);
  }

  @override
  bool shouldRepaint(PendulumPainter old) =>
      old.revision != revision ||
      old.showTrail != showTrail ||
      old.accent != accent ||
      old.trailColour != trailColour;
}
