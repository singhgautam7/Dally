import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/type_scale.dart';

/// `‹ label ›` — steps through an ordered list of options. Shows a value and an
/// optional mono subtitle (e.g. `16 × 16 · 40 mines`). Chevrons disable at the
/// ends unless [wrap] is set.
class OptionStepper extends StatelessWidget {
  const OptionStepper({
    super.key,
    required this.value,
    required this.subtitle,
    required this.onPrev,
    required this.onNext,
    this.canPrev = true,
    this.canNext = true,
  });

  final String value;
  final String? subtitle;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool canPrev;
  final bool canNext;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Chevron(
            icon: Icons.chevron_left_rounded,
            color: canPrev ? t.textMuted : t.textFaint,
            onTap: canPrev ? onPrev : null,
            semanticLabel: 'Previous',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: DallyType.title.copyWith(fontSize: 19, color: t.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint),
                  ),
                ],
              ],
            ),
          ),
          _Chevron(
            icon: Icons.chevron_right_rounded,
            color: canNext ? t.textMuted : t.textFaint,
            onTap: canNext ? onNext : null,
            semanticLabel: 'Next',
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
