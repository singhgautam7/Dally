import 'package:dally/features/games/four_in_a_row/logic/four_in_a_row.dart';
import 'package:flutter_test/flutter_test.dart';

/// Row 0 is the top; a disc falls toward the highest row index.
void main() {
  /// Drops a whole line of columns in order, alternating seats implicitly.
  void dropAll(FourInARowGame g, List<int> cols) {
    for (final c in cols) {
      g.drop(c);
    }
  }

  group('the board', () {
    test('a fresh board is empty and nobody has won', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      expect(g.discs, 0);
      expect(g.winner, isNull);
      expect(g.isOver, isFalse);
      expect(g.isDrawn, isFalse);
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < 7; c++) {
          expect(g.ownerAt(r, c), -1);
        }
      }
    });

    test('the first player is configurable', () {
      expect(FourInARowGame(cols: 7, rows: 6).currentPlayer, 0);
      expect(FourInARowGame(cols: 7, rows: 6, firstPlayer: 1).currentPlayer, 1);
    });

    test('the target is four at every offered size', () {
      expect(FourInARowGame.target, 4);
      for (final (cols, rows) in const [(6, 5), (7, 6), (8, 7)]) {
        final g = FourInARowGame(cols: cols, rows: rows);
        expect(g.cols, cols);
        expect(g.rows, rows);
      }
    });
  });

  group('dropping', () {
    test('a disc falls to the lowest free slot', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      expect(g.drop(3), 5, reason: 'the bottom row');
      expect(g.drop(3), 4, reason: 'stacked on top of it');
      expect(g.ownerAt(5, 3), 0);
      expect(g.ownerAt(4, 3), 1);
    });

    test('landingRow agrees with where the disc actually lands', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      for (var i = 0; i < 6; i++) {
        final predicted = g.landingRow(2);
        expect(g.drop(2), predicted, reason: 'drop $i');
      }
    });

    test('the turn passes on every drop', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      expect(g.currentPlayer, 0);
      g.drop(0);
      expect(g.currentPlayer, 1);
      g.drop(1);
      expect(g.currentPlayer, 0);
    });

    test('a full column is refused, and the board is untouched', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      // Fill column 0 without ever making a line: alternate 0 and 1 by pairs is
      // enough because a vertical four needs the same seat four deep.
      for (var i = 0; i < 6; i++) {
        g.drop(i.isEven ? 0 : 1);
        g.drop(i.isEven ? 1 : 0);
      }
      expect(g.canDrop(0), isFalse);
      final before = g.discs;
      expect(g.drop(0), isNull);
      expect(g.discs, before);
    });

    test('an off-board column is refused', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      expect(g.canDrop(-1), isFalse);
      expect(g.canDrop(7), isFalse);
      expect(g.drop(7), isNull);
      expect(g.landingRow(9), isNull);
    });
  });

  group('win detection', () {
    test('horizontal', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      // Seat 0 takes 0,1,2,3 along the bottom; seat 1 stacks harmlessly on 6.
      dropAll(g, [0, 6, 1, 6, 2, 6, 3]);
      expect(g.winner, 0);
      expect(g.winLine!.cells, [(5, 0), (5, 1), (5, 2), (5, 3)]);
    });

    test('vertical', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      dropAll(g, [2, 3, 2, 3, 2, 3, 2]);
      expect(g.winner, 0);
      expect(g.winLine!.cells, [(2, 2), (3, 2), (4, 2), (5, 2)]);
    });

    test('diagonal, bottom-left to top-right', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      // Build the staircase under seat 0's diagonal.
      dropAll(g, [0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3]);
      expect(g.winner, 0);
      expect(g.winLine!.cells, [(2, 3), (3, 2), (4, 1), (5, 0)]);
    });

    test('diagonal, bottom-right to top-left', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      dropAll(g, [6, 5, 5, 4, 4, 3, 4, 3, 3, 0, 3]);
      expect(g.winner, 0);
      expect(g.winLine!.cells.length, 4);
      // Every cell on the line belongs to the winner, and they are a diagonal.
      final cells = g.winLine!.cells;
      for (final (r, c) in cells) {
        expect(g.ownerAt(r, c), 0);
      }
      for (var i = 1; i < cells.length; i++) {
        expect((cells[i].$1 - cells[i - 1].$1).abs(), 1);
        expect((cells[i].$2 - cells[i - 1].$2).abs(), 1);
      }
    });

    test('a line of five still reports exactly four, including the last disc', () {
      final g = FourInARowGame(cols: 8, rows: 7);
      // Seat 0 fills 0–3 along the bottom, then plays 4 for a fifth in line.
      dropAll(g, [1, 7, 2, 7, 3, 7, 0]);
      expect(g.winner, 0);
      expect(g.winLine!.cells, hasLength(4));
      expect(g.winLine!.contains(6, 0), isTrue, reason: 'the disc just played');
    });

    test('the turn does not pass once a line is made', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      dropAll(g, [0, 6, 1, 6, 2, 6, 3]);
      expect(g.currentPlayer, 0, reason: 'the winner keeps the turn');
      expect(g.isOver, isTrue);
    });

    test('a finished board refuses further drops', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      dropAll(g, [0, 6, 1, 6, 2, 6, 3]);
      final before = g.discs;
      expect(g.drop(4), isNull);
      expect(g.discs, before);
    });

    test('three in a line is not a win', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      dropAll(g, [0, 6, 1, 6, 2]);
      expect(g.winner, isNull);
      expect(g.isOver, isFalse);
    });

    test('a line that wraps the edge is not a line', () {
      final g = FourInARowGame(cols: 6, rows: 5);
      // Seat 0 on columns 4 and 5, seat 1 elsewhere: nothing may join across.
      dropAll(g, [4, 0, 5, 1, 4, 0, 5]);
      expect(g.winner, isNull);
    });
  });

  group('draws', () {
    test('a full board with no line is a draw, declared on the last drop', () {
      // The drawn sequence is *searched for* rather than hand-written, so this
      // asserts the rules rather than a lucky order: a depth-first walk over
      // legal drops that abandons any branch which makes a line.
      final order = _drawnFilling(cols: 4, rows: 4);
      expect(order, isNotNull, reason: 'a 4×4 board must be fillable without a line');

      final g = FourInARowGame(cols: 4, rows: 4);
      for (final c in order!) {
        expect(g.isOver, isFalse, reason: 'nothing ends before the last drop');
        g.drop(c);
      }
      expect(g.isFull, isTrue);
      expect(g.winner, isNull);
      expect(g.isDrawn, isTrue);
      expect(g.isOver, isTrue);
      // …and the finished board takes nothing more.
      expect(g.drop(0), isNull);
    });

    test('isDrawn is false while the board still has room', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      g.drop(0);
      expect(g.isDrawn, isFalse);
      expect(g.isFull, isFalse);
    });
  });

  group('undo', () {
    test('the last disc comes off and the turn goes back', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      g.drop(3);
      final before = g.snapshot();
      expect(g.currentPlayer, 1);
      g.drop(3);
      expect(g.ownerAt(4, 3), 1);

      g.restore(before);
      expect(g.ownerAt(4, 3), -1);
      expect(g.ownerAt(5, 3), 0, reason: 'the earlier disc stays');
      expect(g.currentPlayer, 1);
      expect(g.discs, 1);
    });

    test('undoing the winning drop reopens the game', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      dropAll(g, [0, 6, 1, 6, 2, 6]);
      final before = g.snapshot();
      g.drop(3);
      expect(g.isOver, isTrue);

      g.restore(before);
      expect(g.winner, isNull);
      expect(g.winLine, isNull);
      expect(g.isOver, isFalse);
      expect(g.canDrop(3), isTrue);
    });

    test('a snapshot is independent of the live board', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      final snapshot = g.snapshot();
      g.drop(3);
      expect(snapshot.cells[5][3], -1);
      expect(snapshot.discs, 0);
    });

    test('walking several steps back lands on each earlier position exactly', () {
      final g = FourInARowGame(cols: 7, rows: 6);
      final history = <FourSnapshot>[];
      for (final c in [3, 3, 4, 2, 5]) {
        history.add(g.snapshot());
        g.drop(c);
      }
      for (final s in history.reversed) {
        g.restore(s);
        expect(g.discs, s.discs);
        expect(g.currentPlayer, s.current);
        for (var r = 0; r < g.rows; r++) {
          for (var c = 0; c < g.cols; c++) {
            expect(g.ownerAt(r, c), s.cells[r][c]);
          }
        }
      }
    });
  });
}

/// A drop order that fills a [cols] × [rows] board with no four in a line, or
/// null if none exists. Depth-first, abandoning any branch that makes a line.
List<int>? _drawnFilling({required int cols, required int rows}) {
  final game = FourInARowGame(cols: cols, rows: rows);
  final path = <int>[];

  bool walk() {
    if (game.isFull) return game.winner == null;
    for (var c = 0; c < cols; c++) {
      if (!game.canDrop(c)) continue;
      final before = game.snapshot();
      game.drop(c);
      if (game.winner == null) {
        path.add(c);
        if (walk()) return true;
        path.removeLast();
      }
      game.restore(before);
    }
    return false;
  }

  return walk() ? path : null;
}
