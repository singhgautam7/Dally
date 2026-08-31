import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/type_scale.dart';
import '../theme/spacing.dart';

/// Icon + mono number pill used for in-game stats (mines left, timer, moves,
/// length). The surfaceAlt fill keeps it quiet against the board.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.iconColor,
    this.semanticLabel,
  });

  final IconData icon;
  final String value;
  final Color? iconColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: semanticLabel == null ? null : '$semanticLabel $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: Radii.pillBR,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor ?? t.textMuted),
            const SizedBox(width: 7),
            Text(value, style: DallyType.monoChip.copyWith(color: t.textPrimary)),
          ],
        ),
      ),
    );
  }
}
