import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// A single filter chip. Selected = accent fill with onAccent text and a small
/// ✕ to clear; unselected = hairline outline with muted text; disabled (no
/// matching games) dims to faint.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final child = Container(
      padding: EdgeInsets.only(
        left: Insets.s3 + (selected ? 0 : 2),
        right: selected ? Insets.s3 : Insets.s3 + 2,
        top: 7,
        bottom: 7,
      ),
      decoration: BoxDecoration(
        color: selected ? t.accent : Colors.transparent,
        borderRadius: Radii.pillBR,
        border: selected ? null : Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: DallyType.body.copyWith(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? t.onAccent
                  : (enabled ? t.textMuted : t.textFaint),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 7),
            Icon(Icons.close_rounded, size: 12, color: t.onAccent),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.5,
        child: GestureDetector(onTap: enabled ? onTap : null, child: child),
      ),
    );
  }
}
