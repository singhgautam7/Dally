import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/dally_tokens.dart';
import '../logic/minesweeper_board.dart';

/// Flag & mine glyph set, chosen in the pause sheet.
enum MineStyle { classic, pennant, pin }

MineStyle mineStyleFromId(String? id) => switch (id) {
      'pennant' => MineStyle.pennant,
      'pin' => MineStyle.pin,
      _ => MineStyle.classic,
    };

/// Renders the whole board in one painter (never a widget per cell). Hidden
/// cells are inset tiles; the revealed-empty region is a single merged accent
/// flood (corners rounded only at the region edge); revealed numbers are
/// hairline cells with the fixed 1–8 colours.
class MinesweeperPainter extends CustomPainter {
  MinesweeperPainter({
    required this.board,
    required this.tokens,
    required this.style,
    required this.gameOver,
    required this.explodedIndex,
    required this.reveal,
  });

  final MinesweeperBoard board;
  final DallyTokens tokens;
  final MineStyle style;
  final bool gameOver;
  final int explodedIndex;

  /// The reveal fraction (0..1) for a cascade fade-in of newly-opened cells.
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = board.width, h = board.height;
    final cell = (size.width / w).clamp(0.0, size.height / h);
    final ox = (size.width - cell * w) / 2;
    final oy = (size.height - cell * h) / 2;

    Rect rectOf(int i) {
      final c = i % w, r = i ~/ w;
      return Rect.fromLTWH(ox + c * cell, oy + r * cell, cell, cell);
    }

    bool isFlood(int i) =>
        i >= 0 &&
        i < board.cells &&
        board.reveal[i] == CellReveal.revealed &&
        !board.mine[i] &&
        board.count[i] == 0;

    final floodPaint = Paint()..color = tokens.accent;
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = tokens.border;
    final inset = cell * 0.03;
    final tileRad = Radius.circular(cell * 0.2);

    // Inset "raised" tile (hidden / flagged / revealed-mine), per the design.
    void drawTile(int i, Color fill) => canvas.drawRRect(
          RRect.fromRectAndRadius(rectOf(i).deflate(inset), tileRad),
          Paint()..color = fill,
        );

    for (var i = 0; i < board.cells; i++) {
      final revealed = board.reveal[i] == CellReveal.revealed;

      if (!revealed) {
        drawTile(i, tokens.surfaceAlt);
        if (board.flagged[i]) _drawFlag(canvas, rectOf(i), tokens.textMuted);
        if (gameOver && board.mine[i] && !board.flagged[i]) {
          _drawMine(canvas, rectOf(i), tokens.danger);
        }
        continue;
      }

      if (board.mine[i]) {
        final exploded = i == explodedIndex;
        drawTile(i, exploded ? tokens.danger : tokens.surfaceAlt);
        _drawMine(canvas, rectOf(i), exploded ? tokens.onAccent : tokens.danger);
        continue;
      }

      if (board.count[i] == 0) {
        // Merged flood: round only the corners at the region boundary.
        final c = i % w, r = i ~/ w;
        final top = isFlood(_at(c, r - 1, w, h));
        final bottom = isFlood(_at(c, r + 1, w, h));
        final left = isFlood(_at(c - 1, r, w, h));
        final right = isFlood(_at(c + 1, r, w, h));
        final rad = Radius.circular(cell * 0.23);
        const zero = Radius.zero;
        final rrect = RRect.fromRectAndCorners(
          rectOf(i),
          topLeft: (!top && !left) ? rad : zero,
          topRight: (!top && !right) ? rad : zero,
          bottomLeft: (!bottom && !left) ? rad : zero,
          bottomRight: (!bottom && !right) ? rad : zero,
        );
        canvas.drawRRect(rrect, floodPaint);
        continue;
      }

      // Revealed number: surface cell + 0.5px hairline border + coloured digit.
      canvas.drawRect(rectOf(i), Paint()..color = tokens.surface);
      canvas.drawRect(rectOf(i).deflate(0.25), hairline);
      final colors = tokens.minesweeperNumbers;
      final color = colors[(board.count[i] - 1).clamp(0, colors.length - 1)];
      _drawDigit(canvas, rectOf(i), board.count[i], color, cell);
    }
  }

  int _at(int c, int r, int w, int h) => (c < 0 || c >= w || r < 0 || r >= h) ? -1 : r * w + c;

  void _drawDigit(Canvas canvas, Rect rect, int n, Color color, double cell) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$n',
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: cell * 0.52,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawFlag(Canvas canvas, Rect rect, Color color) =>
      MinesweeperPainterGlyphs(style).drawFlag(canvas, rect, color);

  void _drawMine(Canvas canvas, Rect rect, Color color) =>
      MinesweeperPainterGlyphs(style).drawMine(canvas, rect, color);

  @override
  bool shouldRepaint(MinesweeperPainter old) => true;
}

