import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/haptics.dart';
import '../../../../core/storage/settings.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';
import 'snake_painter.dart';

/// The preview handed to the shared [showStylePicker] — the existing snake and
/// food artwork, unchanged. The picker shell is now
/// `core/widgets/style_picker_sheet.dart`, shared with every other game.
Widget snakeStylePreview(BuildContext context, String styleId) {
  final t = context.tokens;
  return SizedBox(
    width: 62,
    height: 26,
    child: CustomPaint(
      painter: _StylePreviewPainter(
        style: snakeStyleFromId(styleId),
        snake: t.accent,
        food: t.danger,
      ),
    ),
  );
}

class _StylePreviewPainter extends CustomPainter {
  _StylePreviewPainter({required this.style, required this.snake, required this.food});
  final SnakeStyle style;
  final Color snake;
  final Color food;

  @override
  void paint(Canvas canvas, Size size) {
    final seg = size.height * 0.5;
    final cy = size.height / 2;
    final y = cy - seg / 2;
    final paint = Paint()..color = snake;

    if (style == SnakeStyle.ribbon) {
      // Continuous pill + diamond food.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, y, seg * 3.2, seg), Radius.circular(seg / 2)),
        paint,
      );
      final c = Offset(seg * 3.2 + seg * 0.9, cy), h = seg * 0.5;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - h)
          ..lineTo(c.dx + h, c.dy)
          ..lineTo(c.dx, c.dy + h)
          ..lineTo(c.dx - h, c.dy)
          ..close(),
        Paint()..color = food,
      );
      return;
    }

    final pixel = style == SnakeStyle.pixel;
    final gap = pixel ? 2.0 : 1.0;
    final bodyR = pixel ? 0.0 : seg * 0.12;
    final endR = pixel ? 0.0 : seg * 0.36;
    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(i * (seg + gap), y, seg, seg);
      final r = (i == 0 || i == 2) ? endR : bodyR;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), paint);
    }
    final fc = Offset(3 * (seg + gap) + seg * 0.5, cy);
    if (pixel) {
      canvas.drawRect(Rect.fromCenter(center: fc, width: seg, height: seg), Paint()..color = food);
    } else {
      canvas.drawCircle(fc, seg * 0.5, Paint()..color = food);
    }
  }

  @override
  bool shouldRepaint(_StylePreviewPainter old) => old.style != style;
}

/// On-screen controls chooser mirrored into the pause sheet.
class OnScreenControlsRow extends ConsumerWidget {
  const OnScreenControlsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final value = ref.watch(settingsControllerProvider.select((s) => s.onScreenControls));
    Widget chip(String label, OnScreenControls v) {
      final on = value == v;
      return GestureDetector(
        onTap: () {
          Haptics.selection(ref);
          ref.read(settingsControllerProvider.notifier).setOnScreenControls(v);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? t.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: on ? null : Border.all(color: t.border),
          ),
          child: Text(label,
              style: DallyType.body.copyWith(
                fontSize: 12,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? t.onAccent : t.textMuted,
              )),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('On-screen controls',
                    style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
                const SizedBox(height: 3),
                Text('Also in Settings → Gameplay',
                    style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              ],
            ),
          ),
          chip('Swipe only', OnScreenControls.swipeOnly),
          const Gap.h(6),
          chip('D-pad', OnScreenControls.dpad),
        ],
      ),
    );
  }
}
