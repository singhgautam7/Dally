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

/// The round control in a game's top-right chrome: a 40px tap target holding a
/// 34px hairline circle with one icon in it.
///
/// Undo and the overflow are the two of them, and they are one widget because
/// they sit side by side — two different shapes in the same corner reads as an
/// accident rather than a pair. Both share the press behaviour too: a brief
/// accent tint on the ring and the icon, then straight back.
class ChromeButton extends StatefulWidget {
  const ChromeButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.enabled = true,
    this.iconSize = 17,
    this.muted = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  /// Shown on a long press. Defaults to [semanticLabel], so the word a screen
  /// reader announces and the word a sighted player uncovers are the same one —
  /// an icon-only control should not have two names.
  final String? tooltip;

  /// False dims the whole control and stops it taking taps. It is never
  /// hidden — a missing control moves; a dim one just says "not now".
  final bool enabled;

  final double iconSize;

  /// Draws the icon in [DallyTokens.textMuted] rather than the text colour.
  /// The overflow is quieter than undo: it is always available, so it does not
  /// need to advertise itself.
  final bool muted;

  @override
  State<ChromeButton> createState() => _ChromeButtonState();
}

class _ChromeButtonState extends State<ChromeButton> {
  bool _pressed = false;

  bool get _active => _pressed && widget.enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: Tooltip(
        message: widget.tooltip ?? widget.semanticLabel,
        // The Semantics above already names the control; letting the tooltip
        // add its own would announce it twice.
        excludeFromSemantics: true,
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: Radii.cellBR,
          border: Border.all(color: t.border),
        ),
        textStyle: DallyType.body.copyWith(fontSize: 12, color: t.textPrimary),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.38,
          // The press tint rides on a raw [Listener] rather than the gesture
          // detector's `onTapDown`. With the tooltip's long-press recogniser in
          // the arena, `onTapDown` is held back until the arena resolves — which
          // is pointer-up — so the tint arrived after the press had ended.
          // Pointer events are not arena-gated, so this lands on contact.
          child: Listener(
            onPointerDown:
                widget.enabled ? (_) => setState(() => _pressed = true) : null,
            onPointerUp:
                widget.enabled ? (_) => setState(() => _pressed = false) : null,
            onPointerCancel:
                widget.enabled ? (_) => setState(() => _pressed = false) : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? widget.onTap : null,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _active ? t.accent : t.border),
                    ),
                    child: Icon(
                      widget.icon,
                      size: widget.iconSize,
                      color: _active
                          ? t.accent
                          : (widget.muted ? t.textMuted : t.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shared undo control: in the game chrome's top-right, immediately left of
/// the overflow — so a player who learns it in Solitaire finds it in Sudoku
/// without looking.
///
/// Three states, and no fourth: available (icon in the text colour, hairline
/// ring), nothing to undo (the whole control dimmed, not tappable, **never
/// hidden**), and pressed (a brief accent tint). It never carries a number — a
/// count would make the cap read as a resource to spend, and disabled-when-empty
/// says the same thing with nothing to read.
///
/// A game that does not support undo passes no callback and the control is not
/// built at all: a missing control is quieter than a permanently dead one.
class UndoButton extends StatelessWidget {
  const UndoButton({super.key, required this.onTap, required this.enabled});

  final VoidCallback onTap;

  /// False when the stack is empty — and, on a two-seat board, while it is not
  /// your turn: the last move belongs to the other seat.
  final bool enabled;

  @override
  Widget build(BuildContext context) => ChromeButton(
        icon: Icons.undo_rounded,
        onTap: onTap,
        enabled: enabled,
        semanticLabel: 'Undo',
        // A dimmed control says "not now" but not why; the long press does.
        tooltip: enabled ? 'Undo' : 'Undo: disabled',
      );
}

/// The three-dot button that raises a game's pause sheet.
///
/// It sits in the same corner of every game shell (`GameScaffold`, Mental Math,
/// Quick Play, Tiny Arcade, Undercover), so it is one widget rather than five
/// copies — the fifth of which had lost its semantics label.
class OverflowButton extends StatelessWidget {
  /// Every shell opens the same `showPauseSheet`, so they all call it the same
  /// thing. It used to default to "More", which left four of the five shells
  /// naming the button differently from the sixth.
  const OverflowButton({super.key, required this.onTap, this.semanticLabel = 'Pause'});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => ChromeButton(
        icon: Icons.more_vert_rounded,
        onTap: onTap,
        semanticLabel: semanticLabel,
        iconSize: 18,
        muted: true,
      );
}
