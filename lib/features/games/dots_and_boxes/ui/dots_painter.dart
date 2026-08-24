import 'package:flutter/material.dart';

import '../../../../core/theme/type_scale.dart';
import '../logic/dots_and_boxes.dart';

/// The whole board in one painter — dots, hairlines, drawn lines and claimed
/// boxes. Never one widget per cell.
///
/// The trick that keeps the board readable in every palette: an undrawn edge is
/// a 1px hairline and a **drawn edge is the same geometry at 2.4px in the text
/// colour**. The board stays monochrome, so the accent is free to mean turn and
/// ownership and nothing else.
class DotsPainter extends CustomPainter {
  DotsPainter({
    required this.game,
    required this.cell,
    required this.margin,
    required this.accent,
    required this.ink,
    required this.border,
    required this.claimMarks,
    required this.textScale,
  });

  final DotsAndBoxesGame game;
  final double cell;
  final double margin;

  /// Player 1's colour; player 2 uses [ink]. Never a second hue.
  final Color accent;
  final Color ink;
  final Color border;
  final bool claimMarks;
  final double textScale;

  /// Edges inset this much at each end so they never touch the dots.
  static const double _inset = 4;
  static const double _dotRadius = 3;

  Offset _dot(int row, int col) =>
      Offset(margin + col * cell, margin + row * cell);

  @override
  void paint(Canvas canvas, Size size) {
    final hairline = Paint()
      ..color = border
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final drawn = Paint()
      ..color = ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    // Claimed boxes first, so lines sit on top of their tint.
    for (var r = 0; r < game.size; r++) {
      for (var c = 0; c < game.size; c++) {
        final owner = game.ownerAt(r, c);
        if (owner == -1) continue;
        final colour = owner == 0 ? accent : ink;
        final topLeft = _dot(r, c);
        canvas.drawRect(
          Rect.fromLTWH(topLeft.dx, topLeft.dy, cell, cell),
          Paint()..color = colour.withValues(alpha: owner == 0 ? 0.16 : 0.10),
        );
        if (claimMarks) {
          _initial(canvas, topLeft + Offset(cell / 2, cell / 2), owner == 0 ? 'A' : 'B', colour);
        }
      }
    }

    for (var r = 0; r <= game.size; r++) {
      for (var c = 0; c < game.size; c++) {
        final a = _dot(r, c), b = _dot(r, c + 1);
        canvas.drawLine(
          a + const Offset(_inset, 0),
          b - const Offset(_inset, 0),
          game.horizontalAt(r, c) ? drawn : hairline,
        );
      }
    }
    for (var r = 0; r < game.size; r++) {
      for (var c = 0; c <= game.size; c++) {
        final a = _dot(r, c), b = _dot(r + 1, c);
        canvas.drawLine(
          a + const Offset(0, _inset),
          b - const Offset(0, _inset),
          game.verticalAt(r, c) ? drawn : hairline,
        );
      }
    }

    final dotPaint = Paint()..color = ink;
    for (var r = 0; r <= game.size; r++) {
      for (var c = 0; c <= game.size; c++) {
        canvas.drawCircle(_dot(r, c), _dotRadius, dotPaint);
      }
    }
  }

  /// The owner's initial. Not decoration — the tint alone fails Paper, Meadow
  /// and Blush, where the two players' tints sit close together.
  void _initial(Canvas canvas, Offset centre, String letter, Color colour) {
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: DallyType.monoChip.copyWith(
          fontSize: 17 * textScale,
          color: colour.withValues(alpha: 0.75),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  /// The edge nearest [point], or null when the tap is closer to no edge than
  /// [tolerance]. One hit test for both orientations, so a tap between two
  /// lines picks the nearer rather than the first found.
  BoxEdge? edgeAt(Offset point, {double tolerance = 22}) {
    BoxEdge? best;
    var bestDistance = tolerance;

    void consider(BoxEdge edge, Offset a, Offset b) {
      final d = _distanceToSegment(point, a, b);
      if (d < bestDistance) {
        bestDistance = d;
        best = edge;
      }
    }

    for (var r = 0; r <= game.size; r++) {
      for (var c = 0; c < game.size; c++) {
        consider(BoxEdge(EdgeKind.horizontal, r, c), _dot(r, c), _dot(r, c + 1));
      }
    }
    for (var r = 0; r < game.size; r++) {
      for (var c = 0; c <= game.size; c++) {
        consider(BoxEdge(EdgeKind.vertical, r, c), _dot(r, c), _dot(r + 1, c));
      }
    }
    return best;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  @override
  bool shouldRepaint(DotsPainter old) => true;
}
