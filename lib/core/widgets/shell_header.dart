import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

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
        const Gap.h(Insets.s2),
        Text(
          title,
          style: DallyType.title.copyWith(fontSize: 21, color: t.textPrimary),
        ),
      ],
    );
  }
}
