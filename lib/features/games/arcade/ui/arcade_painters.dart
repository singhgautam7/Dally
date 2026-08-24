import 'package:flutter/material.dart';

import '../logic/avoider_core.dart';
import '../logic/jumper_core.dart';
import '../logic/racer_core.dart';
import '../logic/tower_core.dart';

/// House drawing rules for the whole arcade: squares, bars, hairlines, one
/// accent. Obstacles are outlined; the player is solid. No scrolling texture,
/// no faces, no parallax.

enum JumperStyle { blocks, hairline, pixel }

JumperStyle jumperStyleFromId(String id) => switch (id) {
      'hairline' => JumperStyle.hairline,
      'pixel' => JumperStyle.pixel,
      _ => JumperStyle.blocks,
    };

class JumperPainter extends CustomPainter {
  JumperPainter({
    required this.core,
    required this.style,
    required this.accent,
    required this.ink,
    required this.border,
    required this.bestHeight,
  });

  final JumperCore core;
  final JumperStyle style;
  final Color accent;
  final Color ink;
  final Color border;
  final double bestHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(style == JumperStyle.pixel ? 0 : 3);

    for (final p in core.platforms) {
      final rect = Rect.fromLTWH(p.x, p.y, p.width, JumperCore.platformHeight);
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

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(core.playerX, core.playerY, JumperCore.playerSize, JumperCore.playerSize),
        radius,
      ),
      Paint()..color = accent,
    );

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
