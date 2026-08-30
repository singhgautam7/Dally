import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game/player_identity.dart';
import '../../../../core/theme/motion.dart';
import '../logic/ludo.dart';
import '../logic/ludo_layout.dart';

/// The whole 15×15 cross in one painter: grid, yards, home columns, safe stars
/// and every token. Never a widget per cell.
///
/// The board itself is monochrome — squares are hairlines on the surface
/// colour, so all four identity colours keep their meaning against it in every
/// palette. Only the yards, home columns and tokens carry seat colour.
class LudoPainter extends CustomPainter {
  LudoPainter({
    required this.game,
    required this.identities,
    required this.ink,
    required this.border,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.movable,
    required this.animating,
    required this.animatedCell,
    required this.pulse,
    required this.tokenStyle,
    this.poppedBadge,
    this.badgePop = 1,
  });

  final LudoGame game;
  final List<PlayerIdentity> identities;
  final Color ink;
  final Color border;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;

  /// Token indices of the player on turn that can be tapped right now.
  final Set<int> movable;

  /// `(player, token)` currently mid-hop, drawn at [animatedCell] instead of
  /// its resting cell. The game state has already moved on — this only affects
  /// where the token is *drawn*.
  final (int, int)? animating;
  final Offset? animatedCell;

  /// 0→1 breathing value for the movable-token highlight.
  final double pulse;

  /// Pin (default), pawn, or the bare identity shape — chosen in the pause
  /// sheet.
  final PlayerTokenStyle tokenStyle;

  /// The cell whose count badge is popping, and how far through the pop it is.
  final Offset? poppedBadge;
  final double badgePop;

  double _cell = 1;
  Offset _origin = Offset.zero;

  Offset _at(Offset cell) => _origin + Offset(cell.dx * _cell, cell.dy * _cell);

  @override
  void paint(Canvas canvas, Size size) {
    _cell = size.shortestSide / LudoLayout.gridSize;
    _origin = Offset(
      (size.width - _cell * LudoLayout.gridSize) / 2,
      (size.height - _cell * LudoLayout.gridSize) / 2,
    );

    _paintYards(canvas);
    _paintTrack(canvas);
    _paintCentre(canvas);
    _paintTokens(canvas);
  }

