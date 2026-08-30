import 'package:dally/core/theme/theme_controller.dart';
import 'package:dally/features/games/fifteen_puzzle/fifteen_config.dart';
import 'package:dally/features/games/fifteen_puzzle/ui/play_fifteen_screen.dart';
import 'package:dally/features/games/quick_play/coin_flip/coin_flip_module.dart';
import 'package:dally/features/games/quick_play/coin_flip/coin_painter.dart';
import 'package:dally/features/games/quick_play/coin_flip/play_coin_flip_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Reduce motion has two sources — the OS accessibility flag and Dally's own
/// Settings toggle — and the rule is that *either* one is enough. Five screens
/// used to read only the OS flag, so the in-app switch did nothing on them.
void main() {
  Future<ProviderContainer> reduceMotion(WidgetTester tester, Finder of) async {
    final container = ProviderScope.containerOf(tester.element(of));
    await container.read(settingsControllerProvider.notifier).setReduceMotion(true);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the in-app setting alone stops the coin flip animating',
      (tester) async {
    await pumpGameScreen(tester, PlayCoinFlipScreen(module: CoinFlipModule()));
    await reduceMotion(tester, find.byType(PlayCoinFlipScreen));

    await tester.tap(find.text('Flip'));
    await tester.pump();
    // Nothing squashes: the result is simply there. The OS flag is untouched,
    // so this is the app setting doing the work.
    expect(
      tester.widgetList<CoinChip>(find.byType(CoinChip)).every((c) => c.squash == 1),
      isTrue,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('the OS flag alone still stops it', (tester) async {
    await pumpGameScreen(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: PlayCoinFlipScreen(module: CoinFlipModule()),
      ),
    );
    await tester.tap(find.text('Flip'));
    await tester.pump();
    expect(
      tester.widgetList<CoinChip>(find.byType(CoinChip)).every((c) => c.squash == 1),
      isTrue,
    );
    await tester.pumpAndSettle();
  });


  testWidgets('a 15-puzzle tile jump-cuts instead of sliding', (tester) async {
    const config = FifteenConfig(size: 4);
    await pumpGameScreen(
        tester, const PlayFifteenScreen(moduleId: 'fifteen_puzzle', config: config));
    await reduceMotion(tester, find.byType(PlayFifteenScreen));

    final slides = tester.widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned));
    expect(slides, isNotEmpty);
    expect(slides.every((s) => s.duration == Duration.zero), isTrue,
        reason: 'the slide collapses to instant, it does not merely shorten');
  });
}
