import 'package:dally/core/theme/palettes.dart';
import 'package:dally/core/widgets/game_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// The glyphs tint through a `colorFilter` rather than an `SvgTheme`, because
/// `flutter_svg` keys its picture cache on the theme: tinting that way made
/// every palette a separate cache entry and re-decoded all 31 glyphs on a theme
/// switch. This pins the mechanism, not just the colour.
void main() {
  testWidgets('a glyph tints through a colorFilter, not the cache key',
      (tester) async {
    await pumpGameScreen(
      tester,
      const Scaffold(body: Center(child: GameGlyph(asset: 'snake', size: 30))),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.colorFilter, isNotNull,
        reason: 'the tint must be a paint-time filter');

    // The harness installs the Ink palette.
    expect(
      svg.colorFilter,
      ColorFilter.mode(DallyPalettes.byId('ink').accent, BlendMode.srcIn),
      reason: 'and it must resolve to the active accent',
    );
  });

  testWidgets('an explicit colour overrides the accent', (tester) async {
    const override = Color(0xFF123456);
    await pumpGameScreen(
      tester,
      const Scaffold(
        body: Center(child: GameGlyph(asset: 'snake', size: 30, color: override)),
      ),
    );
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.colorFilter, const ColorFilter.mode(override, BlendMode.srcIn));
  });
}