  void _paintYards(Canvas canvas) {
    for (var p = 0; p < identities.length; p++) {
      final o = LudoLayout.yardOrigin(p);
      final rect = Rect.fromLTWH(_at(o).dx, _at(o).dy, _cell * 6, _cell * 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(_cell * 0.2), Radius.circular(_cell * 0.5)),
        Paint()..color = identities[p].color.withValues(alpha: 0.14),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(_cell * 0.2), Radius.circular(_cell * 0.5)),
        Paint()
          ..color = identities[p].color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // The four resting sockets. Small: a tip-anchored pin stands *on* its
      // spot rather than sitting inside it, so a big ring would read as an
      // empty container next to an occupied one.
      for (final spot in LudoLayout.yardSpots(p)) {
        canvas.drawCircle(
          _at(spot),
          _cell * 0.28,
          Paint()
            ..color = identities[p].color.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  void _paintTrack(Canvas canvas) {
    final fill = Paint()..color = surface;
    final line = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void square(Offset cell, Color? tint) {
      final rect = Rect.fromLTWH(_at(cell).dx, _at(cell).dy, _cell, _cell);
      canvas.drawRect(rect, fill);
      if (tint != null) canvas.drawRect(rect, Paint()..color = tint);
      canvas.drawRect(rect.deflate(0.5), line);
    }

    for (var i = 0; i < LudoLayout.ring.length; i++) {
      // An entry square wears its seat's colour; a star is a neutral tint.
      final owner = i % 13 == 0 ? i ~/ 13 : -1;
      final tint = owner >= 0 && owner < identities.length
          ? identities[owner].color.withValues(alpha: 0.3)
          : (kSafeRingSquares.contains(i) ? surfaceAlt : null);
      square(LudoLayout.ring[i], tint);
    }
    for (var p = 0; p < identities.length; p++) {
      for (final cell in LudoLayout.homeColumn(p)) {
        square(cell, identities[p].color.withValues(alpha: 0.3));
      }
    }
    // Stars mark the safe squares that are not somebody's entry.
    for (final i in kSafeRingSquares) {
      if (i % 13 == 0) continue;
      _star(canvas, _at(LudoLayout.ring[i] + const Offset(0.5, 0.5)), _cell * 0.26);
    }
  }

  void _star(Canvas canvas, Offset centre, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * 3.141592653589793 / 4;
      final radius = i.isEven ? r : r * 0.45;
      final p = centre + Offset(radius * _cos(angle), radius * _sin(angle));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = border);
  }

  void _paintCentre(Canvas canvas) {
    // The finish: four wedges meeting in the middle, one per seat.
    final c = _at(const Offset(7.5, 7.5));
    final r = _cell * 1.5;
    for (var p = 0; p < identities.length; p++) {
      final path = Path()..moveTo(c.dx, c.dy);
      final base = -3.141592653589793 * 0.75 + p * 3.141592653589793 / 2;
      path
        ..lineTo(c.dx + r * _cos(base), c.dy + r * _sin(base))
        ..lineTo(c.dx + r * _cos(base + 3.141592653589793 / 2),
            c.dy + r * _sin(base + 3.141592653589793 / 2))
        ..close();
      canvas.drawPath(path, Paint()..color = identities[p].color.withValues(alpha: 0.45));
    }
    canvas.drawRect(
      Rect.fromCenter(center: c, width: _cell * 3, height: _cell * 3).deflate(0.5),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _paintTokens(Canvas canvas) {
    // A cell can hold several tokens, of one colour or of several. Group them
    // so each cell is drawn as a whole rather than token by token.
    final byCell = <Offset, List<(int, int)>>{};
    for (var p = 0; p < identities.length; p++) {
      for (var i = 0; i < 4; i++) {
        final anim = animating;
        if (anim != null && anim.$1 == p && anim.$2 == i) continue;
        byCell
            .putIfAbsent(LudoLayout.cellOf(p, game.tokens[p][i], i), () => [])
            .add((p, i));
      }
    }

    // Top to bottom: a pin's head overflows the cell above it, so the lower
    // token has to be drawn later or it ends up behind its own neighbour.
    final cells = byCell.keys.toList()
      ..sort((a, b) => a.dy == b.dy ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    for (final cell in cells) {
      // Where each token on a shared cell goes is pure geometry, decided in the
      // layout — the painter only draws what it is handed.
      for (final place in LudoLayout.placeOnCell(byCell[cell]!)) {
        final centre = _at(cell) + place.offset * _cell;
        _paintToken(canvas, centre, place.player, place.token, scale: place.scale);
        if (place.count > 1) {
          _paintCountBadge(
              canvas, cell, centre, place.player, place.count, place.scale);
        }
      }
    }

    final anim = animating;
    final cell = animatedCell;
    if (anim != null && cell != null) {
      _paintToken(canvas, _at(cell), anim.$1, anim.$2, scale: 1);
    }
  }

  void _paintToken(Canvas canvas, Offset centre, int player, int token,
      {required double scale}) {
    final radius = _cell * 0.33 * scale;
    final onTurn = player == game.current && !game.isFinished;
    if (onTurn && movable.contains(token) && animating == null) {
      // Around the head, which is the part of a token the eye reads — a halo
      // the size of the whole cell would swallow a fanned neighbour.
      final at = tokenStyle == PlayerTokenStyle.pin
          ? pinHeadCentre(centre, radius)
          : centre;
      canvas.drawCircle(
        at,
        _cell * 0.36 * scale,
        Paint()..color = accent.withValues(alpha: 0.18 + 0.3 * pulse.pulseAlpha),
      );
    }
    paintPlayerToken(
      canvas,
      identities[player],
      centre,
      radius,
      ring: surface,
      ringWidth: _cell * 0.06 * scale,
      style: tokenStyle,
      knockout: surface,
    );
  }

  /// The `×N` badge over a collapsed stack, in the seat's own colour with the
  /// board punched through the numerals.
  void _paintCountBadge(Canvas canvas, Offset cell, Offset centre, int player,
      int count, double scale) {
    final pop = cell == poppedBadge ? badgePop : 1.0;
    final height = _cell * 0.42 * scale * pop;
    // Directly over the token's head — in its own column, so which token the
    // count belongs to is never in question, and clear of the point that
    // anchors the cell.
    final radius = _cell * 0.33 * scale;
    final head = tokenStyle == PlayerTokenStyle.pin
        ? pinHeadCentre(centre, radius)
        : centre;
    final clearance = (tokenStyle == PlayerTokenStyle.pin
            ? pinHeadRadius(radius)
            : radius) +
        height * 0.6;
    final at = head.translate(0, -clearance);
    final label = '×$count';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: height * 0.62,
          height: 1,
          fontWeight: FontWeight.w700,
          color: surface,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final width = math.max(height, painter.width + height * 0.5);
    final rect = Rect.fromCenter(center: at, width: width, height: height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(height / 2)),
      Paint()..color = identities[player].color,
    );
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(LudoPainter old) => true;
}

double _cos(double x) => math.cos(x);
double _sin(double x) => math.sin(x);
