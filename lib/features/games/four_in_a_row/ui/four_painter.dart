import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game/player_identity.dart';
import '../logic/four_in_a_row.dart';

/// The frame, the discs and the winning line, in one painter.
///
/// The frame is a hairline grid of **empty rings on the theme surface**, not a
/// coloured slab: that keeps the two identity colours the only saturated things
/// on screen, so a near-win is visible from across a table.
class FourPainter extends CustomPainter {
  FourPainter({
    required this.game,
    required this.cell,
    required this.identities,
    required this.border,
    required this.ink,
    required this.lightMode,
    required this.drop,
    required this.held,
    required this.shakeColumn,
    required this.shake,
  });

  final FourInARowGame game;
  final double cell;

  /// The two seats. Never a theme colour.
  final List<PlayerIdentity> identities;

  final Color border;
  final Color ink;
  final bool lightMode;

  /// The disc in flight: its column, its landing row, its owner and 0…1 of the
  /// fall. The board already holds it; this only draws the travel.
  final (int col, int row, int player, double t)? drop;

  /// A disc held above the frame by a drag: which column it is over (null when
  /// the finger is off the board) and whose it is.
  final (int?, int)? held;

  /// A tap on a full column shakes that column's top ring.
  final int? shakeColumn;
  final double shake;

  double get _radius => cell * 0.38;

  /// The strip above the frame the held disc hangs in, so a drag is visible
  /// rather than clipped off the top of the board.
  double get topGutter => cell * 0.7;

  Offset centreOf(num row, num col) =>
      Offset(cell * (col + 0.5), topGutter + cell * (row + 0.5));

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final falling = drop;
    final win = game.winLine;

    for (var r = 0; r < game.rows; r++) {
      for (var c = 0; c < game.cols; c++) {
        var centre = centreOf(r, c);
        if (shakeColumn == c && r == 0) centre += Offset(shake, 0);
        final owner = game.ownerAt(r, c);
        // The disc still in flight is drawn from its own position, so its
        // resting slot is left empty until it lands.
        final inFlight = falling != null && falling.$1 == c && falling.$2 == r;
        if (owner == -1 || inFlight) {
          canvas.drawCircle(centre, _radius, ring);
          continue;
        }
        // Every disc that is not on the winning line drops back to 34%.
        final dim = win != null && !win.contains(r, c);
        paintPlayerToken(
          canvas,
          identities[owner],
          centre,
          _radius,
          opacity: dim ? 0.34 : 1,
          lightMode: lightMode,
          ring: win != null && win.contains(r, c) ? identities[owner].color : null,
          ringWidth: 1.5,
        );
      }
    }

    // The held disc sits above the frame, in the gap the board leaves for it.
    final holding = held;
    if (holding != null && holding.$1 != null && falling == null) {
      paintPlayerToken(
        canvas,
        identities[holding.$2],
        centreOf(-0.6, holding.$1!),
        _radius * 0.9,
        opacity: 0.8,
        lightMode: lightMode,
      );
    }

    if (falling != null) {
      final from = centreOf(-1, falling.$1);
      final to = centreOf(falling.$2, falling.$1);
      paintPlayerToken(
        canvas,
        identities[falling.$3],
        Offset.lerp(from, to, falling.$4)!,
        _radius,
        lightMode: lightMode,
      );
    }

    // The line is drawn once, held, and never animated in a loop.
    if (win != null) {
      final a = centreOf(win.cells.first.$1, win.cells.first.$2);
      final b = centreOf(win.cells.last.$1, win.cells.last.$2);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = ink.withValues(alpha: 0.55)
          ..strokeWidth = math.max(1.5, cell * 0.035)
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
  }

  /// The column under [point]. The touch target is the **full column height**,
  /// so nobody has to aim at a ring.
  int? columnAt(Offset point) {
    final c = (point.dx / cell).floor();
    if (c < 0 || c >= game.cols) return null;
    if (point.dy < 0 || point.dy > topGutter + cell * game.rows) return null;
    return c;
  }

  @override
  bool shouldRepaint(FourPainter old) => true;
}
