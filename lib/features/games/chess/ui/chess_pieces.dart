import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/dally_tokens.dart';

/// Piece render style, chosen in the pause sheet.
enum PieceStyle { classic, outline, pebble, pebbleOutline, minimal, letters }

PieceStyle pieceStyleFromId(String? id) => switch (id) {
      'outline' => PieceStyle.outline,
      'pebble' => PieceStyle.pebble,
      'pebbleOutline' => PieceStyle.pebbleOutline,
      'minimal' => PieceStyle.minimal,
      'letters' => PieceStyle.letters,
      _ => PieceStyle.classic,
    };

/// True for the two styles drawn as a hollow shell under a heavier contour.
bool _isOutline(PieceStyle s) =>
    s == PieceStyle.outline || s == PieceStyle.pebbleOutline;

/// True for the rounded set.
bool _isPebble(PieceStyle s) =>
    s == PieceStyle.pebble || s == PieceStyle.pebbleOutline;

// ── The drawn sets (from `Dally Chess Pieces.dc.html`) ──────────────────────
// One 64×64 grid throughout, symmetric about x=32, with the height hierarchy
// King < Queen < Bishop < Knight < Rook < Pawn so a board reads by height
// before it reads by shape.
//
// * **Classic** (pass 5) is the Staunton standard: a shared base+skirt (TAIL),
//   a shared collar, and two details painted in the contour colour.
// * **Pebble** (pass 7) is the rounded set: one closed path per piece, no
//   internal shapes and no detail lines, so nothing goes muddy at 20px.
// * **Minimal** is six primitives on a base bar; **Letters** is the type stack
//   over the same bar.
//
// Side is purely a paint choice — there is never per-theme artwork.
//
// The shapes are original artwork on the public, unprotected Staunton forms.
// No commercial or branded set, online or physical, was traced or sampled.

const String _tail =
    'L44.5 46C45.5 50 47 53 49.2 54.6C49.8 55 50 55.6 50 56.2V57H14V56.2C14 55.6 14.2 55 14.8 54.6C17 53 18.5 50 19.5 46Z';

/// The stem King, Queen and Bishop share, so their collars sit at one height.
const String _body = 'C22 38 23.6 35.4 25 33.6H39C40.4 35.4 42 38 43 42';

/// Pebble's shared slab base, and the lower body B/Q/K share above it.
const String _pTail =
    'H49.6C50.7 50.4 51.6 51.3 51.6 52.4V55.4C51.6 56.5 50.7 57.4 49.6 57.4H14.4C13.3 57.4 12.4 56.5 12.4 55.4V52.4C12.4 51.3 13.3 50.4 14.4 50.4H19.4';
const String _pLower =
    'H42.6C43.6 33.9 44.4 34.7 44.4 35.7V38C44.4 39 43.6 39.8 42.6 39.8H39.4C41.4 43 43.4 46.8 44.6 50.4$_pTail'
    'C20.6 46.8 22.6 43 24.6 39.8H21.4C20.4 39.8 19.6 39 19.6 38V35.7C19.6 34.7 20.4 33.9 21.4 33.9';

/// A drawable primitive in 64-space: an SVG `<path>`, `<circle>` or `<rect>`.
sealed class _Shape {
  const _Shape();
  String svg(String attrs);
}

class _P extends _Shape {
  const _P(this.d);
  final String d;
  @override
  String svg(String a) => '<path d="$d" $a/>';
}

class _C extends _Shape {
  const _C(this.cx, this.cy, this.r);
  final double cx, cy, r;
  @override
  String svg(String a) => '<circle cx="$cx" cy="$cy" r="$r" $a/>';
}

class _R extends _Shape {
  const _R(this.x, this.y, this.w, this.h, this.rx);
  final double x, y, w, h, rx;
  @override
  String svg(String a) => '<rect x="$x" y="$y" width="$w" height="$h" rx="$rx" $a/>';
}

const _R _bar = _R(19, 51.5, 26, 3.2, 1.6);
_C _ball(double cx, double cy) => _C(cx, cy, 1.9);

