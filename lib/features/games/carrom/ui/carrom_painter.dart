import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../logic/carrom_game.dart';
import '../logic/carrom_table.dart';

/// Coin faces. Geometry only, so both work in all eight palettes.
enum CoinStyle { flat, ringed }

CoinStyle coinStyleFromId(String id) => id == 'ringed' ? CoinStyle.ringed : CoinStyle.flat;

/// The board, flat and top-down: frame, pockets, baselines, coins, striker and
/// the aim line. One painter — nineteen coins as widgets would be nineteen
/// layers repainting every frame of a shot.
class CarromPainter extends CustomPainter {
  CarromPainter({
    required this.game,
    required this.style,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.bg,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.textFaint,
    required this.aim,
    required this.showBaseline,
  });

  final CarromGame game;
  final CoinStyle style;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color bg;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color textFaint;

  /// Direction and power of the shot being aimed, in board units.
  final (Offset direction, double power)? aim;

  final bool showBaseline;

  /// The playing surface sits inside a frame this thick, as a fraction of the
  /// whole square.
  static const double frame = 0.055;

  static double playSizeFor(double side) => side * (1 - frame * 2);

  /// Board coordinates (0–1) → canvas pixels.
  static Offset toCanvas(Offset board, double side) =>
      Offset(side * frame + board.dx * playSizeFor(side),
          side * frame + board.dy * playSizeFor(side));

  /// Canvas pixels → board coordinates.
  static Offset toBoard(Offset canvas, double side) {
    final play = playSizeFor(side);
    return Offset((canvas.dx - side * frame) / play, (canvas.dy - side * frame) / play);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final play = playSizeFor(side);

    // Frame and surface.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, side, side), const Radius.circular(Radii.container)),
      Paint()..color = surfaceAlt,
    );
    final board = Rect.fromLTWH(side * frame, side * frame, play, play);
    canvas.drawRect(board, Paint()..color = surface);
    canvas.drawRect(
      board.deflate(0.5),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _paintMarkings(canvas, side, play, board);
    _paintPockets(canvas, side, play);
    _paintCoins(canvas, side, play);
    _paintAim(canvas, side, play);
  }

  void _paintMarkings(Canvas canvas, double side, double play, Rect board) {
    final line = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // The centre circle and its ring.
    canvas.drawCircle(board.center, play * 0.17, line);
    canvas.drawCircle(board.center, play * 0.055, line);

    // Every seat's baseline, the active one brought forward.
    for (var p = 0; p < game.playerCount; p++) {
      final active = showBaseline && p == game.current && !game.isFinished;
      final paint = Paint()
        ..color = active ? accent : border
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2 : 1;
      final home = game.strikerHome(p);
      final half = CarromGame.baselineHalfLength;
      final (a, b) = game.baselineIsHorizontal(p)
          ? (Offset(0.5 - half, home.dy), Offset(0.5 + half, home.dy))
          : (Offset(home.dx, 0.5 - half), Offset(home.dx, 0.5 + half));
      canvas.drawLine(toCanvas(a, side), toCanvas(b, side), paint);
    }
  }

  void _paintPockets(Canvas canvas, double side, double play) {
    final radius = game.table.physics.pocketRadius * play;
    for (final pocket in CarromTable.pockets) {
      final centre = toCanvas(pocket, side);
      canvas.drawCircle(centre, radius, Paint()..color = bg);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  void _paintCoins(Canvas canvas, double side, double play) {
    for (final disc in game.table.discs) {
      if (disc.pocketed) continue;
      final centre = toCanvas(disc.position, side);
      final radius = disc.radius * play;
      final (fill, edge) = switch (disc.kind) {
        CoinKind.striker => (accent, onAccent),
        CoinKind.queen => (danger, onAccent),
        CoinKind.light => (surfaceAlt, ink),
        CoinKind.dark => (ink, surface),
      };
      canvas.drawCircle(centre, radius, Paint()..color = fill);
      canvas.drawCircle(
        centre,
        radius - 0.5,
        Paint()
          ..color = edge.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (style == CoinStyle.ringed) {
        canvas.drawCircle(
          centre,
          radius * 0.55,
          Paint()
            ..color = edge.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _paintAim(Canvas canvas, double side, double play) {
    final shot = aim;
    final striker = game.table.striker;
    if (shot == null || striker == null) return;
    final from = toCanvas(striker.position, side);
    final length = shot.$1.distance;
    if (length == 0) return;
    final unit = shot.$1 / length;
    final reach = play * (0.18 + 0.5 * shot.$2);

    // A dashed line, so the aim never reads as part of the board furniture.
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 7.0;
    for (var travelled = radiusPx(striker, play) + 3; travelled < reach; travelled += dash * 2) {
      canvas.drawLine(
        from + unit * travelled,
        from + unit * math.min(travelled + dash, reach),
        paint,
      );
    }
    canvas.drawCircle(from + unit * reach, 3.5, Paint()..color = accent);
  }

  static double radiusPx(Disc disc, double play) => disc.radius * play;

  @override
  bool shouldRepaint(CarromPainter old) => true;
}
