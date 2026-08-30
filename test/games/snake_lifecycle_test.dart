import 'package:dally/features/games/snake/snake_config.dart';
import 'package:dally/features/games/snake/ui/play_snake_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Snake was the last real-time game running its own `Timer.periodic` instead
/// of the shared loop, and it paid for it: backgrounding the app stopped the
/// timer and *nothing* ever restarted it, so a run came back from a phone call
/// permanently frozen. It is on `RealTimeGameMixin` now, which owns
/// pause-and-resume for every other real-time game in the app.
void main() {
  const config =
      SnakeConfig(arena: SnakeArena.medium, speed: SnakeSpeed.normal, wrap: false);

  Widget screen() => const PlaySnakeScreen(moduleId: 'snake', config: config);

  /// Unmounts the screen so its ticker is disposed before teardown.
  Future<void> stop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// Starts the run by steering, which is the only way in.
  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();
  }

  /// Runs the loop for [ms] of simulated time, a frame at a time.
  Future<void> run(WidgetTester tester, int ms) async {
    for (var elapsed = 0; elapsed < ms; elapsed += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('a run left alone eventually hits the wall', (tester) async {
    await pumpGameScreen(tester, screen());
    await start(tester);
    await run(tester, 4000);
    expect(find.text('Into the wall.'), findsOneWidget);
    await stop(tester);
  });

  testWidgets('the run survives being backgrounded and resumed', (tester) async {
    await pumpGameScreen(tester, screen());
    await start(tester);
    await run(tester, 200);
    expect(find.text('Into the wall.'), findsNothing, reason: 'still alive');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    // Time passes with the app in the background; the snake must not move.
    await run(tester, 4000);
    expect(find.text('Into the wall.'), findsNothing,
        reason: 'a backgrounded game does not play itself into a wall');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await run(tester, 4000);
    expect(find.text('Into the wall.'), findsOneWidget,
        reason: 'the loop restarted — it used to stay dead for good');
    await stop(tester);
  });

  testWidgets('the loop stays stopped while the pause sheet is open',
      (tester) async {
    await pumpGameScreen(tester, screen());
    await start(tester);
    await run(tester, 200);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await run(tester, 4000);
    expect(find.text('Into the wall.'), findsNothing,
        reason: 'the game does not run on behind the sheet');

    // Snake's sheet carries three extra rows; on a 360×640 phone that is
    // taller than the screen, so it scrolls — which is the point of the fix
    // that stopped it clipping "Resume" off the bottom entirely.
    await tester.ensureVisible(find.text('Resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    await run(tester, 4000);
    expect(find.text('Into the wall.'), findsOneWidget);
    await stop(tester);
  });
}
