import 'package:dally/features/games/tic_tac_toe/logic/tic_tac_toe_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TicTacToeGame 3×3', () {
    test('detects a row win for X', () {
      final g = TicTacToeGame(size: 3, winLength: 3, firstPlayer: Ttt.x);
      // X: 0,1,2  O: 3,4
      g.play(0); // X
      g.play(3); // O
      g.play(1); // X
      g.play(4); // O
      g.play(2); // X wins top row
      expect(g.result, isNotNull);
      expect(g.result!.winner, Ttt.x);
      expect(g.result!.line, [0, 1, 2]);
    });

    test('detects a diagonal win', () {
      final g = TicTacToeGame(size: 3, winLength: 3, firstPlayer: Ttt.x);
      g.play(0); // X
      g.play(1); // O
      g.play(4); // X
      g.play(2); // O
      g.play(8); // X wins diagonal 0,4,8
      expect(g.result!.winner, Ttt.x);
      expect(g.result!.line, [0, 4, 8]);
    });

    test('detects a draw when the board fills with no line', () {
      final g = TicTacToeGame(size: 3, winLength: 3, firstPlayer: Ttt.x);
      // X O X / X O O / O X X  → full, no 3-in-a-row.
      for (final i in [0, 1, 2, 4, 3, 5, 7, 6, 8]) {
        g.play(i);
      }
      expect(g.isFull, isTrue);
      expect(g.result, isNotNull);
      expect(g.result!.winner, 0);
      expect(g.result!.line, isEmpty);
    });

    test('turn alternates and rejects occupied cells', () {
      final g = TicTacToeGame(size: 3, winLength: 3, firstPlayer: Ttt.x);
      expect(g.current, Ttt.x);
      expect(g.play(0), isTrue);
      expect(g.current, Ttt.o);
      expect(g.play(0), isFalse); // occupied
      expect(g.current, Ttt.o); // unchanged
    });

    test('no result while game is in progress', () {
      final g = TicTacToeGame(size: 3, winLength: 3, firstPlayer: Ttt.x);
      g.play(0);
      expect(g.result, isNull);
    });
  });

  group('TicTacToeGame larger boards', () {
    test('4×4 needs the configured length to win', () {
      final g = TicTacToeGame(size: 4, winLength: 4, firstPlayer: Ttt.x);
      // X across top row 0..3, O elsewhere.
      g.play(0); g.play(4);
      g.play(1); g.play(5);
      g.play(2); g.play(6);
      expect(g.result, isNull); // only 3 in a row so far
      g.play(3); // 4 in a row
      expect(g.result!.winner, Ttt.x);
      expect(g.result!.line, [0, 1, 2, 3]);
    });

    test('5×5 with win length 4 finds a vertical run', () {
      final g = TicTacToeGame(size: 5, winLength: 4, firstPlayer: Ttt.x);
      // X column 0: indices 0,5,10,15. O scattered off-column.
      g.play(0); g.play(1);
      g.play(5); g.play(2);
      g.play(10); g.play(3);
      g.play(15); // 0,5,10,15 vertical
      expect(g.result!.winner, Ttt.x);
      expect(g.result!.line, [0, 5, 10, 15]);
    });
  });
}
