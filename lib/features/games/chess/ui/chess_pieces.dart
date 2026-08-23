import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/dally_tokens.dart';

/// Piece render style, chosen in the pause sheet.
enum PieceStyle { classic, outline, minimal, letters }

PieceStyle pieceStyleFromId(String? id) => switch (id) {
      'outline' => PieceStyle.outline,
      'minimal' => PieceStyle.minimal,
      'letters' => PieceStyle.letters,
      _ => PieceStyle.classic,
    };

// ── The drawn set (from `Dally Chess Pieces.dc.html`) ────────────────────────
// One 64×64 grid. Classic and Outline share six silhouettes built on a shared
// base+skirt (TAIL) and collar; Minimal is six primitives on a base bar;
// Letters is the type stack over the same bar. Side is purely a paint choice.

const String _tail =
    'L44.5 46C45.5 50 47 53 49.2 54.6C49.8 55 50 55.6 50 56.2V57H14V56.2C14 55.6 14.2 55 14.8 54.6C17 53 18.5 50 19.5 46Z';

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

const _R _collar = _R(19, 37.4, 26, 5, 2);
const _R _bar = _R(19, 51.5, 26, 3.2, 1.6);
_C _ball(double cx, double cy) => _C(cx, cy, 1.9);

final Map<Role, List<_Shape>> _classic = {
  Role.pawn: [
    const _P(
        'M21 42C22 37.5 24 34 26.2 31.2C26.8 30.4 27.3 29.2 27.4 27.6A8 8 0 1 1 36.6 27.6C36.7 29.2 37.2 30.4 37.8 31.2C40 34 42 37.5 43 42$_tail'),
    const _R(21.5, 36.6, 21, 4.8, 1.8),
  ],
  Role.rook: [
    const _P('M21 42V31.5L19 28V19H24.5V23.5H29.5V19H34.5V23.5H39.5V19H45V28L43 31.5V42$_tail'),
  ],
  Role.knight: [
    const _P(
        'M21 42C21.5 37 23 33 25.5 30.5C23 29.5 20.5 29 18.5 28C16.5 27 16 25.5 17.5 23.5C19.5 21 22 19.5 24.5 18.5C25.5 16.5 26.5 14 27.5 12.5L29 9.5L30.5 13L32.5 10.5L34 14C37 16 39.5 19 40.5 23C41.5 28 41.8 34 42.2 38L43 42$_tail'),
  ],
  Role.bishop: [
    const _P(
        'M21 42C21.5 37 23 33 25.5 30C23.5 27 24 22 27 18C29 15.3 31 13.5 32 12.6C33 13.5 35 15.3 37 18C40 22 40.5 27 38.5 30C41 33 42.5 37 43 42$_tail'),
    const _C(32, 10.2, 2.3),
    _collar,
  ],
  Role.queen: [
    const _P(
        'M21 42C21.5 37 23 33.5 25 31L22 20.5L26 25L27.5 15.5L30 23L32 12.5L34 23L36.5 15.5L38 25L42 20.5L39 31C41 33.5 42.5 37 43 42$_tail'),
    _collar,
    _ball(22, 19.6),
    _ball(27.5, 14.6),
    _ball(32, 11.6),
    _ball(36.5, 14.6),
    _ball(42, 19.6),
  ],
  Role.king: [
    const _P(
        'M21 42C21.5 37 23 33.5 25 31L22.5 21L28 25.5L32 19L36 25.5L41.5 21L39 31C41 33.5 42.5 37 43 42$_tail'),
    _collar,
    const _P('M30.4 6.4h3.2V10h3.4v3.2h-3.4v4.2h-3.2v-4.2H27V10h3.4z'),
  ],
};

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

/// Builds the SVG for a Classic/Outline/Minimal piece. Light side takes the
/// fixed cream fill + dark hairline; dark side takes the accent + a lighter tint
/// of itself. Outline draws a neutral hollow fill under a heavier contour line.
String _pieceSvg({
  required Role role,
  required PieceStyle style,
  required bool light,
  required DallyTokens t,
  required double size,
}) {
  final fill = light ? t.pieceLight : t.pieceDark;
  final line = light ? t.pieceLightOutline : t.pieceDarkOutline;
  final outline = style == PieceStyle.outline;
  final shapes = style == PieceStyle.minimal ? _minimal[role]! : _classic[role]!;
  // The contour is a CONSTANT device-px width — it must never scale with the
  // square (design doc), or the fixed light side thins out and vanishes on the
  // light boards (Paper/Meadow/Blush). rendered_px = units × size/64, so invert.
  final contour = (0.75 * 64 / size).toStringAsFixed(3);
  final outlineW = (1.6 * 64 / size).toStringAsFixed(3);
  final attrs = outline
      ? 'fill="${_hex(light ? t.pieceHollowLight : t.pieceHollowDark)}" '
          'stroke="${_hex(fill)}" stroke-width="$outlineW" stroke-linejoin="round" stroke-linecap="round"'
      : 'fill="${_hex(fill)}" stroke="${_hex(line)}" stroke-width="$contour" stroke-linejoin="round"';

  final buf = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
      'width="$size" height="$size" viewBox="0 0 64 64">');
  for (final s in shapes) {
    buf.write(s.svg(attrs));
  }
  // Bishop mitre slit (Classic only).
  if (style != PieceStyle.minimal && role == Role.bishop) {
    final sc = outline ? _hex(fill) : _hex(line);
    buf.write('<path d="M34.6 19.6 29.6 26.4" stroke="$sc" stroke-width="${outline ? outlineW : contour}" '
        'stroke-linecap="round" fill="none"/>');
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