/// Reusable flag/mine glyph drawing, shared by the board painter and the pause
/// sheet's style-picker previews.
class MinesweeperPainterGlyphs {
  MinesweeperPainterGlyphs(this.style);
  final MineStyle style;

  /// Maps a point in an [vbW]×[vbH] viewBox into [rect], centred, scaled so the
  /// glyph height is [frac] of the cell. Mirrors the design's SVG viewBoxes.
  ({Offset o, double s}) _fit(Rect rect, double vbW, double vbH, double frac) {
    final s = rect.height * frac / vbH;
    final o = Offset(rect.center.dx - vbW * s / 2, rect.center.dy - vbH * s / 2);
    return (o: o, s: s);
  }

  void drawFlag(Canvas canvas, Rect rect, Color color) {
    final fill = Paint()..color = color..isAntiAlias = true;
    // Flag viewBox is 14×16 in the design.
    final f = _fit(rect, 14, 16, 0.62);
    double x(double v) => f.o.dx + v * f.s;
    double y(double v) => f.o.dy + v * f.s;
    final staff = Paint()
      ..color = color
      ..strokeWidth = 1.5 * f.s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (style) {
      case MineStyle.classic:
        canvas.drawLine(Offset(x(3.2), y(1.2)), Offset(x(3.2), y(14.8)), staff);
        _poly(canvas, fill, f, const [
          [4, 2], [11.2, 2], [9.2, 4.6], [11.2, 7.2], [4, 7.2],
        ]);
      case MineStyle.pennant:
        canvas.drawLine(Offset(x(3.2), y(1.2)), Offset(x(3.2), y(14.8)), staff);
        _poly(canvas, fill, f, const [
          [4, 2], [12, 2], [9.6, 4.8], [12, 7.6], [4, 7.6],
        ]);
      case MineStyle.pin:
        canvas.drawLine(Offset(x(7), y(6.4)), Offset(x(7), y(14.6)), staff);
        canvas.drawCircle(Offset(x(7), y(4.4)), 3.2 * f.s, fill);
    }
  }

  void drawMine(Canvas canvas, Rect rect, Color color) {
    final fill = Paint()..color = color..isAntiAlias = true;
    // Mine viewBox is 16×16 in the design.
    final f = _fit(rect, 16, 16, 0.5);
    final c = Offset(f.o.dx + 8 * f.s, f.o.dy + 8 * f.s);
    switch (style) {
      case MineStyle.classic:
        canvas.drawCircle(c, 4 * f.s, fill);
        final spoke = Paint()
          ..color = color
          ..strokeWidth = 1.3 * f.s
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * 5 * f.s, c + d * 7 * f.s, spoke);
        }
      case MineStyle.pennant:
        canvas.drawCircle(c, 5 * f.s, fill);
      case MineStyle.pin:
        _poly(canvas, fill, f, const [
          [8, 2.4], [13.6, 8], [8, 13.6], [2.4, 8],
        ]);
    }
  }

  void _poly(Canvas canvas, Paint p, ({Offset o, double s}) f, List<List<double>> pts) {
    final path = Path()..moveTo(f.o.dx + pts[0][0] * f.s, f.o.dy + pts[0][1] * f.s);
    for (final pt in pts.skip(1)) {
      path.lineTo(f.o.dx + pt[0] * f.s, f.o.dy + pt[1] * f.s);
    }
    path.close();
    canvas.drawPath(path, p);
  }
}
