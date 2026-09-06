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

  // ── v6 ────────────────────────────────────────────────────────────────────

  /// The two player bars, top first. Private to the screen, so found by name.
  Finder playerBars() => find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_PlayerBar');

  for (final size in const [
    Size(320, 568),
    Size(390, 780),
    Size(768, 1024),
    Size(820, 420),
  ]) {
    final label = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets('$label: the board takes all the room there is', (tester) async {
      await pumpGameScreen(tester, screen(), size: size);
      await tester.pump();
      final board = tester.getRect(find.byType(AspectRatio).first);

      // The board is square, so it is bound by whichever axis runs out first.
      // What v6 changed is the *width* bound: the shared 18px gutter used to
      // cost eight squares a fifth of their width, and it is now a hairline.
      if (size.width <= size.height) {
        expect(board.left, moreOrLessEquals(size.width - board.right, epsilon: 0.5),
            reason: 'symmetric inset');
      }
      expect(board.width, moreOrLessEquals(board.height, epsilon: 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label: nothing clips', (tester) async {
      await pumpGameScreen(tester, screen(), size: size);
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < playerBars().evaluate().length; i++) {
        final r = tester.getRect(playerBars().at(i));
        expect(r.top, greaterThanOrEqualTo(-0.5), reason: 'bar $i off the top');
        expect(r.bottom, lessThanOrEqualTo(size.height + 0.5),
            reason: 'bar $i off the bottom');
        expect(r.left, greaterThanOrEqualTo(-0.5));
        expect(r.right, lessThanOrEqualTo(size.width + 0.5));
      }
    });

    testWidgets('$label: the two bars sit the same distance from the board',
        (tester) async {
      await pumpGameScreen(tester, screen(), size: size);
      await tester.pump();
      final board = tester.getRect(find.byType(AspectRatio).first);
      expect(playerBars(), findsNWidgets(2));
      // Portrait stacks the bars above and below; landscape moves them to the
      // sides so the board can use the whole height (§10). Either way the two
      // gaps have to match.
      final landscape = size.width > size.height;
      final bars = [
        for (var i = 0; i < 2; i++) tester.getRect(playerBars().at(i)),
      ]..sort((a, b) =>
          landscape ? a.left.compareTo(b.left) : a.top.compareTo(b.top));
      final near = landscape
          ? board.left - bars.first.right
          : board.top - bars.first.bottom;
      final far = landscape
          ? bars.last.left - board.right
          : bars.last.top - board.bottom;
      expect(near, moreOrLessEquals(far, epsilon: 0.5),
          reason: 'gaps $near vs $far');
    });
  }

  testWidgets('given the height for it, the board really is full width',
      (tester) async {
    // A tall phone has the vertical room, so the width bound is the one that
    // bites — and there the hairline inset is all that separates the board
    // from the screen edge.
    await pumpGameScreen(tester, screen(), size: const Size(390, 900));
    await tester.pump();
    final board = tester.getRect(find.byType(AspectRatio).first);
    expect(390 - board.width, lessThan(10),
        reason: 'board is ${board.width} wide on a 390 screen');
  });
}
