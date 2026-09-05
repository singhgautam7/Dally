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

/// The identity's own colour, one step darker — the **mandatory** hairline
/// whenever the mode is Light.
///
/// Measured against the Light background the four fixed fills read 3.08, 2.03,
/// 3.34 and 2.49; two of the four are under the 3:1 a graphical object needs to
/// carry meaning on its own. The hairline is what carries the edge, lifting all
/// four to 3.26 and above. The fills themselves do not move — they are shared
/// with saved games and screenshots — so the edge is the thing that changes.
///
/// Added in phase 7 as a light-theme refinement; required since phase 21.
Color identityOutline(PlayerIdentity id) =>
    Color.lerp(id.color, const Color(0xFF000000), 0.34)!;

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

/// How a seat's token is drawn on a board. Geometry only, per the style rules:
/// the colour is the identity's either way.
enum PlayerTokenStyle {
  /// A flat map-pin teardrop whose point lands on the cell, so which square a
  /// token occupies is never ambiguous even at a 19px cell. The head carries
  /// the identity colour with the identity glyph knocked out of it.
  pin,

  /// A pawn silhouette, with the identity glyph knocked out of its base.
  pawn,

  /// The bare identity shape: circle, diamond, triangle, square.
  geometric,
}

PlayerTokenStyle tokenStyleFromId(String? id) => switch (id) {
      'geometric' => PlayerTokenStyle.geometric,
      'pawn' => PlayerTokenStyle.pawn,
      _ => PlayerTokenStyle.pin,
    };

/// The pawn silhouette, drawn in an 18×24 box and scaled to fit a token of
/// [radius] (half the token's width). Head, waisted body, base bar — no
/// outline, no shadow, so it reads the same on all eight palettes.
Path pawnPath(Offset centre, double radius) {
  final scale = radius * 2 / 18;
  final left = centre.dx - radius;
  final top = centre.dy - 24 * scale / 2;
  double x(double v) => left + v * scale;
  double y(double v) => top + v * scale;

  return Path()
    ..addOval(Rect.fromCircle(center: Offset(x(9), y(5.2)), radius: 4.0 * scale))
    ..moveTo(x(6.6), y(7.6))
    ..cubicTo(x(6.6), y(12.4), x(4.8), y(14.8), x(3.7), y(17.4))
    ..lineTo(x(14.3), y(17.4))
    ..cubicTo(x(13.2), y(14.8), x(11.4), y(12.4), x(11.4), y(7.6))
    ..close()
    ..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(x(2.2), y(17.4), x(15.8), y(21.8)),
      Radius.circular(1.5 * scale),
    ));
}

/// The pin silhouette: a 12.4 × 18.4 teardrop — a head of radius 6.2 with the
/// sides drawn in to a point 12.2 below its centre.
///
/// [tip] is where the point lands. Everything else hangs above it, which is the
/// whole reason the shape exists: the anchor is a single unambiguous spot even
/// when two pins share a cell.
Path pinPath(Offset tip, double headRadius) {
  final r = headRadius;
  final head = Offset(tip.dx, tip.dy - r * 1.968);
  // Where the sides leave the head — just past its widest point, so the curve
  // reads as continuous rather than as a circle with a triangle stuck on it.
  const flare = 0.30;
  return Path()
    ..moveTo(tip.dx, tip.dy)
    ..cubicTo(head.dx - r * 0.52, head.dy + r * 1.25, head.dx - r, head.dy + r * flare,
        head.dx - r, head.dy)
    ..arcToPoint(Offset(head.dx + r, head.dy),
        radius: Radius.circular(r), clockwise: true)
    ..cubicTo(head.dx + r, head.dy + r * flare, head.dx + r * 0.52, head.dy + r * 1.25,
        tip.dx, tip.dy)
    ..close();
}

/// A pin's height as a multiple of the nominal token radius — the design's
/// "16px on a 22px cell". It is drawn from its tip upward, so this is also how
/// far above the cell centre it reaches.
const double _pinHeight = 2.2;

