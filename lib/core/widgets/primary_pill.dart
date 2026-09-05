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
/// Quick Play, Tiny Arcade, Undercover), so it is one widget rather than five copies
/// — the fifth of which had lost its semantics label.
/// The shared undo control: 34px, in the game chrome's top-right immediately
/// left of the overflow, at the same ghosted weight — so a player who learns it
/// in Solitaire finds it in Sudoku without looking.
///
/// Three states, and no fourth: available (icon in the text colour, hairline
/// ring), nothing to undo (the whole control dimmed, not tappable, **never
/// hidden**), and pressed (a brief accent tint). It never carries a number — a
/// count would make the cap read as a resource to spend, and disabled-when-empty
/// says the same thing with nothing to read.
///
/// A game that does not support undo passes no callback and the control is not
/// built at all: a missing control is quieter than a permanently dead one.
class UndoButton extends StatefulWidget {
  const UndoButton({super.key, required this.onTap, required this.enabled});

  final VoidCallback onTap;

  /// False when the stack is empty — and, on a two-seat board, while it is not
  /// your turn: the last move belongs to the other seat.
  final bool enabled;

  @override
  State<UndoButton> createState() => _UndoButtonState();
}

class _UndoButtonState extends State<UndoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tint = _pressed && widget.enabled ? t.accent : t.textPrimary;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Undo',
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.38,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.enabled
              ? () {
                  setState(() => _pressed = false);
                  widget.onTap();
                }
              : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _pressed && widget.enabled ? t.accent : t.border),
                ),
                child: Icon(Icons.undo_rounded, size: 17, color: tint),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