/// Classic, pass 5 — the Staunton standard drawn in Dally's hand.
final Map<Role, List<_Shape>> _classic = {
  // ball head, turned collar, flared stem
  Role.pawn: [
    const _P(
        'M21 42C22 38 24.6 34.4 27.2 31.4C28.4 30 29 28.8 29 27.4H35C35 28.8 35.6 30 36.8 31.4C39.4 34.4 42 38 43 42$_tail'),
    const _R(22.5, 37.4, 19, 4.6, 1.6),
    const _C(32, 21, 6.4),
  ],
  // three merlons, cornice, slightly waisted tower
  Role.rook: [
    const _P(
        'M21 42C21.6 37 22.4 32.6 22.2 28.8H41.8C41.6 32.6 42.4 37 43 42$_tail'),
    const _R(17.6, 24.4, 28.8, 4.6, 1.2),
    const _P('M18.6 14H23.6V18.2H28.2V14H35.8V18.2H40.4V14H45.4V24.8H18.6Z'),
  ],
  // horse head in profile, facing the opponent
  Role.knight: [
    const _P(
        'M21 42C21.4 38 22.6 34.6 24.6 32C26.4 29.6 26.2 27.4 24.4 26.4C21.6 25 18.8 24.4 17.4 22.6C16.6 21.6 17 20.6 18.4 20.2C20 19.7 21.6 19.4 22.6 18.6C23.6 17.8 23.4 16.4 24.6 15.2C26 13.6 27.6 12.8 29 12.4L28.4 10.6C28.3 10.1 28.8 9.9 29.1 10.3L31.4 13.2L33.2 9.8C33.4 9.4 33.9 9.4 34.1 9.8C35.2 12.2 36.6 13.4 37.6 15.2C40 19.6 41.6 24 42.4 28.6C42.9 32.6 43 38 43 42$_tail'),
  ],
  // mitre with its slit, ball finial, turned collar
  Role.bishop: [
    const _P('M21 42$_body$_tail'),
    const _R(21.5, 29.6, 21, 4.8, 1.8),
    const _P(
        'M32 13.2C36.6 19 39.4 24.2 39.4 28.2C39.4 31 36.2 32.6 32 32.6C27.8 32.6 24.6 31 24.6 28.2C24.6 24.2 27.4 19 32 13.2Z'),
    const _C(32, 11.6, 2.4),
  ],
  // five-point coronet, each point balled
  Role.queen: [
    const _P('M21 42$_body$_tail'),
    const _R(21.5, 29.6, 21, 4.8, 1.8),
    const _P(
        'M23.4 30.6C21.8 27 21 23 21 19.4L25.6 24L28.4 15.6L30.7 21.6L32 12.4L33.3 21.6L35.6 15.6L38.4 24L43 19.4C43 23 42.2 27 40.6 30.6Z'),
    _ball(21, 17.6),
    _ball(28.4, 13.8),
    _ball(32, 10.6),
    _ball(35.6, 13.8),
    _ball(43, 17.6),
  ],
  // banded crown under a cross
  Role.king: [
    const _P('M21 42$_body$_tail'),
    const _R(21.5, 29.8, 21, 4.8, 1.8),
    const _P(
        'M24 30.6C22 27.2 21.4 23.2 22.4 20C23.6 16.6 27 14.6 32 14.6C37 14.6 40.4 16.6 41.6 20C42.6 23.2 42 27.2 40 30.6Z'),
    const _R(22.4, 21.6, 19.2, 4, 1.4),
    const _P('M30.2 5.2h3.6v3.4h3.4v3.6h-3.4v4h-3.6v-4H26.8V8.6h3.4z'),
  ],
};

