import 'package:dally/features/games/carrom/carrom_config.dart';
import 'package:dally/features/games/carrom/carrom_module.dart';
import 'package:dally/features/games/carrom/logic/carrom_game.dart';
import 'package:dally/features/games/carrom/ui/play_carrom_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  Widget screen(int players) => PlayCarromScreen(
        module: CarromModule(),
        config: CarromConfig(
          playerCount: players,
          names: const ['Ana', 'Bo', 'Cy', 'Di'].sublist(0, players),
          rules: const CarromRules(),
        ),
      );

  for (final size in const [Size(320, 568), Size(360, 640), Size(430, 932)]) {
    testWidgets('the board lays out at ${size.width}×${size.height}', (tester) async {
      await pumpGameScreen(tester, screen(2), size: size);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Slide the striker'), findsOneWidget);
    });
  }

  testWidgets('a shot runs the loop and settles without leaking a ticker',
      (tester) async {
    await pumpGameScreen(tester, screen(4));
    final board = find.byType(CustomPaint).last;
    final centre = tester.getCenter(board);

    // Pull back from the striker and let go.
    await tester.dragFrom(centre + const Offset(0, 120), const Offset(0, 60));
    await tester.pump();
    // Run the loop out; the shot decelerates to rest on its own.
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });
}
