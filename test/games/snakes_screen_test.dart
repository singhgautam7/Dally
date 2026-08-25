import 'package:dally/features/games/snakes_and_ladders/snakes_config.dart';
import 'package:dally/features/games/snakes_and_ladders/ui/play_snakes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  Widget screen(int side, int players) => PlaySnakesScreen(
        moduleId: 'snakes_and_ladders',
        config: SnakesConfig(
          playerCount: players,
          names: const ['Ana', 'Bo', 'Cy', 'Di'].sublist(0, players),
          side: side,
        ),
      );

  for (final side in const [6, 8, 10]) {
    testWidgets('a $side×$side board lays out on a small phone', (tester) async {
      await pumpGameScreen(tester, screen(side, 4), size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(find.text('Roll'), findsOneWidget);
    });
  }

  testWidgets('rolling walks a token and eventually ends the game',
      (tester) async {
    await pumpGameScreen(tester, screen(6, 2));
    for (var i = 0; i < 200; i++) {
      final roll = find.text('Roll');
      if (roll.evaluate().isEmpty) break;
      await tester.tap(roll);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Play again'), findsOneWidget);
  });
}
