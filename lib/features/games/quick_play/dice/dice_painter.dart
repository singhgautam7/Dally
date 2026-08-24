import 'package:flutter/material.dart';

import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';

enum DiceStyle { classic, numeral, pixel, tally }

DiceStyle diceStyleFromId(String id) => switch (id) {
      'numeral' => DiceStyle.numeral,
      'pixel' => DiceStyle.pixel,
      'tally' => DiceStyle.tally,
      _ => DiceStyle.classic,
    };

/// One die face. Pip geometry is a single 3×3 grid with a per-face mask, so the
/// same mask drives every size and every style that uses pips.
class DiePainter extends CustomPainter {
  DiePainter({
    required this.value,
    required this.style,
    required this.ink,
    required this.accent,
    required this.onAccent,
    required this.border,
  });

  final int value;
  final DiceStyle style;
  final Color ink;
  final Color accent;
  final Color onAccent;
  final Color border;

  /// Which of the nine grid slots each face lights, row-major.
  static const Map<int, List<int>> pipMask = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * (style == DiceStyle.pixel ? 0.0 : 0.2));

    if (style == DiceStyle.numeral) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), Paint()..color = accent);
      _text('$value', canvas, size, onAccent, size.width * 0.5, DallyType.mono);
      return;
    }

    // Everything else is a hairline shell with the mark drawn inside it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = border,
    );

    switch (style) {
      case DiceStyle.classic:
        _pips(canvas, size, circle: true);
      case DiceStyle.pixel:
        _pips(canvas, size, circle: false);
      case DiceStyle.tally:
        _tally(canvas, size);
      case DiceStyle.numeral:
        break;
    }
  }

  void _pips(Canvas canvas, Size size, {required bool circle}) {
    final mask = pipMask[value] ?? const [];
    final cell = size.width / 3;
    final r = size.width * (circle ? 0.075 : 0.08);
    final paint = Paint()..color = accent;
    for (final slot in mask) {
      final cx = (slot % 3 + 0.5) * cell;
      final cy = (slot ~/ 3 + 0.5) * cell;
      if (circle) {
        canvas.drawCircle(Offset(cx, cy), r, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2), paint);
      }
    }
  }

  /// Stroke groups: four uprights and a diagonal for the fifth.
  void _tally(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    final top = size.height * 0.28, bottom = size.height * 0.72;
    final uprights = value >= 5 ? 4 : value;
    final span = size.width * 0.44;
    final left = size.width / 2 - span / 2;
    for (var i = 0; i < uprights; i++) {
      final x = left + (uprights == 1 ? span / 2 : span * i / (uprights - 1));
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
    if (value >= 5) {
      canvas.drawLine(Offset(left - 4, bottom), Offset(left + span + 4, top), paint);
    }
    if (value == 6) {
      canvas.drawLine(
        Offset(size.width * 0.78, top),
        Offset(size.width * 0.78, bottom),
        paint,
      );
    }
  }

  void _text(String s, Canvas canvas, Size size, Color color, double fontSize, String family) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: family,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(DiePainter old) =>
      old.value != value || old.style != style || old.accent != accent;
}

/// One die, sized by its parent. Wrapped in a [RepaintBoundary] so a single die
/// cycling faces doesn't dirty the rest of the grid.
class DieView extends StatelessWidget {
  const DieView({super.key, required this.value, required this.style});

  final int value;
  final DiceStyle style;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RepaintBoundary(
      child: CustomPaint(
        painter: DiePainter(
          value: value,
          style: style,
          ink: t.textPrimary,
          accent: t.accent,
          onAccent: t.onAccent,
          border: t.border,
        ),
      ),
    );
  }
}

/// Fixed-size die for the style picker.
class DieChip extends StatelessWidget {
  const DieChip({super.key, required this.value, required this.style, this.size = 38});
  final int value;
  final DiceStyle style;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: DieView(value: value, style: style),
      );
}

/// The dice grid: 1–2 in a row, 3–4 as 2×2, 5–6 as 3×2. Sized from `1fr` plus a
/// square aspect, so a 320px phone shrinks the dice, never the layout.
class DiceGrid extends StatelessWidget {
  const DiceGrid({super.key, required this.values, required this.style});

  final List<int> values;
  final DiceStyle style;

  @override
  Widget build(BuildContext context) {
    final columns = switch (values.length) {
      1 => 1,
      2 => 2,
      3 || 4 => 2,
      _ => 3,
    };
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: Insets.s3,
        crossAxisSpacing: Insets.s3,
        childAspectRatio: 1,
      ),
      itemCount: values.length,
      itemBuilder: (context, i) => DieView(value: values[i], style: style),
    );
  }
}
