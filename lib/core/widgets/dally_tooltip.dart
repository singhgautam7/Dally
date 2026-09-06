import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// The one tooltip in the app: a surface chip with a hairline, holding the same
/// word a screen reader announces.
///
/// It exists because an **icon-only control has to be able to say its own
/// name**. Undo and the overflow had one; the four on Home did not, so the
/// only way to learn what the tune icon did was to press it.
///
/// Wrap the control, not the icon: the long-press target should be the whole
/// tap target. The wrapper takes the label out of the semantics tree
/// ([excludeFromSemantics]) on the assumption that the caller already named the
/// control — letting the tooltip add its own would announce it twice.
class DallyTooltip extends StatelessWidget {
  const DallyTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: Radii.cellBR,
        border: Border.all(color: t.border),
      ),
      textStyle: DallyType.body.copyWith(fontSize: 12, color: t.textPrimary),
      child: child,
    );
  }
}
