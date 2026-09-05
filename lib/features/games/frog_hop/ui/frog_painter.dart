import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game/player_identity.dart';
import '../logic/frog_hop.dart';

/// The lane, in one painter — cells, the two goal washes, the pieces, and the
/// legal-target markers for whatever is selected.
///
/// The lane is stored as a single index, so portrait and landscape are the same
/// board with its axis swapped: [horizontal] is the only thing that changes.
class FrogPainter extends CustomPainter {
  FrogPainter({
    required this.game,
    required this.cell,
    required this.horizontal,
    required this.identities,
    required this.tokenStyle,
    required this.selected,
    required this.targets,
    required this.surfaceAlt,
    required this.border,
    required this.lightMode,
    required this.flight,
    required this.shake,
  });

  final FrogHopGame game;
  final double cell;

  /// True in landscape, where the lane runs left-to-right.
  final bool horizontal;

  /// Seat 0 is the bottom end, seat 1 the top. Never a theme colour.
  final List<PlayerIdentity> identities;

  /// Geometry only: Chip is the identity shape filled, Pin is the shared Ludo
  /// token. The colour is the identity's either way.
  final PlayerTokenStyle tokenStyle;

  final int? selected;
  final List<FrogMove> targets;

  final Color surfaceAlt;
  final Color border;
  final bool lightMode;

  /// The piece in flight: its move and 0…1 progress along it. A jump arcs one
  /// third of a cell above the line; a step is a straight slide.
  final (FrogMove, double)? flight;

  /// Index and offset of an illegal tap's shake, in logical pixels.
  final (int, double)? shake;

  double get _pieceRadius => cell * 0.34;

  /// Where the centre of [index] sits. One function for both orientations.
  Offset centreOf(num index) => horizontal
      ? Offset(cell * (index + 0.5), cell * 0.5)
      : Offset(cell * 0.5, cell * (game.length - index - 0.5));

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()..isAntiAlias = true;
    final cellPaint = Paint()
      ..color = surfaceAlt
      ..isAntiAlias = true;
    final hairline = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;

    for (var i = 0; i < game.length; i++) {
      final centre = centreOf(i);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: cell * 0.86, height: cell * 0.86),
        Radius.circular(cell * 0.2),
      );
      canvas.drawRRect(rect, cellPaint);
      canvas.drawRRect(rect, hairline);

      // Both goals are marked from the first frame, in the colour of the side
      // that has to reach them — so a new player can see where they are going
      // before making a move.
      for (final side in FrogSide.values) {
        if (game.homeCells(side).contains(i)) {
          canvas.drawRRect(
            rect,
            wash..color = identities[side.index].color.withValues(alpha: 0.12),
          );
        }
      }
    }

    // Legal targets for the selected piece, drawn the moment it is touched.
    for (final move in targets) {
      final centre = centreOf(move.to);
      final side = game.at(selected!)!;
      canvas.drawCircle(
        centre,
        _pieceRadius * (move.kind == FrogMoveKind.jump ? 0.42 : 0.3),
        Paint()
          ..color = identities[side.index].color.withValues(alpha: 0.55)
          ..isAntiAlias = true,
      );
    }

    final travelling = flight?.$1;
    for (var i = 0; i < game.length; i++) {
      final side = game.at(i);
      if (side == null) continue;
      // The piece in flight is drawn from its own interpolated position, so it
      // is skipped where it now sits.
      if (travelling != null && i == travelling.to) continue;
      var centre = centreOf(i);
      if (shake != null && shake!.$1 == i) {
        centre += horizontal ? Offset(0, shake!.$2) : Offset(shake!.$2, 0);
      }
      _piece(canvas, centre, side, selected == i);
    }

    if (travelling != null) {
      final t = flight!.$2;
      final from = centreOf(travelling.from);
      final to = centreOf(travelling.to);
      var centre = Offset.lerp(from, to, t)!;
      if (travelling.kind == FrogMoveKind.jump) {
        // A shallow arc peaking one third of a cell above the line.
        final lift = math.sin(t * math.pi) * cell / 3;
        centre += horizontal ? Offset(0, -lift) : Offset(lift, 0);
      }
      _piece(canvas, centre, game.at(travelling.to)!, false);
    }
  }

  void _piece(Canvas canvas, Offset centre, FrogSide side, bool selected) {
    paintPlayerToken(
      canvas,
      identities[side.index],
      // A pin is tip-anchored, so it hangs off the bottom of the cell rather
      // than centring in it.
      tokenStyle == PlayerTokenStyle.pin
          ? centre + Offset(0, _pieceRadius * 0.8)
          : centre,
      _pieceRadius,
      style: tokenStyle,
      knockout: surfaceAlt,
      lightMode: lightMode,
      ring: selected ? identities[side.index].color : null,
      ringWidth: math.max(2, cell * 0.05),
    );
  }

  /// The lane cell under [point], or null when the tap missed the lane.
  int? indexAt(Offset point) {
    final along = horizontal ? point.dx : point.dy;
    final across = horizontal ? point.dy : point.dx;
    if (across < 0 || across > cell) return null;
    final slot = (along / cell).floor();
    if (slot < 0 || slot >= game.length) return null;
    return horizontal ? slot : game.length - 1 - slot;
  }

  @override
  bool shouldRepaint(FrogPainter old) => true;
}
