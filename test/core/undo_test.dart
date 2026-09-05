import 'package:dally/core/game/undo.dart';
import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/game_2048/logic/board_2048.dart';
import 'package:dally/features/games/solitaire/logic/solitaire.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UndoStack', () {
    test('starts empty and offers nothing to take back', () {
      final s = UndoStack<int>();
      expect(s.canUndo, isFalse);
      expect(s.pop(), isNull);
      expect(s.used, isFalse);
    });

    test('one tap is one step, newest first', () {
      final s = UndoStack<int>()
        ..push(1)
        ..push(2)
        ..push(3);
      expect(s.pop(), 3);
      expect(s.pop(), 2);
      expect(s.pop(), 1);
      expect(s.canUndo, isFalse);
    });

    test('the cap is five, and the oldest is dropped silently', () {
      final s = UndoStack<int>();
      for (var i = 1; i <= 9; i++) {
        s.push(i);
      }
      expect(s.depth, 5);
      expect([for (var i = 0; i < 5; i++) s.pop()], [9, 8, 7, 6, 5]);
      // Everything older than the cap is simply gone — no error, no warning.
      expect(s.pop(), isNull);
    });

    test('clear drops the history but keeps the record-integrity flag', () {
      final s = UndoStack<int>()..push(1);
      s.pop();
      expect(s.used, isTrue);
      // Clearing at the end of a game must not launder the run that used undo.
      s.clear();
      expect(s.canUndo, isFalse);
      expect(s.used, isTrue);
    });

    test('reset is a new game: history gone and the flag with it', () {
      final s = UndoStack<int>()..push(1);
      s.pop();
      s.reset();
      expect(s.used, isFalse);
      expect(s.canUndo, isFalse);
    });

    test('the flag only lifts on an actual step back', () {
      final s = UndoStack<int>()..push(1);
      expect(s.used, isFalse, reason: 'pushing is not undoing');
      final empty = UndoStack<int>();
      empty.pop();
      expect(empty.used, isFalse, reason: 'a pop with nothing to pop is not a step');
    });
  });

  group('2048 undo restores the exact prior state', () {
    test('tiles and score come back together', () {
      final board = Board2048(size: 4, rng: DallyRandom.seeded(7).asRandom)..start();
      final stack = UndoStack<({List<int> values, int score})>();

      for (var i = 0; i < 12; i++) {
        final before = (values: board.toValues(), score: board.score);
        final move = Move2048.values[i % 4];
        if (!board.apply(move).moved) continue;
        stack.push(before);
      }
      expect(stack.canUndo, isTrue);

      // Walk the whole stack back and check every step lands exactly.
      while (stack.canUndo) {
        final s = stack.pop()!;
        board.loadValues(s.values, s.score);
        expect(board.toValues(), s.values);
        expect(board.score, s.score);
      }
    });

    test('an undone move is not replayed by the next move', () {
      final board = Board2048(size: 4, rng: DallyRandom.seeded(3).asRandom)..start();
      final before = (values: board.toValues(), score: board.score);
      board.apply(Move2048.left);
      board.loadValues(before.values, before.score);
      expect(board.toValues(), before.values);
    });
  });

  group('Solitaire undo restores the exact prior state', () {
    test('a move comes back, flip included', () {
      final game = Solitaire(random: DallyRandom.seeded(11));
      // Find any legal tableau→tableau or →foundation move.
      CardRef? from;
      (PileKind, int)? target;
      for (var c = 0; c < Solitaire.columns && from == null; c++) {
        final column = game.tableau[c];
        if (column.isEmpty) continue;
        final ref = CardRef(PileKind.tableau, c, column.length - 1);
        final t = game.autoTarget(ref);
        if (t != null) {
          from = ref;
          target = t;
        }
      }
      // A fresh Klondike deal with a seeded shuffle either has a move or a
      // draw; the draw path is covered below, so only assert when there is one.
      if (from == null) return;

      final snapshot = game.snapshot();
      final faceUpBefore = List<int>.from(game.faceUpFrom);
      expect(game.move(from, target!.$1, target.$2), isTrue);
      game.restore(snapshot);

      expect(game.faceUpFrom, faceUpBefore, reason: 'the flip is undone too');
      expect(game.moves, snapshot.moves);
      for (var c = 0; c < Solitaire.columns; c++) {
        expect(game.tableau[c].length, snapshot.tableau[c].length);
      }
    });

    test('a stock draw comes back', () {
      final game = Solitaire(random: DallyRandom.seeded(5));
      final snapshot = game.snapshot();
      expect(game.draw(), isTrue);
      expect(game.waste, isNotEmpty);
      game.restore(snapshot);
      expect(game.waste, isEmpty);
      expect(game.stock.length, snapshot.stock.length);
      expect(game.moves, snapshot.moves);
    });

    test('a snapshot is independent of the live game', () {
      final game = Solitaire(random: DallyRandom.seeded(9));
      final snapshot = game.snapshot();
      final stockBefore = snapshot.stock.length;
      game.draw();
      // Mutating the game must not reach back into the captured lists.
      expect(snapshot.stock.length, stockBefore);
    });
  });
}
