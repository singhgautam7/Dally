import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/ludo/logic/ludo.dart';
import 'package:dally/features/games/ludo/logic/ludo_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Puts the game under a specific face without fishing for it in a stream.
void forceRoll(LudoGame g, int face) => g.rollFace(face);

void main() {
  group('board geometry', () {
    test('the ring is 52 distinct cells', () {
      expect(LudoLayout.ring, hasLength(kRingSquares));
      expect(LudoLayout.ring.toSet(), hasLength(kRingSquares));
    });

    test('each seat enters a quarter turn apart', () {
      for (var p = 0; p < 4; p++) {
        expect(ringStart(p), p * 13);
        expect(ringIndexOf(p, 1), p * 13);
      }
    });

    test('a full lap of 51 steps stops one short of the start', () {
      for (var p = 0; p < 4; p++) {
        expect(ringIndexOf(p, kLastRingStep), (ringStart(p) + 50) % kRingSquares);
      }
    });

    test('home columns and yards never collide with the ring', () {
      final ring = LudoLayout.ring.toSet();
      for (var p = 0; p < 4; p++) {
        expect(LudoLayout.homeColumn(p), hasLength(5));
        for (final cell in LudoLayout.homeColumn(p)) {
          expect(ring.contains(cell), isFalse, reason: 'home column overlaps the ring');
        }
      }
    });

    test('every step of a journey maps to a cell', () {
      for (var step = 1; step <= kHome; step++) {
        final cell = LudoLayout.cellOf(0, step, 0);
        expect(cell.dx, inInclusiveRange(0, LudoLayout.gridSize.toDouble()));
        expect(cell.dy, inInclusiveRange(0, LudoLayout.gridSize.toDouble()));
      }
    });
  });

  group('leaving the yard', () {
    test('only a six opens the gate by default', () {
      final g = LudoGame(playerCount: 2);
      forceRoll(g, 3);
      expect(g.stuck, isTrue, reason: 'nothing can move on a 3 from four tokens in base');
      expect(g.current, 1, reason: 'the turn passed');
    });

    test('a six puts a token on the entry square', () {
      final g = LudoGame(playerCount: 2);
      forceRoll(g, 6);
      final moves = g.legalMoves();
      expect(moves, hasLength(4), reason: 'any of the four may come out');
      expect(moves.every((m) => m.leavesBase && m.to == 1), isTrue);
      g.play(moves.first);
      expect(g.tokens[0][0], 1);
      expect(g.current, 0, reason: 'a six is rolled again');
    });

    test('the rule can be switched off', () {
      final g = LudoGame(playerCount: 2, rules: const LudoRules(sixToLeaveBase: false));
      forceRoll(g, 2);
      expect(g.legalMoves(), hasLength(4));
    });
  });

  group('captures', () {
    test('landing on an opponent sends it back to the yard', () {
      final g = LudoGame(playerCount: 2);
      // Seat 1 sits on ring 20; seat 0 needs step 21 to land there.
      g.tokens[1][0] = 20 - ringStart(1) + 1; // seat 1's step for ring 20
      expect(ringIndexOf(1, g.tokens[1][0]), 20);
      g.tokens[0][0] = 18;
      forceRoll(g, 3);
      final move = g.legalMoves().firstWhere((m) => m.token == 0);
      expect(ringIndexOf(0, move.to), 20);
      expect(move.captured, [(1, 0)]);
      g.play(move);
      expect(g.tokens[1][0], kInBase);
      expect(g.current, 0, reason: 'a capture earns another turn');
    });

    test('a safe square cannot be captured on', () {
      final g = LudoGame(playerCount: 2);
      // Ring 21 is a star square.
      expect(kSafeRingSquares.contains(21), isTrue);
      g.tokens[1][0] = 21 - ringStart(1) + 1;
      expect(ringIndexOf(1, g.tokens[1][0]), 21);
      g.tokens[0][0] = 19;
      forceRoll(g, 3);
      final move = g.legalMoves().firstWhere((m) => m.token == 0);
      expect(ringIndexOf(0, move.to), 21);
      expect(move.captured, isEmpty);
      g.play(move);
      expect(g.tokens[1][0], isNot(kInBase));
    });

    test('nothing in a home column is reachable', () {
      final g = LudoGame(playerCount: 2);
      g.tokens[1][0] = 53; // seat 1, home column
      g.tokens[0][0] = 50;
      forceRoll(g, 3);
      final move = g.legalMoves().firstWhere((m) => m.token == 0);
      expect(move.captured, isEmpty);
    });
  });

  group('the home column', () {
    test('an exact count is needed to finish', () {
      final g = LudoGame(playerCount: 2);
      g.tokens[0][0] = 55;
      forceRoll(g, 4);
      expect(g.legalMoves().where((m) => m.token == 0), isEmpty,
          reason: '55 + 4 overshoots 57');
      // 2 lands exactly.
      final h = LudoGame(playerCount: 2);
      h.tokens[0][0] = 55;
      forceRoll(h, 2);
      final move = h.legalMoves().firstWhere((m) => m.token == 0);
      expect(move.to, kHome);
      expect(move.finishes, isTrue);
    });

    test('the exact rule can be switched off', () {
      final g = LudoGame(playerCount: 2, rules: const LudoRules(exactFinish: false));
      g.tokens[0][0] = 55;
      forceRoll(g, 4);
      expect(g.legalMoves().firstWhere((m) => m.token == 0).to, kHome);
    });

    test('a seat never stacks two tokens on one square', () {
      final g = LudoGame(playerCount: 2);
      g.tokens[0][0] = 10;
      g.tokens[0][1] = 13;
      forceRoll(g, 3);
      expect(g.legalMoves().where((m) => m.token == 0), isEmpty);
    });
  });

  group('turn order', () {
    test('a dead roll passes the turn but keeps the die on show', () {
      final g = LudoGame(playerCount: 3);
      forceRoll(g, 1);
      expect(g.stuck, isTrue);
      expect(g.die, 1);
      expect(g.awaitingMove, isFalse);
      expect(g.current, 1);
    });

    test('three sixes in a row forfeit the turn', () {
      final g = LudoGame(playerCount: 2);
      g.tokens[0][0] = 10;
      forceRoll(g, 6);
      g.play(g.legalMoves().firstWhere((m) => m.token == 0));
      expect(g.current, 0);
      forceRoll(g, 6);
      g.play(g.legalMoves().firstWhere((m) => m.token == 0));
      expect(g.current, 0);
      forceRoll(g, 6);
      expect(g.stuck, isTrue, reason: 'the third six is forfeited');
      expect(g.current, 1);
    });

    test('an ordinary move hands the turn on', () {
      final g = LudoGame(playerCount: 4);
      g.tokens[0][0] = 10;
      forceRoll(g, 2);
      g.play(g.legalMoves().first);
      expect(g.current, 1);
    });
  });

  group('winning', () {
    test('the seat that brings all four home wins and the game stops', () {
      final g = LudoGame(playerCount: 2);
      g.tokens[0] = [kHome, kHome, kHome, 55];
      forceRoll(g, 2);
      final turn = g.play(g.legalMoves().single)!;
      expect(turn.playerFinished, isTrue);
      expect(turn.winner, 0);
      expect(g.isFinished, isTrue);
      expect(g.homeCount(0), 4);
      expect(() => g.roll(DallyRandom.seeded(1)), throwsStateError);
    });
  });

  test('a seeded game replays move for move', () {
    List<List<int>> playOut(int seed) {
      final random = DallyRandom.seeded(seed);
      final g = LudoGame(playerCount: 4);
      for (var i = 0; i < 400 && !g.isFinished; i++) {
        if (!g.awaitingMove) {
          g.roll(random);
          continue;
        }
        final moves = g.legalMoves();
        g.play(moves[random.nextInt(moves.length)]);
      }
      return [for (final seat in g.tokens) [...seat]];
    }

    expect(playOut(7), playOut(7));
    expect(playOut(7), isNot(playOut(8)));
  });
}
