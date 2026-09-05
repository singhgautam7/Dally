import 'package:dally/features/games/dots_and_boxes/logic/dots_and_boxes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('board creation', () {
    test('a fresh board is empty and unclaimed', () {
      final g = DotsAndBoxesGame(cols: 5, rows: 5);
      expect(g.totalBoxes, 25);
      expect(g.claimedBoxes, 0);
      expect(g.scoreOf(0), 0);
      expect(g.scoreOf(1), 0);
      expect(g.isFinished, isFalse);
      expect(g.ownerAt(2, 2), -1);
    });

    test('the move count matches the geometry for any size', () {
      for (final n in [4, 5, 6]) {
        final g = DotsAndBoxesGame(cols: n, rows: n);
        // 2 · n · (n + 1) edges on an n × n board.
        expect(g.legalMoves.length, 2 * n * (n + 1), reason: '$n×$n');
      }
    });

    test('the first player is configurable', () {
      expect(DotsAndBoxesGame(cols: 4, rows: 4).currentPlayer, 0);
      expect(DotsAndBoxesGame(cols: 4, rows: 4, firstPlayer: 1).currentPlayer, 1);
    });
  });

  group('legality', () {
    test('an off-board edge is rejected', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      expect(g.isLegal(const BoxEdge(EdgeKind.horizontal, 5, 0)), isFalse);
      expect(g.isLegal(const BoxEdge(EdgeKind.horizontal, 0, 4)), isFalse);
      expect(g.isLegal(const BoxEdge(EdgeKind.vertical, 4, 0)), isFalse);
      expect(g.isLegal(const BoxEdge(EdgeKind.vertical, 0, 5)), isFalse);
      expect(g.isLegal(const BoxEdge(EdgeKind.horizontal, -1, 0)), isFalse);
    });

    test('the outer edges of the grid are legal', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      expect(g.isLegal(const BoxEdge(EdgeKind.horizontal, 4, 3)), isTrue);
      expect(g.isLegal(const BoxEdge(EdgeKind.vertical, 3, 4)), isTrue);
    });

    test('an edge cannot be drawn twice, and the board is untouched', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      const edge = BoxEdge(EdgeKind.horizontal, 0, 0);
      expect(g.play(edge), isNotNull);
      final before = g.currentPlayer;
      expect(g.play(edge), isNull);
      expect(g.currentPlayer, before, reason: 'a rejected move must not pass the turn');
      expect(g.legalMoves.length, 2 * 4 * 5 - 1);
    });
  });

  group('turns', () {
    test('a move that closes nothing passes the turn', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      expect(g.currentPlayer, 0);
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 0));
      expect(g.currentPlayer, 1);
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 1));
      expect(g.currentPlayer, 0);
    });
  });

  group('box completion', () {
    /// Draws three sides of box (0,0), leaving one open.
    void threeSides(DotsAndBoxesGame g) {
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 0));
      g.play(const BoxEdge(EdgeKind.horizontal, 1, 0));
      g.play(const BoxEdge(EdgeKind.vertical, 0, 0));
    }

    test('the fourth side claims the box for whoever drew it', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      threeSides(g);
      final closer = g.currentPlayer;
      final result = g.play(const BoxEdge(EdgeKind.vertical, 0, 1))!;
      expect(result.claimed, 1);
      expect(g.ownerAt(0, 0), closer);
      expect(g.scoreOf(closer), 1);
    });

    test('closing a box grants another turn', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      threeSides(g);
      final closer = g.currentPlayer;
      final result = g.play(const BoxEdge(EdgeKind.vertical, 0, 1))!;
      expect(result.extraTurn, isTrue);
      expect(g.currentPlayer, closer, reason: 'the closer plays again');
    });

    test('one line can close two boxes at once', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      // Box (0,0) and box (1,0) both left waiting on the line between them.
      for (final e in const [
        BoxEdge(EdgeKind.horizontal, 0, 0),
        BoxEdge(EdgeKind.vertical, 0, 0),
        BoxEdge(EdgeKind.vertical, 0, 1),
        BoxEdge(EdgeKind.horizontal, 2, 0),
        BoxEdge(EdgeKind.vertical, 1, 0),
        BoxEdge(EdgeKind.vertical, 1, 1),
      ]) {
        g.play(e);
      }
      final closer = g.currentPlayer;
      final result = g.play(const BoxEdge(EdgeKind.horizontal, 1, 0))!;
      expect(result.claimed, 2);
      expect(g.scoreOf(closer), 2);
      expect(result.extraTurn, isTrue);
    });

    test('a box already owned is never re-claimed', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      threeSides(g);
      final closer = g.currentPlayer;
      g.play(const BoxEdge(EdgeKind.vertical, 0, 1));
      // Fill the rest of the board; box (0,0) must stay with its original owner.
      for (final e in g.legalMoves) {
        g.play(e);
      }
      expect(g.ownerAt(0, 0), closer);
    });
  });

  group('completion', () {
    /// Plays every legal move until the board is full.
    DotsAndBoxesGame playOut(int side, {int firstPlayer = 0}) {
      final g = DotsAndBoxesGame(cols: side, rows: side, firstPlayer: firstPlayer);
      while (!g.isFinished) {
        final moves = g.legalMoves;
        if (moves.isEmpty) break;
        g.play(moves.first);
      }
      return g;
    }

    test('a played-out board claims every box', () {
      for (final n in [4, 5, 6]) {
        final g = playOut(n);
        expect(g.isFinished, isTrue, reason: '$n×$n');
        expect(g.claimedBoxes, g.totalBoxes, reason: '$n×$n');
        expect(g.scoreOf(0) + g.scoreOf(1), n * n, reason: '$n×$n');
      }
    });

    test('the winner is whoever has more boxes', () {
      final g = playOut(4);
      final a = g.scoreOf(0), b = g.scoreOf(1);
      if (a == b) {
        expect(g.winner, isNull);
      } else {
        expect(g.winner, a > b ? 0 : 1);
      }
    });

    test('a finished board refuses further moves', () {
      final g = playOut(4);
      expect(g.legalMoves, isEmpty);
      expect(g.play(const BoxEdge(EdgeKind.horizontal, 0, 0)), isNull);
    });

    test('an even split is a draw', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      // Forcing a 2–2 split by construction is fiddly; assert the rule directly.
      expect(g.winner, isNull, reason: '0–0 is a draw');
      expect(g.leaders, [0, 1], reason: 'a tie names every seat on the top score');
    });
  });

  group('rectangular boards', () {
    test('rows and columns are independent, either way round', () {
      final wide = DotsAndBoxesGame(cols: 10, rows: 6);
      final tall = DotsAndBoxesGame(cols: 6, rows: 10);
      expect(wide.totalBoxes, 60);
      expect(tall.totalBoxes, 60);
      // 10 × 6 has a different edge count from 6 × 10 in each orientation, and
      // the same total: rows·(cols+1) vertical + cols·(rows+1) horizontal.
      expect(wide.legalMoves.length, 6 * 11 + 10 * 7);
      expect(tall.legalMoves.length, 10 * 7 + 6 * 11);
    });

    test('the far corners of a non-square board are addressable', () {
      final g = DotsAndBoxesGame(cols: 10, rows: 6);
      expect(g.isLegal(const BoxEdge(EdgeKind.horizontal, 6, 9)), isTrue);
      expect(g.isLegal(const BoxEdge(EdgeKind.vertical, 5, 10)), isTrue);
      // …and one step past them is not.
      expect(g.isLegal(const BoxEdge(EdgeKind.horizontal, 7, 0)), isFalse);
      expect(g.isLegal(const BoxEdge(EdgeKind.vertical, 0, 11)), isFalse);
    });

    test('a wide board plays out completely', () {
      final g = DotsAndBoxesGame(cols: 12, rows: 3);
      while (!g.isFinished && g.legalMoves.isNotEmpty) {
        g.play(g.legalMoves.first);
      }
      expect(g.claimedBoxes, 36);
      expect(g.ownerAt(2, 11), isNot(-1), reason: 'the far corner box is claimed');
    });

    test('a box closed on a wide board is the right box', () {
      final g = DotsAndBoxesGame(cols: 10, rows: 6);
      // Three sides of the box at (row 5, col 9) — the bottom-right corner.
      g.play(const BoxEdge(EdgeKind.horizontal, 5, 9));
      g.play(const BoxEdge(EdgeKind.horizontal, 6, 9));
      g.play(const BoxEdge(EdgeKind.vertical, 5, 9));
      final closer = g.currentPlayer;
      final result = g.play(const BoxEdge(EdgeKind.vertical, 5, 10))!;
      expect(result.claimed, 1);
      expect(g.ownerAt(5, 9), closer);
      expect(g.ownerAt(0, 0), -1);
    });
  });

  group('three and four players', () {
    test('the turn passes round the seats in order', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4, playerCount: 3);
      expect(g.currentPlayer, 0);
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 0));
      expect(g.currentPlayer, 1);
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 1));
      expect(g.currentPlayer, 2);
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 2));
      expect(g.currentPlayer, 0, reason: 'and back round');
    });

    for (final players in [2, 3, 4]) {
      test('with $players players every box ends up owned exactly once', () {
        final g = DotsAndBoxesGame(cols: 5, rows: 4, playerCount: players);
        while (!g.isFinished && g.legalMoves.isNotEmpty) {
          g.play(g.legalMoves.first);
        }
        var total = 0;
        for (var p = 0; p < players; p++) {
          total += g.scoreOf(p);
        }
        expect(total, 20);
        expect(g.claimedBoxes, 20);
      });
    }

    test('closing a box gives the same seat another turn, not the next one', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4, playerCount: 4);
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 0));
      g.play(const BoxEdge(EdgeKind.horizontal, 1, 0));
      g.play(const BoxEdge(EdgeKind.vertical, 0, 0));
      final closer = g.currentPlayer;
      expect(closer, 3);
      g.play(const BoxEdge(EdgeKind.vertical, 0, 1));
      expect(g.currentPlayer, closer);
    });

    test('a four-way tie names all four seats', () {
      final g = DotsAndBoxesGame(cols: 3, rows: 3, playerCount: 4);
      expect(g.leaders, [0, 1, 2, 3]);
      expect(g.winner, isNull);
    });
  });

  group('undo', () {
    test('one line back un-claims the boxes it closed and returns the turn', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4, playerCount: 3);
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 0));
      g.play(const BoxEdge(EdgeKind.horizontal, 1, 0));
      g.play(const BoxEdge(EdgeKind.vertical, 0, 0));
      final before = g.snapshot();
      final closer = g.currentPlayer;

      g.play(const BoxEdge(EdgeKind.vertical, 0, 1));
      expect(g.ownerAt(0, 0), closer);

      g.restore(before);
      expect(g.ownerAt(0, 0), -1, reason: 'the box is un-claimed');
      expect(g.scoreOf(closer), 0);
      expect(g.currentPlayer, closer, reason: 'the turn comes back');
      expect(g.isLegal(const BoxEdge(EdgeKind.vertical, 0, 1)), isTrue,
          reason: 'the line is drawable again');
    });

    test('a snapshot is independent of the live board', () {
      final g = DotsAndBoxesGame(cols: 4, rows: 4);
      final snapshot = g.snapshot();
      g.play(const BoxEdge(EdgeKind.horizontal, 0, 0));
      g.restore(snapshot);
      expect(g.isLegal(const BoxEdge(EdgeKind.horizontal, 0, 0)), isTrue);
      expect(g.legalMoves.length, 2 * 4 * 5);
    });
  });
}
