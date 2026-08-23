import 'package:flutter/material.dart';

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
    required this.passAndPlay,
    required this.onTap,
    this.best,
  });

  final String title;
  final String glyphAsset;
  final String vibe;
  final bool passAndPlay;
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
                    if (passAndPlay) _PassBadge(tokens: t),
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

class _PassBadge extends StatelessWidget {
  const _PassBadge({required this.tokens});
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
        '2P',
        style: DallyType.monoSm.copyWith(
          fontSize: 9,
          letterSpacing: 0.9,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}
