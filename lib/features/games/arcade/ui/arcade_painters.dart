import 'package:flutter/material.dart';

import '../logic/avoider_core.dart';
import '../logic/updraft_core.dart';
import '../logic/jumper_core.dart';
import '../logic/racer_core.dart';
import '../logic/tower_core.dart';

/// House drawing rules for the whole arcade: squares, bars, hairlines, one
/// accent. Obstacles are outlined; the player is solid. No scrolling texture,
/// no faces, no parallax.

/// The platform row of Jumper's style picker — the row that shipped.
enum JumperStyle { blocks, hairline, pixel }

JumperStyle jumperStyleFromId(String id) => switch (id) {
      'hairline' => JumperStyle.hairline,
      'pixel' => JumperStyle.pixel,
      _ => JumperStyle.blocks,
    };

/// The character row — the thing the player actually watches, which had no
/// options at all and made the game feel thinner than its neighbours.
///
/// Rules for a character: the same hit box, the same silhouette weight, one
/// accent fill and nothing else — no faces, no second colour, no outline.
/// [square] and [pixel] read direction through a one-cell offset in the leading
/// edge; [arrow] flips horizontally; [disc] shows direction only through its
/// motion, which is the point of offering it. The choice is cosmetic and the
/// physics never sees it.
enum JumperCharacter { square, disc, arrow, pixel }

JumperCharacter jumperCharacterFromId(String id) => switch (id) {
      'disc' => JumperCharacter.disc,
      'arrow' => JumperCharacter.arrow,
      'pixel' => JumperCharacter.pixel,
      _ => JumperCharacter.square,
    };

/// Draws a character into [box] in [colour], facing [facing] (-1, 0 or 1).
/// Shared by the arena and the style-picker previews, so what you tap is what
/// you get.
void paintJumperCharacter(
  Canvas canvas,
  JumperCharacter character,
  Rect box,
  Color colour, {
  int facing = 0,
}) {
  final paint = Paint()
    ..color = colour
    ..isAntiAlias = true;
  switch (character) {
    case JumperCharacter.disc:
      canvas.drawCircle(box.center, box.shortestSide / 2, paint);
    case JumperCharacter.arrow:
      // Points the way it is travelling, and flips at the wall.
      final tipX = facing < 0 ? box.left : box.right;
      final backX = facing < 0 ? box.right : box.left;
      canvas.drawPath(
        Path()
          ..moveTo(tipX, box.center.dy)
          ..lineTo(backX, box.top)
          ..lineTo(backX + (facing < 0 ? -1 : 1) * box.width * 0.34, box.center.dy)
          ..lineTo(backX, box.bottom)
          ..close(),
        paint,
      );
    case JumperCharacter.pixel:
      // A hard-edged block with a one-cell notch on the leading edge.
      final cell = box.width / 4;
      canvas.drawRect(box, paint);
      if (facing != 0) {
        final notch = facing > 0
            ? Rect.fromLTWH(box.right - cell, box.top, cell, cell)
            : Rect.fromLTWH(box.left, box.top, cell, cell);
        canvas.drawRect(notch, Paint()..blendMode = BlendMode.clear);
      }
    case JumperCharacter.square:
      final r = Radius.circular(box.width * 0.14);
      canvas.drawRRect(RRect.fromRectAndRadius(box, r), paint);
      if (facing != 0) {
        // The leading edge steps out by one cell, so which way it is going
        // reads even at rest.
        final cell = box.width / 5;
        final lead = facing > 0
            ? Rect.fromLTWH(box.right - cell, box.center.dy - cell / 2, cell * 1.5, cell)
            : Rect.fromLTWH(box.left - cell * 0.5, box.center.dy - cell / 2, cell * 1.5, cell);
        canvas.drawRRect(
            RRect.fromRectAndRadius(lead, Radius.circular(cell * 0.3)), paint);
      }
  }
}

class JumperPainter extends CustomPainter {
  JumperPainter({
    required this.core,
    required this.style,
    required this.character,
    required this.accent,
    required this.ink,
    required this.border,
    required this.bestHeight,
  });

  final JumperCore core;
  final JumperStyle style;
  final JumperCharacter character;
  final Color accent;
  final Color ink;
  final Color border;
  final double bestHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(style == JumperStyle.pixel ? 0 : 3);