/// The head radius of a pin drawn at the nominal token [radius]. The 12.4 × 18.4
/// teardrop is 2.968 head-radii tall.
double pinHeadRadius(double radius) => radius * _pinHeight / 2.968;

/// Where a tip-anchored pin's head sits, given the cell centre it points at.
/// Rings, badges and anything else that decorates a pin hangs off this rather
/// than off the cell, because the head is the part the eye reads as the token.
Offset pinHeadCentre(Offset anchor, double radius) =>
    Offset(anchor.dx, anchor.dy - pinHeadRadius(radius) * 1.968);

/// Draws a seat's token: filled shape, optional ring for the active turn.
///
/// [knockout] is the colour the pawn's base glyph is punched in — the board
/// behind it — so the redundant shape channel survives the shared silhouette.
void paintPlayerToken(
  Canvas canvas,
  PlayerIdentity id,
  Offset centre,
  double radius, {
  Color? ring,
  double ringWidth = 2,
  double opacity = 1,
  PlayerTokenStyle style = PlayerTokenStyle.geometric,
  Color? knockout,
  bool lightMode = false,
}) {
  final fill = Paint()
    ..color = opacity == 1 ? id.color : id.color.withValues(alpha: opacity)
    ..isAntiAlias = true;

  // In Light the hairline is not a refinement — two of the four fills sit
  // under 3:1 against the light background without it (see [identityOutline]).
  final edge = lightMode
      ? (Paint()
        ..color = opacity == 1
            ? identityOutline(id)
            : identityOutline(id).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, radius * 0.12)
        ..isAntiAlias = true)
      : null;

  if (style == PlayerTokenStyle.pin) {
    // A map pin, anchored the way a map pin is: the **point sits on the cell
    // centre** and the head rises above it, overflowing the cell. Boxing the
    // whole shape inside the square is what made it read as cramped and left
    // which square it occupied ambiguous.
    final headRadius = pinHeadRadius(radius);
    final tip = centre;
    final head = pinHeadCentre(tip, radius);
    canvas.drawPath(pinPath(tip, headRadius), fill);
    if (edge != null) canvas.drawPath(pinPath(tip, headRadius), edge);
    if (knockout != null) {
      canvas.drawPath(
        playerShapePath(id.shape, head, headRadius * 0.403),
        Paint()
          ..color = knockout
          ..isAntiAlias = true,
      );
    }
  } else if (style == PlayerTokenStyle.pawn) {
    canvas.drawPath(pawnPath(centre, radius), fill);
    if (edge != null) canvas.drawPath(pawnPath(centre, radius), edge);
    if (knockout != null) {
      // The glyph sits in the base bar, at the size the 12px Ludo cell allows.
      final base = Offset(centre.dx, centre.dy + radius * 0.66);
      canvas.drawPath(
        playerShapePath(id.shape, base, radius * 0.26),
        Paint()
          ..color = knockout
          ..isAntiAlias = true,
      );
    }
  } else {
    canvas.drawPath(playerShapePath(id.shape, centre, radius), fill);
    if (edge != null) {
      canvas.drawPath(playerShapePath(id.shape, centre, radius), edge);
    }
  }

  if (ring != null) {
    final path = switch (style) {
      // A ring round the whole pin would swallow the point; it rings the head,
      // which is the part the eye reads as the token.
      PlayerTokenStyle.pin => Path()
        ..addOval(Rect.fromCircle(
            center: pinHeadCentre(centre, radius),
            radius: pinHeadRadius(radius) + ringWidth)),
      PlayerTokenStyle.pawn =>
        Path()..addOval(Rect.fromCircle(center: centre, radius: radius + ringWidth)),
      PlayerTokenStyle.geometric =>
        playerShapePath(id.shape, centre, radius + ringWidth),
    };
    canvas.drawPath(
        path,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..isAntiAlias = true);
  }
}

