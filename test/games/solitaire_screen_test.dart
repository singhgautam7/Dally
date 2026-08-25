import 'package:dally/features/games/solitaire/solitaire_config.dart';
import 'package:dally/features/games/solitaire/solitaire_module.dart';
import 'package:dally/features/games/solitaire/ui/play_solitaire_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  Widget screen(int draw) => PlaySolitaireScreen(
        module: SolitaireModule(),
        config: SolitaireConfig(drawCount: draw),
      );

  for (final size in const [Size(320, 568), Size(360, 640), Size(430, 932)]) {
    testWidgets('the table lays out at ${size.width}×${size.height}',
        (tester) async {
      await pumpGameScreen(tester, screen(1), size: size);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Tap a card'), findsOneWidget);
    });
  }

  testWidgets('tapping the stock turns cards without throwing', (tester) async {
    await pumpGameScreen(tester, screen(3));
    // The stock sits at the top-left of the board area.
    final board = find.byType(CustomPaint).last;
    final topLeft = tester.getTopLeft(board);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(topLeft + const Offset(20, 20));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
