import 'package:flutter/material.dart';

import '../logic/snake_game.dart';

/// Snake body/food render style, chosen in the pause sheet.
enum SnakeStyle { classic, ribbon, pixel }

SnakeStyle snakeStyleFromId(String? id) => switch (id) {
      'ribbon' => SnakeStyle.ribbon,
      'pixel' => SnakeStyle.pixel,
      _ => SnakeStyle.classic,
    };

/// Paints the arena: snake segments (accent, rounded per [style]) and food
/// (danger). One painter for the whole board — never a widget per cell.
class SnakePainter extends CustomPainter {
  SnakePainter({
    required this.game,
    required this.style,
    required this.snakeColor,
    required this.foodColor,
    required this.dead,
    required this.progress,
    required this.headPop,
  });

  final SnakeGame game;
  final SnakeStyle style;
  final Color snakeColor;
  final Color foodColor;
  final bool dead;

  /// How far through the current grid step we are, `0..1`. Each segment is
  /// drawn between the cell it came from and the cell it is in, so the snake
  /// slides instead of jumping a whole cell per tick. `1` is the discrete
  /// render — what a stopped loop, a dead snake and reduce-motion all get.
  final double progress;

  /// Scale on the head for one `pop` beat after eating; 1 otherwise.
  final double headPop;

  @override
  void paint(Canvas canvas, Size size) {
    final n = game.size;
    const pad = 6.0;
    final cell = (size.width - 2 * pad) / n;
    // Per-style grid gap: classic hairline, pixel wide, ribbon merges (no gap).
    final gap = switch (style) {
      SnakeStyle.classic => cell * 0.09,
      SnakeStyle.pixel => cell * 0.16,
      SnakeStyle.ribbon => 0.0,
    };

    Rect cellRect(int index) {
      final c = index % n, r = index ~/ n;
      return Rect.fromLTWH(
        pad + c * cell + gap / 2,
        pad + r * cell + gap / 2,
        cell - gap,
        cell - gap,
      );
    }

    Offset cellCenter(int index) => cellRect(index).center;

    // Where segment [i] is drawn: between the cell it came from (its successor
    // in the body, which it is following) and the cell it now occupies. A gap
    // wider than one cell means the body wrapped the arena edge, and there is
    // nothing sensible to slide across — snap instead.
    Offset lead(int i) => cellCenter(game.snake[i]);
    Offset from(int i) =>
        cellCenter(game.snake[i + 1 < game.snake.length ? i + 1 : i]);
    Offset drawnCentre(int i) {
      if (progress >= 1) return lead(i);
      final a = from(i), b = lead(i);
      if ((b - a).distance > cell * 1.5) return b;
      return Offset.lerp(a, b, progress)!;
    }

    final snakePaint = Paint()..color = dead ? snakeColor.withValues(alpha: 0.6) : snakeColor;
    final foodPaint = Paint()..color = foodColor;

    // Food: classic round dot, ribbon diamond, pixel square.
    if (game.food >= 0) {
      final f = cellRect(game.food);
      switch (style) {
        case SnakeStyle.classic:
          canvas.drawCircle(f.center, f.width / 2, foodPaint);
        case SnakeStyle.pixel:
          canvas.drawRect(f, foodPaint);
        case SnakeStyle.ribbon:
          final c = f.center, h = f.width / 2;
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - h)
              ..lineTo(c.dx + h, c.dy)
              ..lineTo(c.dx, c.dy + h)
              ..lineTo(c.dx - h, c.dy)
              ..close(),
            foodPaint,
          );
      }
    }

    if (style == SnakeStyle.ribbon) {
      _paintRibbon(canvas, drawnCentre, cell, snakePaint);
    } else {
      _paintSegments(canvas, drawnCentre, cell, snakePaint, foodPaint);
    }
  }

  /// Discrete cells: a chain rounded only at head & tail (classic) or sharp
  /// squares (pixel). Each segment is centred on its interpolated position, so
  /// the same code draws a mid-step slide and a settled board.
  void _paintSegments(Canvas canvas, Offset Function(int) centreOf, double cell,
      Paint snakePaint, Paint foodPaint) {
    final gap = switch (style) {
      SnakeStyle.classic => cell * 0.09,
      SnakeStyle.pixel => cell * 0.16,
      SnakeStyle.ribbon => 0.0,
    };
    for (var i = 0; i < game.snake.length; i++) {
      final isHead = i == 0;
      final isTail = i == game.snake.length - 1;
      final side = (cell - gap) * (isHead ? headPop : 1);
      final rect = Rect.fromCenter(center: centreOf(i), width: side, height: side);
      final radius = switch (style) {
        SnakeStyle.pixel => 0.0,
        SnakeStyle.classic => (isHead || isTail) ? cell * 0.36 : cell * 0.09,
        SnakeStyle.ribbon => 0.0,
      };
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), snakePaint);
      if (isHead && dead) {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), foodPaint);
      }
    }
  }

  /// Continuous smooth ribbon: one round-capped stroke through the segment
  /// centres, split where the body wraps the arena edge.
  void _paintRibbon(Canvas canvas, Offset Function(int) centreOf, double cell, Paint snakePaint) {
    final stroke = Paint()
      ..color = snakePaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.82
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    var started = false;
    Offset? prev;
    for (var i = 0; i < game.snake.length; i++) {
      final c = centreOf(i);
      if (!started || (prev != null && (c - prev).distance > cell * 1.5)) {
        path.moveTo(c.dx, c.dy);
        started = true;
      } else {
        path.lineTo(c.dx, c.dy);
      }
      prev = c;
    }
    canvas.drawPath(path, stroke);
    if (dead && game.snake.isNotEmpty) {
      final h = centreOf(0);
      canvas.drawCircle(h, cell * 0.41, Paint()..color = foodColor);
    }
  }

  @override
  bool shouldRepaint(SnakePainter old) =>
      old.progress != progress ||
      old.headPop != headPop ||
      old.dead != dead ||
      old.style != style ||
      old.game.snake.length != game.snake.length ||
      old.game.head != game.head ||
      old.game.food != game.food;
}
