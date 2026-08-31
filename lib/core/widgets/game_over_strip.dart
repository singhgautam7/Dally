import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';
import 'primary_pill.dart';

/// The strip every game raises when it ends: a headline, one quiet line under
/// it, and one or two pills.
///
/// Nine games each had their own private copy of this widget, identical but for
/// the strings. It lives here so a game declares *what it wants to say* and
/// nothing about how the end of a game looks.
///
/// [titleColor] exists for the one case that isn't neutral — a Minesweeper loss
/// puts the headline in `danger`. Everything else takes the default.
class GameOverStrip extends StatelessWidget {
  const GameOverStrip({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.titleColor,
  }) : assert(
          (secondaryLabel == null) == (onSecondary == null),
          'a secondary pill needs both a label and a callback',
        );

  final String title;
  final String subtitle;

  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Omit for a single full-width pill (2048's dead end, Mafia's summary).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: DallyType.heading
                .copyWith(fontSize: 24, color: titleColor ?? t.textPrimary)),
        const SizedBox(height: 5),
        Text(subtitle, style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
        const Gap(Insets.s4),
        if (secondaryLabel == null)
          PrimaryPill(label: primaryLabel, onPressed: onPrimary)
        else
          Row(
            children: [
              Expanded(child: PrimaryPill(label: primaryLabel, onPressed: onPrimary)),
              const Gap.h(Insets.s2 + 2),
              Expanded(
                child: PrimaryPill.secondary(
                    label: secondaryLabel!, onPressed: onSecondary),
              ),
            ],
          ),
      ],
    );
  }
}
