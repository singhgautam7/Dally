import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';
import 'primary_pill.dart';
import 'dally_sheet.dart';

/// The one empty/error shape: a 44px hairline glyph, a title, one line, and at
/// most one action.
///
/// Empty states are **neutral** — the glyph takes `border`. Errors take
/// `danger`, and only on the glyph and the failing control, never on body text
/// or backgrounds.
class DallyEmptyState extends StatelessWidget {
  const DallyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        // Shifted up so it doesn't sit under the thumb.
        padding: const EdgeInsets.only(bottom: 60, left: Insets.s5, right: Insets.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: Radii.cellBR,
                border: Border.all(color: isError ? t.danger : t.border, width: 1.5),
              ),
              child: Icon(icon, size: 20, color: isError ? t.danger : t.textFaint),
            ),
            const Gap(Insets.s4),
            Text(title,
                textAlign: TextAlign.center,
                style: DallyType.bodyStrong.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: t.textPrimary)),
            const Gap(Insets.s2),
            Text(message,
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 14, height: 1.55, color: t.textMuted)),
            if (actionLabel != null && onAction != null) ...[
              const Gap(Insets.s5),
              PrimaryPill(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// A recoverable failure, as a bottom sheet over whatever the player was doing
/// — never a full screen, and never silently overwriting their data.
///
/// [onRetry] is the primary action; [safeLabel]/[onSafe] is the way out that
/// leaves everything alone; [destructiveLabel] is a quiet text link, used only
/// where discarding is genuinely the player's choice.
Future<void> showRecoverableError(
  BuildContext context, {
  required String title,
  required String message,
  String retryLabel = 'Try again',
  VoidCallback? onRetry,
  String? safeLabel,
  VoidCallback? onSafe,
  String? destructiveLabel,
  VoidCallback? onDestructive,
}) {
  return showDallySheet<void>(
    context,
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 20, color: t.danger),
                  const Gap.h(Insets.s2 + 2),
                  Expanded(
                    child: Text(title, style: DallyType.title.copyWith(color: t.textPrimary)),
                  ),
                ],
              ),
              const Gap(Insets.s2 + 2),
              Text(message,
                  style: DallyType.body.copyWith(fontSize: 13, height: 1.55, color: t.textMuted)),
              const Gap(Insets.s5),
              if (onRetry != null) ...[
                PrimaryPill(
                  label: retryLabel,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onRetry();
                  },
                ),
                const Gap(Insets.s2 + 2),
              ],
              if (safeLabel != null && onSafe != null)
                PrimaryPill.secondary(
                  label: safeLabel,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onSafe();
                  },
                ),
              if (destructiveLabel != null && onDestructive != null) ...[
                const Gap(Insets.s4),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onDestructive();
                    },
                    child: Text(destructiveLabel,
                        style: DallyType.body.copyWith(fontSize: 13, color: t.danger)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Inline setup validation: a danger hairline on the offending row plus one
/// line under it. Replaces the old dialog-on-submit.
class InlineValidation extends StatelessWidget {
  const InlineValidation({super.key, required this.message, required this.child, this.invalid = true});

  final String message;
  final Widget child;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: Radii.containerBR,
            border: Border.all(color: invalid ? t.danger : Colors.transparent),
          ),
          child: child,
        ),
        if (invalid) ...[
          const Gap(Insets.s2),
          Text(message, style: DallyType.body.copyWith(fontSize: 12, color: t.danger)),
        ],
      ],
    );
  }
}
