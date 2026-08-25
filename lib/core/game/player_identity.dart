import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The shape drawn inside a player's token. Colour alone is not enough:
/// roughly one player in twelve cannot separate the red and green seats, and
/// a greyscale screenshot separates none of them. Shape is the real key;
/// colour is the fast one.
enum PlayerShape { circle, diamond, triangle, square }

/// A seat at the table: a fixed identity colour, a shape, and a label.
///
/// **Deliberate token exception.** These four colours are *not* theme tokens
/// and do not change with the palette — the same rule Chess uses for its two
/// piece colours. A seat that changed hue with the theme would stop being an
/// identity. They are mid-tone and saturated so they hold contrast against
/// both the near-black and near-white board fills across all eight palettes.
@immutable
class PlayerIdentity {
  const PlayerIdentity({
    required this.index,
    required this.color,
    required this.shape,
    required this.name,
  });

  /// Seat index, 0-based, stable for the life of a game.
  final int index;
  final Color color;
  final PlayerShape shape;

  /// The colour's own name — "Coral", not the person's name.
  final String name;

  /// A single-character mark for tight spots (mono type).
  String get initial => name[0];
}

/// The fixed four-seat palette, in seat order.
const List<PlayerIdentity> kPlayerIdentities = [
  PlayerIdentity(
      index: 0, color: Color(0xFFE05252), shape: PlayerShape.circle, name: 'Coral'),
  PlayerIdentity(
      index: 1, color: Color(0xFF3FA45B), shape: PlayerShape.diamond, name: 'Fern'),
  PlayerIdentity(
      index: 2, color: Color(0xFF4A7FE0), shape: PlayerShape.triangle, name: 'Cobalt'),
  PlayerIdentity(
      index: 3, color: Color(0xFFD9A21B), shape: PlayerShape.square, name: 'Amber'),
];

/// The seats for a [count]-player game, 2–4.
///
/// The subsets are chosen, not truncated: two players get the pair that stays
/// furthest apart in hue *and* shape (circle vs triangle), three add the green.
/// Truncation would have handed a 2-player game red and green, the one pair
/// that collapses for the most common colour-vision deficiency.
List<PlayerIdentity> identitiesFor(int count) {
  assert(count >= 1 && count <= 4);
  return switch (count) {
    1 => const [PlayerIdentity(index: 0, color: Color(0xFFE05252), shape: PlayerShape.circle, name: 'Coral')],
    2 => [kPlayerIdentities[0], _reseat(kPlayerIdentities[2], 1)],
    3 => [kPlayerIdentities[0], _reseat(kPlayerIdentities[2], 1), _reseat(kPlayerIdentities[3], 2)],
    _ => kPlayerIdentities,
  };
}

PlayerIdentity _reseat(PlayerIdentity id, int index) => PlayerIdentity(
    index: index, color: id.color, shape: id.shape, name: id.name);

/// Builds the [PlayerShape] as a path centred on [centre] with the given
/// [radius] (the circumradius). One place defines every seat's geometry, so a
/// painter, a widget preview and a legend all draw the identical mark.
Path playerShapePath(PlayerShape shape, Offset centre, double radius) {
  final path = Path();
  switch (shape) {
    case PlayerShape.circle:
      path.addOval(Rect.fromCircle(center: centre, radius: radius));
    case PlayerShape.square:
      final side = radius * 1.5;
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: side, height: side),
        Radius.circular(radius * 0.22),
      ));
    case PlayerShape.diamond:
      path
        ..moveTo(centre.dx, centre.dy - radius)
        ..lineTo(centre.dx + radius, centre.dy)
        ..lineTo(centre.dx, centre.dy + radius)
        ..lineTo(centre.dx - radius, centre.dy)
        ..close();
    case PlayerShape.triangle:
      // Nudged down so the visual centre of mass sits on [centre].
      final c = centre + Offset(0, radius * 0.12);
      for (var i = 0; i < 3; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / 3;
        final p = c + Offset(math.cos(a) * radius, math.sin(a) * radius);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
  }
  return path;
}

/// Draws a seat's token: filled shape, optional ring for the active turn.
void paintPlayerToken(
  Canvas canvas,
  PlayerIdentity id,
  Offset centre,
  double radius, {
  Color? ring,
  double ringWidth = 2,
  double opacity = 1,
}) {
  final path = playerShapePath(id.shape, centre, radius);
  canvas.drawPath(
      path,
      Paint()
        ..color = opacity == 1 ? id.color : id.color.withValues(alpha: opacity)
        ..isAntiAlias = true);
  if (ring != null) {
    canvas.drawPath(
        playerShapePath(id.shape, centre, radius + ringWidth),
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..isAntiAlias = true);
  }
}
