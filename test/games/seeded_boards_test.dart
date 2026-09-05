import 'package:dally/features/games/fifteen_puzzle/fifteen_config.dart';
import 'package:dally/features/games/fifteen_puzzle/ui/play_fifteen_screen.dart';
import 'package:dally/features/games/game_2048/game_2048_config.dart';
import 'package:dally/features/games/game_2048/ui/play_2048_screen.dart';
import 'package:dally/core/widgets/primary_pill.dart';
import 'package:dally/features/games/undercover/logic/word_pair.dart';
import 'package:dally/features/games/undercover/ui/play_undercover_screen.dart';
import 'package:dally/features/games/undercover/undercover_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Seeded randomness is only real if the *screen* passes it down.
///
/// Seven game cores take `Random? rng` and silently fall back to a bare
/// `Random()` when the caller forgets — which looks correct and is not. Sudoku,
/// Snake, Chess, 15-puzzle, Memory, Minesweeper, 2048 and the party game all
/// forgot, so
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

  testWidgets('an Undercover deal is reproducible from its seed', (tester) async {
    // Roles, the word pair and the speaking order all come from the shared RNG,
    // and the screen is where a seed most easily goes missing.
    Future<String> firstCard(int seed) async {
      await pumpGameScreen(
        tester,
        const PlayUndercoverScreen(
          moduleId: 'undercover',
          config: UndercoverConfig(
            names: ['Ravi', 'Ana', 'Priya', 'Noor', 'Sam'],
            undercover: 1,
            mrWhite: false,
            difficulty: WordDifficulty.normal,
            voting: UndercoverVoting.open,
          ),
        ),
        seed: seed,
      );
      await tester.pump();
      // Walk the first player through to their card.
      await tester.tap(find.byType(PrimaryPill).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tap the card to reveal'));
      await tester.pumpAndSettle();
      // Everything on the revealed card: the dealt name, the position in the
      // queue and the word itself. Scraping one string would be guessing which
      // one is the word; the whole screen is unambiguous.
      final screen = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((d) => d.isNotEmpty)
          .join('|');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      return screen;
    }

    final a = await firstCard(7);
    final b = await firstCard(7);
    final c = await firstCard(31);
    expect(a, isNotEmpty);
    expect(a, b, reason: 'the same seed must deal the same first card');
    expect(a, isNot(c), reason: 'a different seed must deal a different one');
  });
}
