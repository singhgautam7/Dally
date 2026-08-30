import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';

/// Where the die lives. "Per-seat" — the default — gives every seat marker its
/// own slot and lights only the current player's, so nobody reaches across the
/// phone. "Centre-bottom" keeps one place to look, under the board.
class LudoDicePositionRow extends ConsumerWidget {
  const LudoDicePositionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final follows =
        ref.watch(settingsControllerProvider.select((s) => s.ludoDieFollowsTurn));

    Widget chip(String label, bool value) {
      final on = follows == value;
      return GestureDetector(
        onTap: () {
          Haptics.selection(ref);
          ref.read(settingsControllerProvider.notifier).setLudoDieFollowsTurn(value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? t.accent : Colors.transparent,
            borderRadius: Radii.pillBR,
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
                Text('Dice position',
                    style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
                const SizedBox(height: 3),
                Text('Tap the die to roll it',
                    style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              ],
            ),
          ),
          chip('Per-seat', true),
          const Gap.h(6),
          chip('Centre', false),
        ],
      ),
    );
  }
}
