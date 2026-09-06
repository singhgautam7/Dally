import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';
import 'dally_tooltip.dart';

/// The back-chevron + title row shared by every pushed shell screen (Themes,
/// Settings, About, Stats). No app bar; matches the mockups' flat header.
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Back',
          child: DallyTooltip(
            message: 'Back',
            child: InkResponse(
              onTap: onBack ?? () => context.pop(),
              radius: 24,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.chevron_left_rounded, color: t.textMuted, size: 26),
              ),
            ),
          ),
        ),
        const Gap.h(Insets.s2),
        // Flexible, not fixed: a long screen title — a game's own name on its
        // stats page — must not push itself off a narrow phone or overflow at
        // a large text scale.
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DallyType.title.copyWith(fontSize: 21, color: t.textPrimary),
          ),
        ),
      ],
    );
  }
}
