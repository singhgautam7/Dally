import 'package:dally/features/games/ludo/logic/ludo.dart';
import 'package:dally/features/games/ludo/ludo_config.dart';
import 'package:dally/features/games/ludo/ui/play_ludo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  Widget screen(int players) => PlayLudoScreen(
        moduleId: 'ludo',
        config: LudoConfig(
          playerCount: players,
          names: const ['Ana', 'Bo', 'Cy', 'Di'].sublist(0, players),
          rules: const LudoRules(),
          firstPlayer: 0,
        ),
      );

  for (final size in const [Size(320, 568), Size(360, 640), Size(430, 932)]) {
    testWidgets('the board lays out and paints at ${size.width}×${size.height}',
        (tester) async {
      await pumpGameScreen(tester, screen(4), size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Roll'), findsOneWidget);
    });
  }

  testWidgets('rolling advances the turn without throwing', (tester) async {
    await pumpGameScreen(tester, screen(2));
    for (var i = 0; i < 12; i++) {
      final roll = find.text('Roll');
      if (roll.evaluate().isEmpty) break;
      await tester.tap(roll);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
