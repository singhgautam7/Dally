import 'package:dally/features/games/fifteen_puzzle/fifteen_config.dart';
import 'package:dally/features/games/fifteen_puzzle/ui/play_fifteen_screen.dart';
import 'package:dally/features/games/game_2048/game_2048_config.dart';
import 'package:dally/features/games/game_2048/ui/play_2048_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Seeded randomness is only real if the *screen* passes it down.
///
/// Seven game cores take `Random? rng` and silently fall back to a bare
/// `Random()` when the caller forgets — which looks correct and is not. Sudoku,
/// Snake, Chess, 15-puzzle, Memory, Minesweeper, 2048 and Mafia all forgot, so
/// `pumpGameScreen`'s seeded override had no effect on any of them and every
/// screen test that "passed deterministically" was passing by luck.
///
/// A generated board is deterministic per seed, or the injection is decorative.
void main() {
  /// Every number rendered on the board, in tree order.
  List<String> numbers(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((d) => int.tryParse(d.replaceAll(',', '')) != null)
      .toList();

  Future<List<String>> boardWith(
    WidgetTester tester,
    Widget screen,
    int seed,
  ) async {
    await pumpGameScreen(tester, screen, seed: seed);
    await tester.pump();
    final out = numbers(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    return out;
  }

  testWidgets('a 15-puzzle shuffle is reproducible from its seed',
      (tester) async {
    Widget screen() => const PlayFifteenScreen(
        moduleId: 'fifteen_puzzle', config: FifteenConfig(size: 4));

    final a = await boardWith(tester, screen(), 7);
    final b = await boardWith(tester, screen(), 7);
    final c = await boardWith(tester, screen(), 99);

    expect(a, isNotEmpty);
    expect(a, b, reason: 'the same seed must deal the same board');
    expect(a, isNot(c), reason: 'a different seed must deal a different one');
  });

  testWidgets('a 2048 opening is reproducible from its seed', (tester) async {
    Widget screen() => const Play2048Screen(
        moduleId: 'game_2048', config: Game2048Config(size: 4));

    final a = await boardWith(tester, screen(), 7);
    final b = await boardWith(tester, screen(), 7);

    expect(a, isNotEmpty);
    expect(a, b, reason: 'the same seed must spawn the same tiles');
  });
}
