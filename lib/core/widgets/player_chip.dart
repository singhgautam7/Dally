import 'package:flutter/material.dart';

import '../game/player_identity.dart';
import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// The seat's mark on its own — shape in identity colour. Used in turn
/// indicators, scoreboards, legends and setup previews.
class PlayerMark extends StatelessWidget {
  const PlayerMark({super.key, required this.identity, this.size = 12, this.dim = false});

  final PlayerIdentity identity;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
            painter: _MarkPainter(identity, dim, lightMode: !context.tokens.isDark)),
      );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.identity, this.dim, {required this.lightMode});
  final PlayerIdentity identity;
  final bool dim;

  /// The identity hairline is mandatory in Light — see [identityOutline].
  final bool lightMode;

  @override
  void paint(Canvas canvas, Size size) => paintPlayerToken(
        canvas,
        identity,
        size.center(Offset.zero),
        size.shortestSide / 2,
        opacity: dim ? 0.35 : 1,
        lightMode: lightMode,
      );

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.identity.index != identity.index ||
      old.dim != dim ||
      old.lightMode != lightMode;
}

/// One seat, stacked: mark, name and an optional value beneath. The unit
/// [PlayerStrip] is built from, and the same badge Frog Hop parks in its side
/// gutters — so a seat looks identical wherever it is shown.
class PlayerBadge extends StatelessWidget {
  const PlayerBadge({
    super.key,
    required this.identity,
    required this.name,
    required this.active,
    this.value,
  });

  final PlayerIdentity identity;
  final String name;
  final bool active;

  /// Optional mono line under the name (score, tokens home).
  final String? value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PlayerMark(identity: identity, size: 14, dim: !active),
        const Gap(Insets.s1),
        Text(
          name,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: DallyType.body.copyWith(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? t.textPrimary : t.textMuted,
          ),
        ),
        if (value != null)
          Text(value!,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: DallyType.monoChip.copyWith(fontSize: 15, color: t.textPrimary)),
      ],
    );
  }
}

/// The shared turn/score strip for seat-based games: every player's mark, name
/// and (optional) trailing value, with the active seat brought forward.
class PlayerStrip extends StatelessWidget {
  const PlayerStrip({
    super.key,
    required this.identities,
    required this.names,
    required this.activeIndex,
    this.valueOf,
  });

  final List<PlayerIdentity> identities;
  final List<String> names;

  /// -1 when the game is over and nobody is on turn.
  final int activeIndex;

  /// Optional trailing mono value per seat (score, tokens home).
  final String Function(int index)? valueOf;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < identities.length; i++) ...[
          if (i > 0) const Gap.h(Insets.s3),
          Expanded(
            child: PlayerBadge(
              identity: identities[i],
              name: names[i],
              active: activeIndex == i,
              value: valueOf?.call(i),
            ),
          ),
        ],
      ],
    );
  }
}

/// The style-picker preview shared by Ludo and Snakes & Ladders: the four seat
/// tokens drawn in the style being previewed, at board size.
class TokenStylePreview extends StatelessWidget {
  const TokenStylePreview({super.key, required this.styleId, this.seats = 4});

  final String styleId;
  final int seats;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 112,
        height: 34,
        child: CustomPaint(
          painter: _TokenStylePainter(
            style: tokenStyleFromId(styleId),
            identities: identitiesFor(seats),
            knockout: context.tokens.surface,
            lightMode: !context.tokens.isDark,
          ),
        ),
      );
}

class _TokenStylePainter extends CustomPainter {
  const _TokenStylePainter({
    required this.style,
    required this.identities,
    required this.knockout,
    required this.lightMode,
  });

  final PlayerTokenStyle style;
  final List<PlayerIdentity> identities;
  final Color knockout;
  final bool lightMode;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / identities.length;
    final radius = size.height * 0.34;
    for (var i = 0; i < identities.length; i++) {
      paintPlayerToken(
        canvas,
        identities[i],
        Offset(step * (i + 0.5), size.height / 2),
        radius,
        style: style,
        knockout: knockout,
        lightMode: lightMode,
      );
    }
  }

  @override
  bool shouldRepaint(_TokenStylePainter old) =>
      old.style != style || old.knockout != knockout || old.lightMode != lightMode;
}
