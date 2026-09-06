import 'dart:math' as math;
import 'dart:ui';

/// Updraft's four token styles. Geometry only — the accent stays the accent in
/// every one.
///
/// The enum lives in `logic/` rather than beside the painter because the *core*
/// needs it: a run ends when the shape you can see touches something, so the
/// selected style is a rule, not a decoration (`.agents/CLAUDE.md` §2.2).
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

/// A token's collision shape: the same silhouette the painter draws.
///
/// Two primitives cover all four styles — a circle for the round ones, and a
/// set of **convex** polygons for the angular ones (the dart is concave at its
/// notch, so it is carried as its two wings). Everything is in arena
/// coordinates, already rotated by the token's tilt.
///
/// The scale pulse the round styles play on a beat is deliberately *not* in
/// here: collision must not breathe.
class TokenSilhouette {
  const TokenSilhouette.circle({required this.centre, required this.radius})
      : polygons = const [];

  const TokenSilhouette.convex(this.polygons)
      : centre = Offset.zero,
        radius = 0;

  final Offset centre;
  final double radius;
  final List<List<Offset>> polygons;

  bool get isCircle => polygons.isEmpty;

  /// The silhouette's vertical extent — what the floor and the ceiling test.
  double get top => isCircle
      ? centre.dy - radius
      : polygons.expand((p) => p).map((o) => o.dy).reduce(math.min);

  double get bottom => isCircle
      ? centre.dy + radius
      : polygons.expand((p) => p).map((o) => o.dy).reduce(math.max);

  double get left => isCircle
      ? centre.dx - radius
      : polygons.expand((p) => p).map((o) => o.dx).reduce(math.min);

  double get right => isCircle
      ? centre.dx + radius
      : polygons.expand((p) => p).map((o) => o.dx).reduce(math.max);

  /// True when the silhouette overlaps the axis-aligned [rect]. An empty or
  /// inverted rect never hits, which is what makes a one-sided pillar's missing
  /// slab cost nothing.
  bool hitsRect(Rect rect) {
    if (rect.isEmpty) return false;
    if (isCircle) {
      final nx = centre.dx.clamp(rect.left, rect.right);
      final ny = centre.dy.clamp(rect.top, rect.bottom);
      final dx = centre.dx - nx, dy = centre.dy - ny;
      return dx * dx + dy * dy <= radius * radius;
    }
    return polygons.any((p) => _polygonHitsRect(p, rect));
  }
}

/// Separating-axis test between a convex polygon and an axis-aligned rect.
bool _polygonHitsRect(List<Offset> poly, Rect rect) {
  final axes = <Offset>[const Offset(1, 0), const Offset(0, 1)];
  for (var i = 0; i < poly.length; i++) {
    final e = poly[(i + 1) % poly.length] - poly[i];
    final len = e.distance;
    if (len > 0) axes.add(Offset(-e.dy / len, e.dx / len));
  }
  final corners = [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ];
  for (final a in axes) {
    var pMin = double.infinity, pMax = double.negativeInfinity;
    for (final v in poly) {
      final d = v.dx * a.dx + v.dy * a.dy;
      pMin = math.min(pMin, d);
      pMax = math.max(pMax, d);
    }
    var rMin = double.infinity, rMax = double.negativeInfinity;
    for (final v in corners) {
      final d = v.dx * a.dx + v.dy * a.dy;
      rMin = math.min(rMin, d);
      rMax = math.max(rMax, d);
    }
    if (pMax < rMin || rMax < pMin) return false; // a gap: no overlap
  }
  return true;
}

/// The silhouette of [token] drawn centred on [centre] inside a [size]-square
/// box, tilted by [tiltRadians] for the styles that tilt.
///
/// The vertices mirror `paintUpdraftToken` one for one; the only simplification
/// is the block's 16% corner rounding, which is inside the consistent tolerance
/// every style shares.
TokenSilhouette updraftSilhouette({
  required UpdraftToken token,
  required Offset centre,
  required double size,
  required double tiltRadians,
}) {
  final h = size / 2;
  switch (token) {
    case UpdraftToken.dot:
    case UpdraftToken.ring:
      // The ring's stroke is centred at r - 0.11w with width 0.22w, so its
      // outer edge is the same circle the dot fills.
      return TokenSilhouette.circle(centre: centre, radius: h);
    case UpdraftToken.block:
      return TokenSilhouette.convex([
        _place([
          Offset(-h, -h),
          Offset(h, -h),
          Offset(h, h),
          Offset(-h, h),
        ], centre, tiltRadians),
      ]);
    case UpdraftToken.dart:
      // Tip right, two swept-back wings, notched at the tail — carried as the
      // two convex wings so the notch is genuinely empty.
      final tip = Offset(h, 0);
      final topBack = Offset(-h, -h);
      final bottomBack = Offset(-h, h);
      final notch = Offset(-h + size * 0.3, 0);
      return TokenSilhouette.convex([
        _place([tip, topBack, notch], centre, tiltRadians),
        _place([tip, notch, bottomBack], centre, tiltRadians),
      ]);
  }
}

List<Offset> _place(List<Offset> local, Offset centre, double tilt) {
  final c = math.cos(tilt), s = math.sin(tilt);
  return [
    for (final p in local)
      Offset(centre.dx + p.dx * c - p.dy * s, centre.dy + p.dx * s + p.dy * c),
  ];
}