/// Pebble, pass 7 — the rounded set. One closed path a piece: no internal
/// shapes, no detail lines, nothing to go muddy at 20px.
final Map<Role, List<_Shape>> _pebble = {
  // ball head · narrow waist · collar bar · concave flare
  Role.pawn: [
    const _P(
        'M32 13.6C36 13.6 39.2 16.8 39.2 20.8C39.2 23.2 38 25.3 36.2 26.6H37.6C38.5 26.6 39.2 27.3 39.2 28.2C39.2 29.1 38.5 29.8 37.6 29.8H36.4C38.4 33.8 42.4 41.6 44.6 50.4${_pTail}C21.6 41.6 25.6 33.8 27.6 29.8H26.4C25.5 29.8 24.8 29.1 24.8 28.2C24.8 27.3 25.5 26.6 26.4 26.6H27.8C26 25.3 24.8 23.2 24.8 20.8C24.8 16.8 28 13.6 32 13.6Z'),
  ],
  // rounded merlons over a slab cornice — the crown is the widest part
  Role.rook: [
    const _P(
        'M16.6 16C16.6 14.9 17.5 14 18.6 14H22.8C23.9 14 24.8 14.9 24.8 16V19.8H29.6V16C29.6 14.9 30.5 14 31.6 14H32.4C33.5 14 34.4 14.9 34.4 16V19.8H39.2V16C39.2 14.9 40.1 14 41.2 14H45.4C46.5 14 47.4 14.9 47.4 16V23.4H48.6C49.4 23.4 50 24 50 24.8V28.4C50 29.2 49.4 29.8 48.6 29.8H42.6C41.6 36.6 41.8 44 43.4 50.4${_pTail}C20.6 44 20.8 36.6 21.4 29.8H15.4C14.6 29.8 14 29.2 14 28.4V24.8C14 24 14.6 23.4 15.4 23.4H16.6Z'),
  ],
  // blunt muzzle, deep jaw, one soft ear, thick neck
  Role.knight: [
    const _P(
        'M33.8 12.8C34.2 11.2 35.2 9.8 36.4 9.3C37.6 8.8 38.4 10 37.9 11.4L36.9 14.1C41.7 16.2 45.1 19.9 46.4 24.4C47.6 28.2 47.4 30.8 46.8 34.2C46.2 39.6 45.2 45.4 44.6 50.4${_pTail}C19.6 44.4 22.4 38.8 26.8 34.4C28.6 32.4 28.2 30 25.4 30.2C22.6 27.4 19.2 27.2 16.4 28.8C14.4 29.9 13.2 27.6 14.8 25.9C16.4 24.3 18.4 22.5 20.8 20.7C24.4 17.9 29.4 15.1 33.8 12.8Z'),
  ],
  // near-circular mitre with a ball
  Role.bishop: [
    const _P(
        'M23.2 29.2C23.2 25.9 25.8 21.3 30.1 15.8C29.6 15.3 29.3 14.6 29.3 13.9C29.3 12.4 30.5 11.2 32 11.2C33.5 11.2 34.7 12.4 34.7 13.9C34.7 14.6 34.4 15.3 33.9 15.8C38.2 21.3 40.8 25.9 40.8 29.2C40.8 31.6 38.6 33.4 35.4 33.9${_pLower}H28.6C25.4 33.4 23.2 31.6 23.2 29.2Z'),
  ],
  // five balls on a wide coronet — a solid rounded fan, not spikes
  Role.queen: [
    const _P(
        'M21.6 28.6C20.6 25.6 19.6 21.6 19.6 19.6L16.6 17.4A2.8 2.8 0 0 1 22.2 17.4L22.8 14.6A2.9 2.9 0 0 1 28.6 14.6L28.9 12.6A3.1 3.1 0 0 1 35.1 12.6L35.4 14.6A2.9 2.9 0 0 1 41.2 14.6L41.8 17.4A2.8 2.8 0 0 1 47.4 17.4L44.4 19.6C44.4 21.6 43.4 25.6 42.4 28.6H45.2C46.1 28.6 46.8 29.3 46.8 30.2V31.8C46.8 32.7 46.1 33.4 45.2 33.4H41.8C42.4 39.4 43.4 46 44.6 50.4${_pTail}C20.6 46 21.6 39.4 22.2 33.4H18.8C17.9 33.4 17.2 32.7 17.2 31.8V30.2C17.2 29.3 17.9 28.6 18.8 28.6Z'),
  ],
  // a broad dome, a band, and a stubby rounded cross
  Role.king: [
    const _P(
        'M23.2 28.6C21.4 25 20.8 21 22.6 18.4C24 16.4 26.4 15.2 29.4 15V13.8H27.6C26.4 13.8 25.4 12.8 25.4 11.6C25.4 10.4 26.4 9.4 27.6 9.4H29.4V7.4C29.4 6.2 30.4 5.2 31.6 5.2H32.4C33.6 5.2 34.6 6.2 34.6 7.4V9.4H36.4C37.6 9.4 38.6 10.4 38.6 11.6C38.6 12.8 37.6 13.8 36.4 13.8H34.6V15C37.6 15.2 40 16.4 41.4 18.4C43.2 21 42.6 25 40.8 28.6H44C44.9 28.6 45.6 29.3 45.6 30.2V31.8C45.6 32.7 44.9 33.4 44 33.4H41C41.8 39.4 42.8 46 44.6 50.4${_pTail}C21.2 46 22.2 39.4 23 33.4H20C19.1 33.4 18.4 32.7 18.4 31.8V30.2C18.4 29.3 19.1 28.6 20 28.6Z'),
  ],
};

