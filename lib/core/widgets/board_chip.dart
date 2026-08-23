import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/type_scale.dart';

/// A quiet in-game stat pill: a leading [icon] or text [label], then a mono
/// value. Used across boards for moves, timers, mines-left, length.
class BoardChip extends StatelessWidget {
  const BoardChip({
    super.key,
    required this.value,
    this.icon,
    this.label,
    this.valueColor,
    this.iconColor,
    this.semanticLabel,
  });

  final String value;
  final IconData? icon;
  final String? label;
  final Color? valueColor;
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
          color: t.surface,
          borderRadius: BorderRadius.circular(999),
          border: t.surfaceBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor ?? t.textMuted),
              const SizedBox(width: 7),
            ] else if (label != null) ...[
              Text(label!, style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
              const SizedBox(width: 7),
            ],
            Text(value,
                style: DallyType.monoChip.copyWith(color: valueColor ?? t.textPrimary)),
          ],
        ),
      ),
    );
  }
}
