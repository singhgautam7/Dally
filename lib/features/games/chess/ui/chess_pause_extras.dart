import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';
import 'chess_pieces.dart';

/// Piece style picker (Classic / Outline / Minimal / Letters) for the pause
/// sheet. Persists under the game id.
class PieceStyleRow extends ConsumerWidget {
  const PieceStyleRow({super.key, required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final current = ref.watch(settingsControllerProvider.select((s) => s.styleChoices[gameId])) ?? 'classic';
    const styles = [
      ('classic', 'Classic'),
      ('outline', 'Outline'),
      ('minimal', 'Minimal'),
      ('letters', 'Letters'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Piece style', style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
          const Gap(Insets.s3),
          Row(
            children: [
              for (final (id, label) in styles) ...[
                if (id != 'classic') const Gap.h(Insets.s2),
                Expanded(
                  child: _Card(
                    label: label,
                    style: pieceStyleFromId(id),
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

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.style,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final PieceStyle style;
  final bool selected;
  final DallyTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? t.accent : t.border, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 30,
              width: 30,
              child: PieceGlyph(
                piece: const Piece(color: Side.white, role: Role.knight),
                style: style,
                size: 30,
              ),
            ),
            const Gap(Insets.s2),
            Text(label,
                style: DallyType.body.copyWith(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? t.textPrimary : t.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}
