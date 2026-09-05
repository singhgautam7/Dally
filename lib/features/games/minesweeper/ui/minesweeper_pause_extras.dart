import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/inline_stepper.dart';
import 'minesweeper_painter.dart';

const List<int> _longPressSteps = [200, 300, 400, 500, 600];

/// The preview handed to the shared [showStylePicker] — the existing flag and
/// mine artwork, unchanged. The picker shell is now
/// `core/widgets/style_picker_sheet.dart`, shared with every other game.
Widget mineStylePreview(BuildContext context, String groupId, String styleId) {
  final t = context.tokens;
  return SizedBox(
    width: 56,
    height: 28,
    child: CustomPaint(
      painter: _GlyphPreview(
        style: mineStyleFromId(styleId),
        flag: t.danger,
        mine: t.textPrimary,
      ),
    ),
  );
}

class _GlyphPreview extends CustomPainter {
  _GlyphPreview({required this.style, required this.flag, required this.mine});
  final MineStyle style;
  final Color flag;
  final Color mine;

  @override
  void paint(Canvas canvas, Size size) {
    final flagRect = Rect.fromLTWH(0, 0, size.width / 2, size.height);
    final mineRect = Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);
    final painter = MinesweeperPainterGlyphs(style);
    painter.drawFlag(canvas, flagRect, flag);
    painter.drawMine(canvas, mineRect, mine);
  }

  @override
  bool shouldRepaint(_GlyphPreview old) => old.style != style;
}

/// Long-press-to-flag duration control — Minesweeper-specific, lives here rather
/// than in global Settings.
class LongPressRow extends ConsumerWidget {
  const LongPressRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final ms = ref.watch(settingsControllerProvider.select((s) => s.longPressMs));
    final idx = _longPressSteps.indexOf(ms);
    final base = idx == -1 ? _longPressSteps.indexOf(400) : idx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Long-press to flag', style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
                const SizedBox(height: 3),
                Text('How long is a long press', style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              ],
            ),
          ),
          InlineStepper(
            value: '${ms}ms',
            width: 62,
            onPrev: base > 0
                ? () => ref.read(settingsControllerProvider.notifier).setLongPressMs(_longPressSteps[base - 1])
                : null,
            onNext: base < _longPressSteps.length - 1
                ? () => ref.read(settingsControllerProvider.notifier).setLongPressMs(_longPressSteps[base + 1])
                : null,
          ),
        ],
      ),
    );
  }
}
