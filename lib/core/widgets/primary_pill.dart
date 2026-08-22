import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// The Start / Continue / Again button. Primary = accent fill with onAccent
/// ink; secondary = hairline outline with primary text. Full-width by default.
class PrimaryPill extends StatelessWidget {
  const PrimaryPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.expand = true,
  });

  const PrimaryPill.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  }) : primary = false;

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final child = Material(
      color: primary ? t.accent : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.pillBR,
        side: primary ? BorderSide.none : BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: Insets.s5),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: DallyType.bodyStrong.copyWith(
              fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
              color: primary ? t.onAccent : t.textPrimary,
            ),
          ),
        ),
      ),
    );
    final semantic = Semantics(button: true, label: label, child: child);
    return expand ? SizedBox(width: double.infinity, child: semantic) : semantic;
  }
}
