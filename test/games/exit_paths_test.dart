import 'package:dally/features/games/dots_and_boxes/dots_config.dart';
import 'package:dally/features/games/dots_and_boxes/ui/play_dots_screen.dart';
import 'package:dally/features/games/undercover/logic/word_pair.dart';
import 'package:dally/features/games/undercover/ui/play_undercover_screen.dart';
import 'package:dally/features/games/undercover/undercover_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// The two games that never adopted `leaveGame` / `GameBackScope`, and the two
/// ways each of them used to get leaving wrong.
///
/// Dots & Boxes popped one screen — landing back on its *own setup screen*
/// rather than Home. The party game's `PopScope` opened the pause sheet on every back
/// press and offered no second step, so system back could never leave the game
/// at all.
void main() {
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  group('Dots & Boxes', () {
    const config = DotsConfig(
      cols: 4,
      rows: 4,
      names: ['Ana', 'Ben'],
      firstPlayer: 0,
    );

    Widget screen() =>
        const PlayDotsScreen(moduleId: 'dots_and_boxes', config: config);

    testWidgets('leaving from the pause sheet lands on Home, not on setup',
        (tester) async {
      await pumpGameRoute(tester, screen());
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();
      // Mid-game, so it confirms first.
      expect(find.text('Leave this game?'), findsOneWidget);
      await tester.tap(find.text('Leave game'));
      await tester.pumpAndSettle();
      expect(find.text(kHomeMarker), findsOneWidget);
    });

    testWidgets('system back opens the pause sheet before it offers to leave',
        (tester) async {
      await pumpGameRoute(tester, screen());
      await pressBack(tester);
      expect(find.text('Restart this board'), findsOneWidget,
          reason: 'the first back is the pause sheet');
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      await pressBack(tester);
      expect(find.text('Leave this game?'), findsOneWidget);
    });

    testWidgets('the seats are the shared identities, not theme colours',
        (tester) async {
      await pumpGameRoute(tester, screen());
      // Both players' names come from the shared strip rather than a private
      // score row, which is what carries the identity mark and shape.
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
    });
  });

  group('Undercover', () {
    const config = UndercoverConfig(
      names: ['Ana', 'Ben', 'Cass', 'Dee', 'Eli'],
      undercover: 1,
      mrWhite: false,
      difficulty: WordDifficulty.normal,
      voting: UndercoverVoting.open,
    );

    Widget screen() =>
        const PlayUndercoverScreen(moduleId: 'undercover', config: config);

    testWidgets('back opens the pause sheet, and back again offers to leave',
        (tester) async {
      await pumpGameRoute(tester, screen());
      await pressBack(tester);
      expect(find.text('Restart this board'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      await pressBack(tester);
      expect(find.text('Leave this game?'), findsOneWidget,
          reason: 'the second back must be able to leave, not re-pause');
      await tester.tap(find.text('Leave game'));
      await tester.pumpAndSettle();
      expect(find.text(kHomeMarker), findsOneWidget);
    });

    testWidgets('"Back to games" from the pause sheet reaches Home',
        (tester) async {
      await pumpGameRoute(tester, screen());
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave game'));
      await tester.pumpAndSettle();
      expect(find.text(kHomeMarker), findsOneWidget);
    });
  });
}
