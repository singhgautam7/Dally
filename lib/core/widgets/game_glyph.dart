import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/dally_tokens.dart';

/// Renders a game's single-colour glyph SVG in the active accent (or an
/// override). Assets live in `assets/glyphs/<id>.svg`.
///
/// The tint is applied as a **`colorFilter`, not an `SvgTheme`**, and that is a
/// performance decision rather than a style one. `flutter_svg` keys its picture
/// cache on `SvgCacheKey(theme, colorMapper, keyName)` — so passing the accent
/// through `SvgTheme(currentColor:)` makes every palette a *different cache
/// entry*, and switching theme re-parses and re-rasterises every glyph on
/// screen. A `colorFilter` is applied at paint time and is not part of the key,
/// so each glyph is decoded once for the life of the process no matter how
/// often the palette changes.
///
/// It is equivalent here because these glyphs are single-colour by
/// construction: every one paints `currentColor` and nothing else, so
/// re-tinting the whole picture and substituting `currentColor` produce the
/// same pixels.
class GameGlyph extends StatelessWidget {
  const GameGlyph({
    super.key,
    required this.asset,
    this.size = 30,
    this.color,
  });

  /// The glyph asset basename without extension, e.g. `minesweeper`.
  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.tokens.accent;
    return SvgPicture.asset(
      'assets/glyphs/$asset.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
    );
  }
}
