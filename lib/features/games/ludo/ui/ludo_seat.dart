import 'package:flutter/material.dart';

import '../../../../core/game/player_identity.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/player_chip.dart';

/// One player's corner of the screen: identity glyph, name, tokens home, and
/// their own dice slot.
///
/// Four of these replace the old row of name pills. Each sits at the screen
/// corner matching that player's yard, so the turn is legible from where that
/// player is sitting and their die is under their own thumb.
///
/// Layout is one group — glyph and text together, slot last — so the four read
/// identically however they are mirrored across the screen.
class LudoSeat extends StatelessWidget {
  const LudoSeat({
    super.key,
    required this.identity,
    required this.name,
    required this.home,
    required this.active,
    this.total = 4,
    this.dieSlot,
  });

  final PlayerIdentity identity;

  /// Already resolved — a blank name falls back to the colour word upstream.
  final String name;

  final int home;
  final int total;

  /// True for the player on turn: identity tint behind, identity ring around.
  final bool active;

  /// The seat's die. Omitted entirely in centre-bottom dice mode, where the
  /// seat keeps its identity and progress but has nothing to tap.
  final Widget? dieSlot;

  /// Below this width the progress folds into the name row and the seat stays
  /// one line. The die never shrinks — it is the only tap target here.
  static const double compactWidth = 340;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final compact = MediaQuery.sizeOf(context).width < compactWidth;
    final progress = '$home/$total';

    return AnimatedContainer(
      duration: MotionPreset.appear.duration,
      curve: MotionPreset.appear.curve,
      padding: const EdgeInsets.fromLTRB(Insets.s2 + 2, Insets.s2, Insets.s2, Insets.s2),
      decoration: BoxDecoration(
        color: active ? identity.color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: Radii.containerBR,
        border: Border.all(color: active ? identity.color : t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerMark(identity: identity, size: 13, dim: !active),
          const Gap.h(Insets.s2),
          Flexible(
            child: compact
                // The name gives way, the count never does: which seat this is
                // was already said by the glyph and the colour.
                // Scaled down rather than clipped when a seat is really tight:
                // the die keeps its 42px target, so the text is what gives.
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          style: DallyType.body.copyWith(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? t.textPrimary : t.textMuted,
                          ),
                        ),
                        Text(
                          ' · $progress',
                          style: DallyType.monoChip.copyWith(
                            fontSize: 11,
                            color: active ? t.textMuted : t.textFaint,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DallyType.body.copyWith(
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? t.textPrimary : t.textMuted,
                        ),
                      ),
                      Text(
                        progress,
                        style: DallyType.monoChip.copyWith(
                          fontSize: 11,
                          color: active ? t.textMuted : t.textFaint,
                        ),
                      ),
                    ],
                  ),
          ),
          if (dieSlot != null) ...[
            const Gap.h(Insets.s2),
            dieSlot!,
          ],
        ],
      ),
    );
  }
}

/// Two seats facing each other across the width of the screen — the row above
/// the board, or the row below it. A missing seat leaves its corner empty
/// rather than re-seating anyone, which is what keeps a three-player game
/// reading the same as a four-player one.
class LudoSeatRow extends StatelessWidget {
  const LudoSeatRow({super.key, required this.left, required this.right});

  final Widget? left;
  final Widget? right;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(child: Align(alignment: Alignment.centerLeft, child: left)),
          const Gap.h(Insets.s2),
          Flexible(child: Align(alignment: Alignment.centerRight, child: right)),
        ],
      );
}
