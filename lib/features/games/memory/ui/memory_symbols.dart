import 'dart:math';

import 'package:flutter/material.dart';

/// Draws one of a set of flat, monochrome symbols (indexed) in [color]. Symbols
/// are geometry, not pictures, so they read down to a 6×6 grid. There are enough
/// distinct shapes for 18 pairs (the largest board).
class MemorySymbolPainter extends CustomPainter {
  MemorySymbolPainter({required this.index, required this.color});

  final int index;
  final Color color;

  static const int count = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.34;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (index % count) {
      case 0:
        canvas.drawCircle(c, r, fill);
      case 1:
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r), Radius.circular(r * 0.3)),
            fill);
      case 2:
        canvas.drawPath(_polygon(c, r, 3, -pi / 2), fill);
      case 3:
        canvas.drawPath(_polygon(c, r, 3, pi / 2), fill);
      case 4:
        canvas.drawPath(_polygon(c, r, 4, 0), fill);
      case 5:
        canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), stroke);
        canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), stroke);
      case 6:
        final d = r * 0.72;
        canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), stroke);
        canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), stroke);
      case 7:
        canvas.drawCircle(c, r, stroke);
      case 8:
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r), Radius.circular(r * 0.3)),
            stroke);
      case 9:
        canvas.drawPath(_polygon(c, r, 3, -pi / 2), stroke);
      case 10:
        canvas.drawPath(_polygon(c, r, 6, 0), fill);
      case 11:
        canvas.drawPath(_star(c, r, r * 0.45, 5), fill);
      case 12:
        canvas.drawPath(_polygon(c, r, 5, -pi / 2), fill);
      case 13:
        canvas.drawPath(_polygon(c, r, 6, 0), stroke);
      case 14:
        canvas.drawPath(_polygon(c, r, 5, -pi / 2), stroke);
      case 15:
        canvas.drawPath(_star(c, r, r * 0.5, 6), fill);
      case 16:
        // Up chevron.
        final p = Path()
          ..moveTo(c.dx - r, c.dy + r * 0.4)
          ..lineTo(c.dx, c.dy - r * 0.5)
          ..lineTo(c.dx + r, c.dy + r * 0.4);
        canvas.drawPath(p, stroke);
      case 17:
        // Dot in ring.
        canvas.drawCircle(c, r, stroke);
        canvas.drawCircle(c, r * 0.32, fill);
    }
  }

  Path _polygon(Offset c, double r, int sides, double rot) {
    final p = Path();
    for (var i = 0; i < sides; i++) {
      final a = rot + i * 2 * pi / sides;
      final o = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  Path _star(Offset c, double outer, double inner, int points) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / points;
      final o = Offset(c.dx + rr * cos(a), c.dy + rr * sin(a));
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(MemorySymbolPainter old) => old.index != index || old.color != color;
}