/// Classic's two details, painted in the **contour** colour rather than cut
/// out, so they survive at 20px and never punch a hole in a filled piece.
/// Pebble has none by design — its silhouette does all the work.
const Map<Role, List<(String, double)>> _classicDetail = {
  Role.bishop: [('M34.8 19.4 29.8 26.6', 1.1)],
  Role.knight: [('M37 15.6C39.2 19.6 40.4 23.4 40.9 27.4', 1.0)],
};

/// The knight's eye, which is a dot rather than a stroke.
const _C _knightEye = _C(24.9, 19.8, 1.15);

final Map<Role, List<_Shape>> _minimal = {
  Role.pawn: [_bar, const _C(32, 40, 7)],
  Role.rook: [_bar, const _R(25, 32, 14, 15, 1.5)],
  Role.knight: [_bar, const _P('M41.5 47H22.5L41.5 25.5Z')],
  Role.bishop: [_bar, const _P('M32 23L43.5 35.5 32 48 20.5 35.5Z')],
  Role.queen: [_bar, const _P('M32 21.5L42.2 27.6V39.8L32 46 21.8 39.8V27.6Z')],
  Role.king: [_bar, const _P('M27.5 21.5h9v9h9v9h-9v8h-9v-8h-9v-9h9z')],
};

const Map<Role, String> _letter = {
  Role.king: 'K',
  Role.queen: 'Q',
  Role.rook: 'R',
  Role.bishop: 'B',
  Role.knight: 'N',
  Role.pawn: 'P',
};

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Builds the SVG for any drawn piece — Classic, Pebble or Minimal, filled or
/// hollow. Light side takes the fixed cream fill + dark hairline; dark side
/// takes the accent + a lighter tint of itself. A hollow style draws a neutral
/// fill under a heavier contour line.
String _pieceSvg({
  required Role role,
  required PieceStyle style,
  required bool light,
  required DallyTokens t,
  required double size,
}) {
  final fill = light ? t.pieceLight : t.pieceDark;
  final line = light ? t.pieceLightOutline : t.pieceDarkOutline;
  final outline = _isOutline(style);
  final pebble = _isPebble(style);
  final shapes = switch (style) {
    PieceStyle.minimal => _minimal[role]!,
    PieceStyle.pebble || PieceStyle.pebbleOutline => _pebble[role]!,
    _ => _classic[role]!,
  };
  // The contour is a CONSTANT device-px width — it must never scale with the
  // square (design doc), or the fixed light side thins out and vanishes on the
  // light boards (Paper/Meadow/Blush). rendered_px = units × size/64, so invert.
  //
  // Pebble is drawn with a heavier contour than Classic — 1.7u against 1.1u,
  // and 2.6u against 2.4u when hollow — so the ratio rides along.
  const classicContourPx = 0.75, classicOutlinePx = 1.6;
  final contourPx = pebble ? classicContourPx * 1.7 / 1.1 : classicContourPx;
  final outlinePx = pebble ? classicOutlinePx * 2.6 / 2.4 : classicOutlinePx;
  final contour = (contourPx * 64 / size).toStringAsFixed(3);
  final outlineW = (outlinePx * 64 / size).toStringAsFixed(3);
  // A hollow Classic is stroked in its own fill. A hollow Pebble strokes the
  // light side in whichever of the two fixed piece colours the *page* is not:
  // the near-black hairline on a light board, the cream on a dark one. Stroking
  // it in the hairline everywhere left the white side invisible on Ink.
  final hollowStroke = !pebble
      ? fill
      : (light ? (t.isDark ? t.pieceLight : t.pieceLightOutline) : t.pieceDark);
  final attrs = outline
      ? 'fill="${_hex(light ? t.pieceHollowLight : t.pieceHollowDark)}" '
          'stroke="${_hex(hollowStroke)}" stroke-width="$outlineW" stroke-linejoin="round" stroke-linecap="round"'
      : 'fill="${_hex(fill)}" stroke="${_hex(line)}" stroke-width="$contour" stroke-linejoin="round"';

  final buf = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
      'width="$size" height="$size" viewBox="0 0 64 64">');
  for (final s in shapes) {
    buf.write(s.svg(attrs));
  }
  // Classic's details — the bishop's mitre slit, the knight's mane and eye —
  // painted in the contour colour rather than cut out. Pebble has none: its
  // silhouette does all the work, so there is nothing here to go muddy at 20px.
  if (style == PieceStyle.classic || style == PieceStyle.outline) {
    final detailColour = _hex(outline ? hollowStroke : line);
    final width = outline ? outlinePx : contourPx;
    for (final (d, w) in _classicDetail[role] ?? const <(String, double)>[]) {
      final px = (width * w / 1.1 * 64 / size).toStringAsFixed(3);
      buf.write('<path d="$d" stroke="$detailColour" stroke-width="$px" '
          'stroke-linecap="round" fill="none"/>');
    }
    if (role == Role.knight) {
      buf.write(_knightEye.svg('fill="$detailColour" stroke="none"'));
    }
  }
  buf.write('</svg>');
  return buf.toString();
}