    for (final p in core.platforms) {
      final rect = Rect.fromLTWH(p.x, p.y, p.width, core.platformHeight);
      if (style == JumperStyle.hairline) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(0.5), radius),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = border,
        );
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), Paint()..color = border);
      }
    }

    // The character is drawn into a saved layer so the Pixel notch can punch
    // through it without taking the platforms with it.
    final box =
        Rect.fromLTWH(core.playerX, core.playerY, core.playerSize, core.playerSize);
    canvas.saveLayer(box.inflate(2), Paint());
    paintJumperCharacter(canvas, character, box, accent, facing: core.steer);
    canvas.restore();

    // An accent tick on the right edge marks the best run.
    if (bestHeight > 0 && core.height < bestHeight) {
      final y = size.height * 0.42 - (bestHeight - core.height);
      if (y > 0 && y < size.height) {
        canvas.drawLine(
          Offset(size.width - 14, y),
          Offset(size.width, y),
          Paint()
            ..color = accent
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(JumperPainter old) => true;
}

/// Flappy Token's four token styles. Geometry only — the accent stays the
/// accent in every one, and all four share the same 26 × 26 hit box, so no
/// style is easier.
///
/// [dot] and [ring] do not tilt — a circle rotating shows nothing — so they read
/// the beat through a short scale pulse instead.
enum UpdraftToken { dart, dot, block, ring }

UpdraftToken updraftTokenFromId(String id) => switch (id) {
      'dot' => UpdraftToken.dot,
      'block' => UpdraftToken.block,
      'ring' => UpdraftToken.ring,
      _ => UpdraftToken.dart,
    };

/// True for the styles that show the beat through rotation rather than a pulse.
bool updraftTokenTilts(UpdraftToken token) =>
    token == UpdraftToken.dart || token == UpdraftToken.block;

/// Draws a token into [box] in [colour]. Shared by the arena and the style
/// previews, so what you tap is what you get.
void paintUpdraftToken(Canvas canvas, UpdraftToken token, Rect box, Color colour) {
  final paint = Paint()
    ..color = colour
    ..isAntiAlias = true;
  switch (token) {
    case UpdraftToken.dart:
      canvas.drawPath(
        Path()
          ..moveTo(box.right, box.center.dy)
          ..lineTo(box.left, box.top)
          ..lineTo(box.left + box.width * 0.3, box.center.dy)
          ..lineTo(box.left, box.bottom)
          ..close(),
        paint,
      );
    case UpdraftToken.dot:
      canvas.drawCircle(box.center, box.shortestSide / 2, paint);
    case UpdraftToken.block:
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.16)),
        paint,
      );
    case UpdraftToken.ring:
      canvas.drawCircle(
        box.center,
        box.shortestSide / 2 - box.width * 0.11,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = box.width * 0.22,
      );
  }
}

/// The arena: hairline pillar outlines, never filled slabs, and nothing but the
/// score on screen during a run.
class UpdraftPainter extends CustomPainter {
  UpdraftPainter({
    required this.core,
    required this.token,
    required this.accent,
    required this.border,
    required this.danger,
    required this.pulse,
    required this.edgeFlash,
  });

  final UpdraftCore core;
  final UpdraftToken token;
  final Color accent;
  final Color border;
  final Color danger;

  /// 0…1 beat pulse for the two round styles.
  final double pulse;

  /// 0…1 of the single danger pass the arena edge takes on a crash.
  final double edgeFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true;

    for (final p in core.pillars) {
      final radius = Radius.circular(core.pillarWidth * 0.18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(p.x, -radius.y, p.x + core.pillarWidth, p.gapTop),
          radius,
        ),
        outline,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(p.x, p.gapBottom, p.x + core.pillarWidth, size.height + radius.y),
          radius,
        ),
        outline,
      );
    }

    // The token holds where it hit for a beat before the card appears; the sim
    // stops, so drawing it is the same code either way.
    final centre = Offset(core.tokenX, core.y);
    // The round styles read the beat through a scale pulse instead of a tilt.
    final grow = updraftTokenTilts(token) ? 1.0 : 1 + 0.14 * pulse;
    final box = Rect.fromCenter(
        center: Offset.zero, width: core.tokenHeight * grow, height: core.tokenHeight * grow);

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    if (updraftTokenTilts(token)) {
      canvas.rotate(core.tiltDegrees * 3.1415926535 / 180);
    }
    paintUpdraftToken(canvas, token, box, accent);
    canvas.restore();

    if (edgeFlash > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(14),
        ).deflate(1),
        Paint()
          ..color = danger.withValues(alpha: 0.9 * edgeFlash)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(UpdraftPainter old) => true;
}

