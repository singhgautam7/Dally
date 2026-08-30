import 'package:flutter/material.dart';

import '../../../../core/game/player_identity.dart';
import '../logic/dots_and_boxes.dart';

/// The whole board in one painter — dots, hairlines, drawn lines and claimed
/// boxes. Never one widget per cell.
///
/// The trick that keeps the board readable in every palette: an undrawn edge is
/// a 1px hairline and a **drawn edge is the same geometry at 2.4px in the text
/// colour**. The board stays monochrome, so the two seat colours are free to
/// mean ownership and nothing else.
///
/// Ownership comes from [identities], the shared seat palette — fixed hues that
/// do not follow the theme, each with its own shape. The shape is why the mark
/// inside a claimed box is a circle or a triangle rather than an "A" or a "B":
/// tint alone collapses on the light palettes, and initials collapse the moment
/// both players' names start with the same letter.
class DotsPainter extends CustomPainter {
  DotsPainter({
    required this.game,
    required this.cell,
    required this.margin,
    required this.identities,
    required this.ink,
    required this.border,
    required this.claimMarks,
    required this.settling,
    required this.settle,
  });

  final DotsAndBoxesGame game;
  final double cell;
  final double margin;

  /// The two seats, in player order. Never a theme colour.
  final List<PlayerIdentity> identities;

  final Color ink;
  final Color border;
  final bool claimMarks;

  /// Row-major indices of the boxes claimed by the last move — the only ones
  /// [settle] applies to.
  final Set<int> settling;

  /// `0..1` progress of that settle; 1 when nothing is animating. It drives the
  /// mark's scale only — the tint lands immediately, because ownership is state
  /// rather than decoration.
  final double settle;

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
        final identity = identities[owner];
        final topLeft = _dot(r, c);
        canvas.drawRect(
          Rect.fromLTWH(topLeft.dx, topLeft.dy, cell, cell),
          Paint()..color = identity.color.withValues(alpha: 0.16),
        );
        if (claimMarks) {
          final scale = settling.contains(r * game.size + c) ? settle : 1.0;
          _mark(canvas, topLeft + Offset(cell / 2, cell / 2), identity, scale);
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

  /// The owner's seat shape. Not decoration — the tint alone fails Paper,
  /// Meadow and Blush, where the two players' tints sit close together, and it
  /// fails entirely in greyscale.
  void _mark(Canvas canvas, Offset centre, PlayerIdentity identity, double scale) {
    final radius = cell * 0.17 * scale;
    if (radius <= 0) return;
    canvas.drawPath(
      playerShapePath(identity.shape, centre, radius),
      Paint()
        ..color = identity.color.withValues(alpha: 0.75)
        ..isAntiAlias = true,
    );
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