/// Renders a chess piece. Light-side fill is fixed ([Palette.pieceLight]); the
/// dark side takes the palette accent — never inverted across themes.
class PieceGlyph extends StatelessWidget {
  const PieceGlyph({super.key, required this.piece, required this.style, required this.size});

  final Piece piece;
  final PieceStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final light = piece.color == Side.white;

    if (style == PieceStyle.letters) {
      return _Letter(role: piece.role, light: light, size: size, tokens: t);
    }
    return SvgPicture.string(
      _pieceSvg(role: piece.role, style: style, light: light, t: t, size: size),
      width: size,
      height: size,
    );
  }
}

/// Letters style: the type stack over the shared base bar. Drawn with Flutter
/// text (a fill pass + an outline pass) so it stays crisp without SVG fonts.
class _Letter extends StatelessWidget {
  const _Letter({required this.role, required this.light, required this.size, required this.tokens});
  final Role role;
  final bool light;
  final double size;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final fill = light ? tokens.pieceLight : tokens.pieceDark;
    final line = light ? tokens.pieceLightOutline : tokens.pieceDarkOutline;
    final char = _letter[role]!;
    TextStyle base(Paint? fg, Color? color) => TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: size * 0.48,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          height: 1,
          color: color,
          foreground: fg,
        );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base bar (rect 19,51.5 → 45,54.7 in 64-space).
          Positioned(
            top: size * 51.5 / 64,
            left: size * 19 / 64,
            width: size * 26 / 64,
            height: size * 3.2 / 64,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(size * 1.6 / 64),
                border: Border.all(color: line, width: 0.8),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.18),
            child: Stack(
              children: [
                Text(char, style: base(null, fill)),
                Text(char,
                    style: base(
                        Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = size * 0.014
                          ..color = line,
                        null)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
