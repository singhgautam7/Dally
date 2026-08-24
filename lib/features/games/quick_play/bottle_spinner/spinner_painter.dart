import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/dally_tokens.dart';

enum SpinnerStyle { bottle, arrow, marker }

SpinnerStyle spinnerStyleFromId(String id) => switch (id) {
      'arrow' => SpinnerStyle.arrow,
      'marker' => SpinnerStyle.marker,
      _ => SpinnerStyle.bottle,
    };

/// The ring plus the pointer. Motion is identical across styles — only the
/// pointer's shape changes, which is what keeps a style purely geometric.
class SpinnerPainter extends CustomPainter {
  SpinnerPainter({
    required this.angle,
    required this.style,
    required this.accent,
    required this.border,
    required this.spinning,
  });

  /// Pointer angle in radians, clockwise from straight up.
  final double angle;
  final SpinnerStyle style;
  final Color accent;
  final Color border;
  final bool spinning;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      centre,
      radius * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = border,
    );

    // A quiet accent arc trails the pointer while it moves.
    if (spinning) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius * 0.94),
        angle - math.pi / 2 - 0.9,
        0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.45),
      );
    }

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle);
    final paint = Paint()..color = accent;
    final len = radius * 0.6;

    switch (style) {
      case SpinnerStyle.bottle:
        // A neck-and-body silhouette, drawn head-on and flat.
        final w = radius * 0.13;
        final path = Path()
          ..moveTo(-w * 0.42, -len)
          ..lineTo(w * 0.42, -len)
          ..lineTo(w * 0.42, -len * 0.62)
          ..lineTo(w, -len * 0.42)
          ..lineTo(w, len * 0.8)
          ..arcToPoint(Offset(-w, len * 0.8), radius: Radius.circular(w), clockwise: false)
          ..lineTo(-w, -len * 0.42)
          ..lineTo(-w * 0.42, -len * 0.62)
          ..close();
        canvas.drawPath(path, paint);
      case SpinnerStyle.arrow:
        final w = radius * 0.09;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(-w * 0.5, -len * 0.5, w * 0.5, len * 0.85),
            Radius.circular(w * 0.5),
          ),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0, -len)
            ..lineTo(w * 1.7, -len * 0.42)
            ..lineTo(-w * 1.7, -len * 0.42)
            ..close(),
          paint,
        );
      case SpinnerStyle.marker:
        final w = radius * 0.1;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(-w * 0.5, -len, w * 0.5, len * 0.2),
            Radius.circular(w * 0.5),
          ),
          paint,
        );
        canvas.drawCircle(Offset(0, -len), w * 1.5, paint);
    }
    canvas.restore();

    canvas.drawCircle(centre, radius * 0.045, Paint()..color = border);
  }

  @override
  bool shouldRepaint(SpinnerPainter old) =>
      old.angle != angle || old.style != style || old.accent != accent || old.spinning != spinning;
}

/// A small static pointer for the style picker.
class SpinnerChip extends StatelessWidget {
  const SpinnerChip({super.key, required this.style, this.size = 54});
  final SpinnerStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: SpinnerPainter(
          angle: 0.5,
          style: style,
          accent: t.accent,
          border: t.border,
          spinning: false,
        ),
      ),
    );
  }
}
