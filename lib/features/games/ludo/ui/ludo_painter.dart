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
      // The four resting rings, so an empty yard still reads as four slots.
      for (final spot in LudoLayout.yardSpots(p)) {
        canvas.drawCircle(
          _at(spot),
          _cell * 0.42,
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
    // A ring square can hold several tokens; fan them so none is hidden.
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

    void token((int, int) who, Offset cell, {int of = 1, int at = 0}) {
      final (p, i) = who;
      var centre = _at(cell);
      if (of > 1) {
        final shift = _cell * 0.22 * (at - (of - 1) / 2);
        centre = centre.translate(shift, shift * 0.4);
      }
      final onTurn = p == game.current && !game.isFinished;
      if (onTurn && movable.contains(i) && animating == null) {
        canvas.drawCircle(
          centre,
          _cell * 0.5,
          Paint()..color = accent.withValues(alpha: 0.18 + 0.3 * pulse.pulseAlpha),
        );
      }
      paintPlayerToken(
        canvas,
        identities[p],
        centre,
        _cell * 0.33,
        ring: surface,
        ringWidth: _cell * 0.06,
      );
    }

    byCell.forEach((cell, occupants) {
      for (var k = 0; k < occupants.length; k++) {
        token(occupants[k], cell, of: occupants.length, at: k);
      }
    });

    final anim = animating;
    final cell = animatedCell;
    if (anim != null && cell != null) token(anim, cell);
  }

  @override
  bool shouldRepaint(LudoPainter old) => true;
}

double _cos(double x) => math.cos(x);
double _sin(double x) => math.sin(x);
