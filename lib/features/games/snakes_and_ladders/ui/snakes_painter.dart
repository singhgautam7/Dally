import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game/player_identity.dart';
import '../../../../core/theme/type_scale.dart';
import '../logic/snakes_and_ladders.dart';

/// The numbered grid, its climbs and chutes, and every token — one painter.
///
/// Ladders and snakes are drawn in the ink colour, not in seat colours: the
/// board furniture must never compete with the four identity colours moving
/// over it. A ladder is rails and rungs; a snake is a wave with a head.
class SnakesPainter extends CustomPainter {
  SnakesPainter({
    required this.game,
    required this.identities,
    required this.ink,
    required this.border,
    required this.surface,
    required this.surfaceAlt,
    required this.lightMode,
    required this.textFaint,
    required this.animatedPositions,
    required this.tokenStyle,
    this.linkAnim,
  });

  final SnakesAndLaddersGame game;
  final List<PlayerIdentity> identities;
  final Color ink;
  final Color border;
  /// The seat hairline is mandatory in Light — see [identityOutline].
  final bool lightMode;

  final Color surface;
  final Color surfaceAlt;
  final Color textFaint;

  /// Drawn positions per seat, in *square* units and fractional, so a token can
  /// be shown mid-walk. The game state has already moved on.
  final List<double> animatedPositions;

  /// Pawn (default) or the bare identity shape, chosen in the pause sheet.
  final PlayerTokenStyle tokenStyle;

  /// A seat riding a link: drawn straight along the ladder or snake rather
  /// than crawling the serpentine numbering.
  final (int seat, Link link, double t)? linkAnim;

  double _cell = 1;

  Offset _centreOf(int square) {
    final (c, r) = game.cellOf(square);
    return Offset((c + 0.5) * _cell, (r + 0.5) * _cell);
  }

  /// The drawn point for a fractional square, walking between whole squares so
  /// the token follows the boustrophedon rather than cutting across the board.
  Offset _centreOfFractional(double square) {
    final low = square.floor().clamp(1, game.squares);
    final high = square.ceil().clamp(1, game.squares);
    if (low == high) return _centreOf(low);
    return Offset.lerp(_centreOf(low), _centreOf(high), square - low)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _cell = math.min(size.width / game.columns, size.height / game.rows);
    _paintGrid(canvas);
    _paintLinks(canvas);
    _paintTokens(canvas);
  }

  void _paintGrid(Canvas canvas) {
    final line = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var s = 1; s <= game.squares; s++) {
      final (c, r) = game.cellOf(s);
      final rect = Rect.fromLTWH(c * _cell, r * _cell, _cell, _cell);
      // A quiet checker so the serpentine numbering is readable at a glance.
      canvas.drawRect(rect, Paint()..color = (c + r).isEven ? surface : surfaceAlt);
      canvas.drawRect(rect.deflate(0.5), line);
      if (_cell >= 22) {
        _label(canvas, rect.topLeft + Offset(_cell * 0.16, _cell * 0.12), '$s');
      }
    }
  }

  void _label(Canvas canvas, Offset at, String text) {
    TextPainter(
      text: TextSpan(
        text: text,
        style: DallyType.monoChip.copyWith(fontSize: _cell * 0.24, color: textFaint),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, at);
  }

  void _paintLinks(Canvas canvas) {
    for (final link in game.links) {
      final a = _centreOf(link.from);
      final b = _centreOf(link.to);
      link.isLadder ? _ladder(canvas, a, b) : _snake(canvas, a, b);
    }
  }

  void _ladder(Canvas canvas, Offset a, Offset b) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.5)
      ..strokeWidth = math.max(1.4, _cell * 0.05)
      ..strokeCap = StrokeCap.round;
    final along = b - a;
    final length = along.distance;
    if (length == 0) return;
    final side = Offset(-along.dy, along.dx) / length * (_cell * 0.16);
    canvas.drawLine(a + side, b + side, paint);
    canvas.drawLine(a - side, b - side, paint);
    final rungs = math.max(2, (length / (_cell * 0.55)).floor());
    for (var i = 1; i < rungs; i++) {
      final p = a + along * (i / rungs);
      canvas.drawLine(p + side, p - side, paint);
    }
  }

  void _snake(Canvas canvas, Offset head, Offset tail) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, _cell * 0.13)
      ..strokeCap = StrokeCap.round;
    final along = tail - head;
    final length = along.distance;
    if (length == 0) return;
    final side = Offset(-along.dy, along.dx) / length * (_cell * 0.55);
    final path = Path()
      ..moveTo(head.dx, head.dy)
      ..cubicTo(
        (head + along * 0.33 + side).dx,
        (head + along * 0.33 + side).dy,
        (head + along * 0.66 - side).dx,
        (head + along * 0.66 - side).dy,
        tail.dx,
        tail.dy,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(head, _cell * 0.17, Paint()..color = ink.withValues(alpha: 0.6));
  }

  void _paintTokens(Canvas canvas) {
    // Seats sharing a square fan out so none is hidden.
    final bySquare = <int, List<int>>{};
    for (var p = 0; p < identities.length; p++) {
      bySquare.putIfAbsent(animatedPositions[p].round(), () => []).add(p);
    }
    final riding = linkAnim;
    for (var p = 0; p < identities.length; p++) {
      final mates = bySquare[animatedPositions[p].round()]!;
      final at = mates.indexOf(p);
      final shift = _cell * 0.2 * (at - (mates.length - 1) / 2);
      final centre = riding != null && riding.$1 == p
          ? Offset.lerp(_centreOf(riding.$2.from), _centreOf(riding.$2.to), riding.$3)!
          : _centreOfFractional(animatedPositions[p]) + Offset(shift, shift * 0.5);
      paintPlayerToken(
        canvas,
        identities[p],
        centre,
        _cell * 0.24,
        ring: surface,
        ringWidth: math.max(1, _cell * 0.04),
        style: tokenStyle,
        knockout: surface,
        lightMode: lightMode,
      );
    }
  }

  @override
  bool shouldRepaint(SnakesPainter old) => true;
}
