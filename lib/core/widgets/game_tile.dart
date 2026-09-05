import 'package:flutter/material.dart';

import '../game/game_category.dart';
import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';
import 'game_glyph.dart';

/// A home-grid tile: accent glyph, optional pass-and-play badge, title, vibe
/// subtitle and an optional mono best-score line.
class GameTile extends StatelessWidget {
  const GameTile({
    super.key,
    required this.title,
    required this.glyphAsset,
    required this.vibe,
    required this.seats,
    required this.onTap,
    this.best,
  });

  final String title;
  final String glyphAsset;
  final String vibe;
  /// How many bodies the game needs, from the module's own metadata. Null for
  /// a solo game, which carries no badge at all.
  final PlayerCount? seats;
  final String? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '$title. $vibe.${best != null ? ' Best $best.' : ''}',
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.containerBR,
          side: BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Insets.s3 + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GameGlyph(asset: glyphAsset, size: 30),
                    const Spacer(),
                    if (seats != null) _SeatsBadge(seats: seats!, tokens: t),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DallyType.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.16,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  vibe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint),
                ),
                if (best != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    best!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pass-and-play badge. It reads the module's declared [PlayerCount]
/// rather than a literal: "2P" was hardcoded, which was already a half-truth
/// for the 2–4 seat board games and became a flat lie when Dots & Boxes gained
/// four seats and Undercover took 4–20.
class _SeatsBadge extends StatelessWidget {
  const _SeatsBadge({required this.seats, required this.tokens});
  final PlayerCount seats;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.s2, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: Radii.pillBR,
      ),
      child: Text(
        switch (seats) {
          PlayerCount.group => '4+',
          PlayerCount.two => '2P',
          PlayerCount.solo => '1P',
        },
        style: DallyType.monoSm.copyWith(
          fontSize: 9,
          letterSpacing: 0.9,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}
