import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/dally_tokens.dart';

/// Renders a game's single-colour glyph SVG, resolving `currentColor` to the
/// active accent (or an override). Assets live in `assets/glyphs/<id>.svg`.
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
      theme: SvgTheme(currentColor: resolved),
    );
  }
}