enum TowerStyle { stack, girder, slab }

TowerStyle towerStyleFromId(String id) => switch (id) {
      'girder' => TowerStyle.girder,
      'slab' => TowerStyle.slab,
      _ => TowerStyle.stack,
    };

class TowerPainter extends CustomPainter {
  TowerPainter({
    required this.core,
    required this.style,
    required this.accent,
    required this.ink,
    required this.border,
    required this.flash,
  });

  final TowerCore core;
  final TowerStyle style;
  final Color accent;
  final Color ink;
  final Color border;

  /// The single accent flash: a block that just widened.
  final bool flash;

  @override
  void paint(Canvas canvas, Size size) {
    // The tower grows upward from the bottom; the camera holds the top few
    // floors on screen once it is taller than the arena.
    final totalHeight = core.floors.length * TowerCore.floorHeight;
    final lift = totalHeight > size.height - 120 ? totalHeight - (size.height - 120) : 0.0;

    for (var i = 0; i < core.floors.length; i++) {
      final f = core.floors[i];
      final y = size.height - (i + 1) * TowerCore.floorHeight + lift;
      if (y > size.height || y < -TowerCore.floorHeight) continue;
      _block(canvas, Rect.fromLTWH(f.left, y, f.width, TowerCore.floorHeight - 1),
          solid: true);
    }

    if (!core.dead) {
      final sweepY = size.height - totalHeight - TowerCore.floorHeight * 2.4 + lift;
      _block(
        canvas,
        Rect.fromLTWH(core.sweepLeft, sweepY.clamp(4.0, size.height),
            core.sweepWidth, TowerCore.floorHeight - 1),
        solid: false,
      );
    }
  }

  void _block(Canvas canvas, Rect rect, {required bool solid}) {
    final colour = solid ? (flash ? accent : border) : accent;
    switch (style) {
      case TowerStyle.stack:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = colour,
        );
      case TowerStyle.slab:
        canvas.drawRect(rect, Paint()..color = colour);
      case TowerStyle.girder:
        canvas.drawRect(
          rect.deflate(0.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = colour,
        );
        canvas.drawLine(rect.centerLeft, rect.centerRight,
            Paint()..color = colour..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(TowerPainter old) => true;
}

class RacerPainter extends CustomPainter {
  RacerPainter({
    required this.core,
    required this.accent,
    required this.ink,
    required this.border,
  });

  final RacerCore core;
  final Color accent;
  final Color ink;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final laneWidth = size.width / RacerCore.lanes;

    // Moving lane dashes are the only motion cue.
    final dash = Paint()
      ..color = border
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var l = 1; l < RacerCore.lanes; l++) {
      final x = l * laneWidth;
      for (var y = -60 + core.dashOffset; y < size.height; y += 60) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 28), dash);
      }
    }

    for (final b in core.blocks) {
      final rect = Rect.fromLTWH(
        b.lane * laneWidth + laneWidth * 0.18,
        b.y,
        laneWidth * 0.64,
        RacerCore.blockHeight,
      );
      // Obstacles are outlined; the car is solid.
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = border,
      );
    }

    final carRect = Rect.fromLTWH(
      core.lane * laneWidth + laneWidth * 0.24,
      size.height * RacerCore.carY,
      laneWidth * 0.52,
      RacerCore.blockHeight * 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect, const Radius.circular(4)),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(RacerPainter old) => true;
}

class AvoiderPainter extends CustomPainter {
  AvoiderPainter({
    required this.core,
    required this.accent,
    required this.ink,
    required this.border,
  });

  final AvoiderCore core;
  final Color accent;
  final Color ink;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.74;

    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = border
        ..strokeWidth = 1.2,
    );

    for (final o in core.obstacles) {
      canvas.drawRect(
        Rect.fromLTWH(o.x, groundY - o.height, 18, o.height),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = border,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          AvoiderCore.playerX,
          groundY - AvoiderCore.playerSize + core.y,
          AvoiderCore.playerSize,
          AvoiderCore.playerSize,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(AvoiderPainter old) => true;
}
