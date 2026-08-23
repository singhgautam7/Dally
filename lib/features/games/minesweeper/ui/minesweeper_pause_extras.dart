import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/inline_stepper.dart';
import 'minesweeper_painter.dart';

const List<int> _longPressSteps = [200, 300, 400, 500, 600];

/// Flag & mine style picker for the pause sheet (Classic / Pennant+dot /
/// Pin+diamond).
class MineStyleRow extends ConsumerWidget {
  const MineStyleRow({super.key, required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final current = ref.watch(settingsControllerProvider.select((s) => s.styleChoices[gameId])) ?? 'classic';
    const styles = [('classic', 'Classic'), ('pennant', 'Pennant'), ('pin', 'Pin')];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Flag & mine style', style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
          const Gap(Insets.s3),
          Row(
            children: [
              for (final (id, label) in styles) ...[
                if (id != 'classic') const Gap.h(Insets.s2 + 2),
                Expanded(
                  child: _StyleCard(
                    label: label,
                    style: mineStyleFromId(id),
                    selected: current == id,
                    tokens: t,
                    onTap: () {
                      Haptics.selection(ref);
                      ref.read(settingsControllerProvider.notifier).setStyleChoice(gameId, id);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.label,
    required this.style,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final MineStyle style;
  final bool selected;
  final DallyTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? t.accent : t.border, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 28,
              width: 56,
              child: CustomPaint(painter: _GlyphPreview(style: style, flag: t.accent, mine: t.danger)),
            ),
            const Gap(Insets.s2 + 2),
            Text(label,
                style: DallyType.body.copyWith(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? t.textPrimary : t.textMuted,
                )),
          ],
        ),
      ),
    );
  }
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
