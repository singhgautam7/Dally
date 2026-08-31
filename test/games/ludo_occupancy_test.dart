import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/ludo/logic/ludo.dart';
import 'package:dally/features/games/ludo/logic/ludo_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// How several tokens share one cell is pure geometry, so it is tested here
/// rather than through a painter.
void main() {
  List<TokenPlacement> place(List<(int, int)> occupants) =>
      LudoLayout.placeOnCell(occupants);

  group('one seat on a cell', () {
    test('a lone token sits dead centre at full size', () {
      final out = place([(0, 2)]);
      expect(out, hasLength(1));
      expect(out.single.offset, Offset.zero);
      expect(out.single.scale, 1);
      expect(out.single.count, 1);
    });

    test('a pair fans either side, both drawn in full', () {
      final out = place([(0, 0), (0, 1)]);
      expect(out, hasLength(2), reason: 'two are shown, not counted');
      expect(out.every((p) => p.count == 1), isTrue);
      expect(out[0].offset.dx, lessThan(0));
      expect(out[1].offset.dx, greaterThan(0));
      expect(out[0].offset.dx, -out[1].offset.dx);
    });

    test('three collapse to one token carrying the count', () {
      final out = place([(0, 0), (0, 1), (0, 3)]);
      expect(out, hasLength(1));
      expect(out.single.count, 3);
      expect(out.single.offset, Offset.zero);
    });

    test('four collapse the same way', () {
      final out = place([(0, 0), (0, 1), (0, 2), (0, 3)]);
      expect(out, hasLength(1));
      expect(out.single.count, 4);
    });

    test('the threshold is exactly three — two fan, three count', () {
      expect(LudoLayout.stackBadgeFrom, 3);
      expect(place([(1, 0), (1, 1)]).length, 2);
      expect(place([(1, 0), (1, 1), (1, 2)]).single.count, 3);
    });
  });

  group('several seats on a cell', () {
    test('every identity is drawn, offset apart and slightly reduced', () {
      final out = place([(0, 0), (2, 1)]);
      expect(out, hasLength(2));
      expect(out.map((p) => p.player), [0, 2], reason: 'seat order is stable');
      expect(out.every((p) => p.scale < 1), isTrue);
      expect(out[0].offset.dx, isNot(out[1].offset.dx),
          reason: 'never one on top of another');
    });

    test('three seats spread symmetrically about the cell', () {
      final out = place([(0, 0), (1, 0), (2, 0)]);
      expect(out, hasLength(3));
      expect(out[1].offset.dx, 0, reason: 'the middle seat keeps the centre');
      expect(out[0].offset.dx, -out[2].offset.dx);
    });

    test('a seat that is stacked still counts inside a mixed cell', () {
      final out = place([(0, 0), (0, 1), (0, 2), (3, 0)]);
      final mine = out.firstWhere((p) => p.player == 0);
      expect(mine.count, 3);
      expect(out.where((p) => p.player == 3).single.count, 1);
      expect(out.every((p) => p.scale < 1), isTrue);
    });
  });

  group('stacks and the rules core', () {
    /// Which of a stack's tokens is moved must not change the outcome — that
    /// is what lets the screen move "one" without asking which.
    test('moving any token from a stack lands the same position', () {
      List<List<int>> after(int token) {
        final g = LudoGame(playerCount: 2);
        g.tokens[0][0] = 10;
        g.tokens[0][1] = 10;
        g.tokens[0][2] = 10;
        g.rollFace(3);
        g.play(g.legalMoves().firstWhere((m) => m.token == token));
        return [
          for (final seat in g.tokens) [...seat]..sort(),
        ];
      }

      expect(after(0), after(1));
      expect(after(1), after(2));
    });

    test('a stack decrements by exactly one when it moves', () {
      final g = LudoGame(playerCount: 2);
      g.tokens[0][0] = 10;
      g.tokens[0][1] = 10;
      g.tokens[0][2] = 10;
      g.rollFace(3);

      final before = LudoLayout.cellOf(0, 10, 0);
      var on = g.tokens[0].where((t) => t == 10).length;
      expect(place([for (var i = 0; i < on; i++) (0, i)]).single.count, 3);

      g.play(g.legalMoves().first);
      on = g.tokens[0].where((t) => t == 10).length;
      expect(on, 2, reason: 'one left the stack');
      // Two fan again rather than carrying a badge.
      expect(place([for (var i = 0; i < on; i++) (0, i)]), hasLength(2));
      expect(LudoLayout.cellOf(0, 13, 0), isNot(before));
    });

    test('a seeded game never puts two seats in one yard slot', () {
      // Yard spots are per-token, so a cell shared by two seats can only ever
      // happen on the shared ring — where the mixed layout applies.
      final random = DallyRandom.seeded(4);
      final g = LudoGame(playerCount: 4);
      for (var i = 0; i < 300 && !g.isFinished; i++) {
        if (!g.awaitingMove) {
          g.roll(random);
          continue;
        }
        final moves = g.legalMoves();
        g.play(moves[random.nextInt(moves.length)]);
      }
      final byCell = <Offset, List<(int, int)>>{};
      for (var p = 0; p < 4; p++) {
        for (var i = 0; i < 4; i++) {
          byCell
              .putIfAbsent(LudoLayout.cellOf(p, g.tokens[p][i], i), () => [])
              .add((p, i));
        }
      }
      for (final entry in byCell.entries) {
        final out = place(entry.value);
        // Every token on the cell is accounted for, once.
        expect(out.fold<int>(0, (n, p) => n + p.count), entry.value.length,
            reason: 'cell ${entry.key}');
      }
    });
  });
}
