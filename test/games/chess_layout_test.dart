import 'package:dally/features/games/chess/chess_config.dart';
import 'package:dally/features/games/chess/ui/play_chess_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// The chess board used to be sized at a flat 86% of the available height, with
/// the player bar underneath assumed to fit in the rest. On a 320×568 phone it
/// did not, and the column overflowed by 10px. The board now takes what the bar
/// leaves, so these three sizes all have to hold.
void main() {
  Widget screen() => const PlayChessScreen(
        moduleId: 'chess',
        config: ChessConfig(
          time: ChessTime.none,
          player1Side: ChessSide.white,
          flipEachTurn: false,
          faceToFace: false,
          legalDots: true,
        ),
      );

  for (final size in const [
    Size(320, 568), // the smallest phone supported
    Size(360, 640),
    Size(430, 932), // a large modern phone
  ]) {
    testWidgets('the board is square and fits at ${size.width}×${size.height}',
        (tester) async {
      await pumpGameScreen(tester, screen(), size: size);
      await tester.pump();
      expect(tester.takeException(), isNull);

      final board = tester.getSize(find.byType(AspectRatio).first);
      expect(board.width, moreOrLessEquals(board.height, epsilon: 0.5),
          reason: 'the board stays square');
      expect(board.width, lessThanOrEqualTo(size.width));
      expect(board.width, greaterThan(size.width * 0.5),
          reason: 'it still takes most of the width — it did not collapse');
    });
  }
}
