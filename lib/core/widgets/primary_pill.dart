import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// The button. Start, Continue, Again, Resume, Leave game — all of them.
///
/// Three fills, and no fourth: [PrimaryPill] is accent with onAccent ink,
/// [PrimaryPill.secondary] is a hairline outline with primary text, and
/// [PrimaryPill.danger] is the danger fill, for the one action in the app that
/// throws a game away. Full-width by default.
class PrimaryPill extends StatelessWidget {
  const PrimaryPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.enabled = true,
  }) : _fill = _PillFill.primary;

  const PrimaryPill.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.enabled = true,
  }) : _fill = _PillFill.secondary;

  const PrimaryPill.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.enabled = true,
  }) : _fill = _PillFill.danger;

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  /// A disabled pill dims to 40% and stops taking taps, rather than vanishing —
  /// the player can still read what they are one step away from.
  final bool enabled;

  final _PillFill _fill;

  bool get _isPrimary => _fill != _PillFill.secondary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final child = Material(
      color: switch (_fill) {
        _PillFill.primary => t.accent,
        _PillFill.danger => t.danger,
        _PillFill.secondary => Colors.transparent,
      },
      shape: RoundedRectangleBorder(
        borderRadius: Radii.pillBR,
        side: _isPrimary ? BorderSide.none : BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: Insets.s5),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: DallyType.bodyStrong.copyWith(
              fontWeight: _isPrimary ? FontWeight.w600 : FontWeight.w500,
              color: _isPrimary ? t.onAccent : t.textPrimary,
            ),
          ),
        ),
      ),
    );
    Widget pill = Semantics(button: true, enabled: enabled, label: label, child: child);
    if (!enabled) pill = Opacity(opacity: 0.4, child: pill);
    return expand ? SizedBox(width: double.infinity, child: pill) : pill;
  }
}

enum _PillFill { primary, secondary, danger }

/// The three-dot button that raises a game's pause sheet.
///
/// It sits in the same corner of every game shell (`GameScaffold`, Mental Math,
/// Quick Play, Tiny Arcade, Mafia), so it is one widget rather than five copies
/// — the fifth of which had lost its semantics label.
class OverflowButton extends StatelessWidget {
  const OverflowButton({super.key, required this.onTap, this.semanticLabel = 'More'});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.more_vert_rounded,
                color: context.tokens.textFaint, size: 20),
          ),
        ),
      );
}
