import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// A row of equal-width pill options; the selected one fills with accent, the
/// rest are hairline outlines. Used for small enumerated choices (board size).
class SegmentedSelector<T> extends StatelessWidget {
  const SegmentedSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const Gap.h(Insets.s2),
          Expanded(
            child: _Segment(
              label: labelOf(options[i]),
              selected: options[i] == selected,
              tokens: t,
              onTap: () => onSelect(options[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final DallyTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? t.accent : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.pillBR,
          side: selected ? BorderSide.none : BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? t.onAccent : t.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
