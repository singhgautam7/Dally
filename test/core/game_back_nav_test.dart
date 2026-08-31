import 'package:dally/core/widgets/game_exit.dart';
import 'package:dally/core/widgets/game_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// One implementation of back navigation serves every game, so it is tested
/// once here rather than a dozen times over the game screens.
void main() {
  /// Fires a system back press the way Android does.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Widget scaffold({required bool ended, required VoidCallback onPause}) =>
      GameScaffold(
        onOverflow: onPause,
        ended: ended,
        statusBar: const Text('status'),
        board: const SizedBox(width: 100, height: 100),
        controls: const Text('controls'),
      );

  testWidgets('the first back mid-game opens the pause sheet', (tester) async {
    var paused = 0;
    await pumpGameScreen(
        tester, scaffold(ended: false, onPause: () => paused++));
    await pressBack(tester);
    expect(paused, 1);
    // Nothing was popped: the game is still on screen.
    expect(find.text('status'), findsOneWidget);
  });

  testWidgets('back again asks to leave rather than re-opening the sheet',
      (tester) async {
    var paused = 0;
    await pumpGameScreen(
        tester, scaffold(ended: false, onPause: () => paused++));
    await pressBack(tester);
    await pressBack(tester);
    expect(paused, 1, reason: 'the sheet is not opened twice');
    expect(find.text('Leave this game?'), findsOneWidget);
  });

  testWidgets('"Keep playing" returns to the board', (tester) async {
    await pumpGameScreen(tester, scaffold(ended: false, onPause: () {}));
    await pressBack(tester);
    await pressBack(tester);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this game?'), findsNothing);
    expect(find.text('status'), findsOneWidget);
  });

  testWidgets('once the game has ended, back goes straight to Home',
      (tester) async {
    var paused = 0;
    await pumpGameRoute(tester, scaffold(ended: true, onPause: () => paused++));
    await pressBack(tester);
    expect(paused, 0, reason: 'there is nothing left to pause');
    expect(find.text('Leave this game?'), findsNothing);
    expect(find.text(kHomeMarker), findsOneWidget);
  });

  testWidgets('leaving mid-game confirms first, then lands on Home',
      (tester) async {
    await pumpGameRoute(tester, scaffold(ended: false, onPause: () {}));
    await pressBack(tester);
    await pressBack(tester);
    expect(find.text(kHomeMarker), findsNothing, reason: 'not yet — confirm first');
    await tester.tap(find.text('Leave game'));
    await tester.pumpAndSettle();
    expect(find.text(kHomeMarker), findsOneWidget);
  });

  testWidgets('opening the pause sheet from the overflow counts as seen',
      (tester) async {
    var paused = 0;
    await pumpGameScreen(
        tester, scaffold(ended: false, onPause: () => paused++));
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(paused, 1);
    await pressBack(tester);
    expect(paused, 1, reason: 'the next back asks to leave instead');
    expect(find.text('Leave this game?'), findsOneWidget);
  });

  testWidgets('the exit confirmation tailors its copy to saved progress',
      (tester) async {
    await pumpGameRoute(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => leaveGame(context, progressSaved: true),
              child: const Text('leave'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pick it up later'), findsOneWidget);
  });
}
