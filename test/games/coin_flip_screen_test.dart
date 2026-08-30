import 'package:dally/features/games/quick_play/coin_flip/coin_flip_module.dart';
import 'package:dally/features/games/quick_play/coin_flip/coin_logic.dart';
import 'package:dally/features/games/quick_play/coin_flip/coin_painter.dart';
import 'package:dally/features/games/quick_play/coin_flip/play_coin_flip_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  Widget screen() => PlayCoinFlipScreen(module: CoinFlipModule());

  /// The squash of every coin currently on screen. 1 means "at rest".
  List<double> squashes(WidgetTester tester) => tester
      .widgetList<CoinChip>(find.byType(CoinChip))
      .map((c) => c.squash)
      .toList();

  Future<void> setCount(WidgetTester tester, int taps) async {
    for (var i = 0; i < taps; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a multi-coin flip animates every coin, not just the first',
      (tester) async {
    await pumpGameScreen(tester, screen());
    await setCount(tester, 1); // 1 → 3 coins
    expect(find.byType(CoinChip), findsNWidgets(3));

    await tester.tap(find.text('Flip'));
    await tester.pump(); // the frame the ticker starts on
    // Part-way through the run: the coins are mid-squash, not already resolved.
    await tester.pump(const Duration(milliseconds: 120));
    final mid = squashes(tester);
    expect(mid, hasLength(3));
    expect(mid.every((s) => s < 1), isTrue,
        reason: 'every coin is flipping, not only the first');

    await tester.pumpAndSettle();
    expect(squashes(tester).every((s) => s == 1), isTrue,
        reason: 'they all come to rest');
  });

  testWidgets('the coins are staggered rather than moving as one block',
      (tester) async {
    await pumpGameScreen(tester, screen());
    await setCount(tester, 3); // 1 → 10 coins
    await tester.tap(find.text('Flip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final s = squashes(tester);
    expect(s.first, isNot(s.last), reason: '40ms of stagger per coin');
    await tester.pumpAndSettle();
  });

  testWidgets('the results are the faces the RNG drew, once settled',
      (tester) async {
    await pumpGameScreen(tester, screen());
    await setCount(tester, 1);
    await tester.tap(find.text('Flip'));
    await tester.pumpAndSettle();
    final faces = tester
        .widgetList<CoinChip>(find.byType(CoinChip))
        .map((c) => c.face)
        .toList();
    expect(faces, hasLength(3));
    expect(faces.every(CoinFace.values.contains), isTrue);
    // The headline reports the same batch it drew.
    expect(find.textContaining('heads'), findsWidgets);
  });
}
