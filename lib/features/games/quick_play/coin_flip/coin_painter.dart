import 'package:flutter/material.dart';

import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/type_scale.dart';
import 'coin_logic.dart';

/// The four coin styles. A style changes the disc's geometry only — the letter
/// and label logic is shared, and every style paints in live theme tokens, so
/// all four work in all eight palettes.
enum CoinStyle { classic, minimal, glyph, pixel }

CoinStyle coinStyleFromId(String id) => switch (id) {
      'minimal' => CoinStyle.minimal,
      'glyph' => CoinStyle.glyph,
      'pixel' => CoinStyle.pixel,
      _ => CoinStyle.classic,
    };

/// Draws one coin face. [squash] is the vertical scale of the flip beat: the
/// face swaps at the narrowest frame, so the coin never appears to rotate.
class CoinPainter extends CustomPainter {
  CoinPainter({
    required this.face,
    required this.style,
    required this.accent,
    required this.onAccent,
    required this.surface,
    required this.border,
    required this.squash,
  });

  final CoinFace face;
  final CoinStyle style;
  final Color accent;
  final Color onAccent;
  final Color surface;
  final Color border;
  final double squash;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(1, squash.clamp(0.02, 1.0));
    canvas.translate(-centre.dx, -centre.dy);

    final r = size.width / 2;
    // Tails takes the darker stop of the accent so the two faces are legible
    // apart without introducing a second hue.
    final fill = face == CoinFace.heads
        ? accent
        : Color.lerp(accent, const Color(0xFF000000), 0.28)!;

    switch (style) {
      case CoinStyle.classic:
        canvas.drawCircle(centre, r, Paint()..color = fill);
        canvas.drawCircle(
          centre,
          r * 0.82,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.035
            ..color = onAccent.withValues(alpha: 0.45),
        );
        _letter(canvas, size, onAccent, r * 0.62);
      case CoinStyle.minimal:
        canvas.drawCircle(
          centre,
          r * 0.94,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05
            ..color = border,
        );
        _letter(canvas, size, fill, r * 0.62);
      case CoinStyle.glyph:
        canvas.drawCircle(centre, r, Paint()..color = fill);
        if (face == CoinFace.heads) {
          canvas.drawCircle(centre, r * 0.36, Paint()..color = onAccent);
        } else {
          canvas.drawCircle(
            centre,
            r * 0.36,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.1
              ..color = onAccent,
          );
        }
      case CoinStyle.pixel:
        _pixelDisc(canvas, size, fill);
        _letter(canvas, size, onAccent, r * 0.55);
    }
    canvas.restore();
  }

  /// An 8×8 bitmap disc — the same circle, quantised.
  void _pixelDisc(Canvas canvas, Size size, Color fill) {
    const n = 8;
    final cell = size.width / n;
    final paint = Paint()..color = fill;
    const mid = (n - 1) / 2;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final dx = x - mid, dy = y - mid;
        if (dx * dx + dy * dy <= (mid + 0.35) * (mid + 0.35)) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5), paint);
        }
      }
    }
  }

  void _letter(Canvas canvas, Size size, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: face == CoinFace.heads ? 'H' : 'T',
        style: DallyType.displayLg.copyWith(
          fontSize: fontSize,
          height: 1,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(CoinPainter old) =>
      old.face != face ||
      old.style != style ||
      old.squash != squash ||
      old.accent != accent;
}

/// A small static coin for the style picker and the batch grid.
class CoinChip extends StatelessWidget {
  const CoinChip({
    super.key,
    required this.face,
    required this.style,
    this.size = 44,
    this.squash = 1,
  });

  final CoinFace face;
  final CoinStyle style;
  final double size;

  /// Vertical scale, 1 at rest. Every coin in a batch flips through the same
  /// squash the single coin does; only the timing is staggered.
  final double squash;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: CoinPainter(
          face: face,
          style: style,
          accent: t.accent,
          onAccent: t.onAccent,
          surface: t.surface,
          border: t.border,
          squash: squash,
        ),
      ),
    );
  }
}
