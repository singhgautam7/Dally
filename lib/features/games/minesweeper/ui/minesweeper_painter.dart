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
    required this.cascade,
  });

  final MinesweeperBoard board;
  final DallyTokens tokens;
  final MineStyle style;
  final bool gameOver;
  final int explodedIndex;

  /// The cells opened by the last tap, keyed by how many rings out from it they
  /// sit, plus how far the ripple has travelled (in rings). A cell fades in as
  /// the ripple reaches it; everything not in the map is drawn as usual.
  ///
  /// Doing it here rather than as a widget per cell is what keeps a 30×16 clear
  /// to one repaint.
  final ({Map<int, int> ringOf, double front})? cascade;

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

    final ripple = cascade;

    /// 0 → not opened yet, 1 → fully drawn. Cells outside the ripple are 1.
    double opened(int i) {
      if (ripple == null) return 1;
      final ring = ripple.ringOf[i];
      if (ring == null) return 1;
      return (ripple.front - ring).clamp(0.0, 1.0);
    }

    for (var i = 0; i < board.cells; i++) {
      final revealed = board.reveal[i] == CellReveal.revealed;
      final open = revealed ? opened(i) : 1.0;
      // Not reached by the ripple yet: it still looks like a hidden tile.
      if (revealed && open <= 0) {
        drawTile(i, tokens.surfaceAlt);
        continue;
      }

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
        if (open < 1) {
          // Mid-ripple the tile is still under the flood, so the accent grows
          // over it rather than appearing out of the board colour.
          drawTile(i, tokens.surfaceAlt);
          canvas.drawRRect(
              rrect, Paint()..color = tokens.accent.withValues(alpha: open));
        } else {
          canvas.drawRRect(rrect, floodPaint);
        }
        continue;
      }

      // Revealed number: surface cell + 0.5px hairline border + coloured digit.
      canvas.drawRect(rectOf(i), Paint()..color = tokens.surface);
      canvas.drawRect(rectOf(i).deflate(0.25), hairline);
      final colors = tokens.minesweeperNumbers;
      final color = colors[(board.count[i] - 1).clamp(0, colors.length - 1)];
      _drawDigit(canvas, rectOf(i), board.count[i],
          open < 1 ? color.withValues(alpha: open) : color, cell);
    }
  }

  int _at(int c, int r, int w, int h) => (c < 0 || c >= w || r < 0 || r >= h) ? -1 : r * w + c;

  /// Laid-out digits, shared across frames.
  ///
  /// An Expert board has ~200 numbered cells, and this used to build and lay
  /// out a fresh [TextPainter] for every one of them on **every frame** — text
  /// layout includes shaping, so a cascade was doing ~12 000 shaping passes a
  /// second to draw eight distinct glyphs. There are only ever eight digits in
  /// a handful of colours at one cell size, so they are laid out once and
  /// reused.
  ///
  /// A cell still fading in during the cascade has a partial alpha, which would
  /// thrash a cache keyed on colour — those few cells (the ripple front only,
  /// never the settled board behind it) still lay out per frame.
  static final Map<int, TextPainter> _digits = {};

  void _drawDigit(Canvas canvas, Rect rect, int n, Color color, double cell) {
    final fontSize = cell * 0.52;
    final opaque = color.a >= 1.0;
    final key = opaque ? Object.hash(n, fontSize, color.toARGB32()) : null;

    var tp = key == null ? null : _digits[key];
    if (tp == null) {
      tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (key != null) {
        // Bounded: 8 digits × the palette's number colours × one cell size per
        // device. The clear is a floor against an unforeseen key explosion, not
        // an eviction policy — there is nothing here worth an LRU.
        if (_digits.length > 64) _digits.clear();
        _digits[key] = tp;
      }
    }
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
