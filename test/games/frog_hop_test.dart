import 'package:dally/features/games/frog_hop/logic/frog_hop.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure rules, no widgets, no clock, no randomness — so every case here is
/// exact rather than sampled.
void main() {
  group('the deal', () {
    test('both blocks start at their own end with one empty cell between', () {
      final g = FrogHopGame(perSide: 3);
      expect(g.length, 7);
      expect([for (var i = 0; i < g.length; i++) g.at(i)], [
        FrogSide.bottom,
        FrogSide.bottom,
        FrogSide.bottom,
        null,
        FrogSide.top,
        FrogSide.top,
        FrogSide.top,
      ]);
    });

    test('the lane is both blocks plus the gaps between them', () {
      for (final n in [1, 3, 4, 5]) {
        expect(FrogHopGame(perSide: n).length, n * 2 + 1, reason: '$n a side');
        expect(FrogHopGame(perSide: n, gaps: 3).length, n * 2 + 3, reason: '$n a side');
      }
    });

    test('a race lane deals both blocks to their own ends, gaps between', () {
      final g = FrogHopGame(perSide: 3, gaps: 3);
      expect([for (var i = 0; i < g.length; i++) g.at(i)], [
        FrogSide.bottom,
        FrogSide.bottom,
        FrogSide.bottom,
        null,
        null,
        null,
        FrogSide.top,
        FrogSide.top,
        FrogSide.top,
      ]);
    });

    test('nobody starts home, and both goals are the far cells', () {
      final g = FrogHopGame(perSide: 3);
      expect(g.homeCount(FrogSide.bottom), 0);
      expect(g.homeCount(FrogSide.top), 0);
      expect(g.homeCells(FrogSide.bottom).toList(), [6, 5, 4]);
      expect(g.homeCells(FrogSide.top).toList(), [0, 1, 2]);
    });
  });

  group('legal moves', () {
    test('a step goes into the empty cell directly ahead', () {
      final g = FrogHopGame(perSide: 3);
      // Cell 2 is bottom's leading piece; cell 3 is empty.
      expect(g.movesFrom(2), [
        const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step),
      ]);
    });

    test('a jump clears exactly one neighbour into the empty cell beyond', () {
      final g = FrogHopGame(perSide: 3);
      // Top's leading piece at 4 jumps bottom's at 3 once bottom has stepped.
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      expect(g.movesFrom(4), [
        const FrogMove(from: 4, to: 2, kind: FrogMoveKind.jump),
      ]);
      expect(const FrogMove(from: 4, to: 2, kind: FrogMoveKind.jump).over, 3);
    });

    test('a piece with no empty cell within two ahead has no move', () {
      final g = FrogHopGame(perSide: 3);
      // Cell 0: ahead (1) is occupied and beyond (2) is occupied too, so there
      // is nowhere to land. Cell 1 *can* jump its own neighbour into cell 3.
      expect(g.movesFrom(0), isEmpty);
      expect(g.movesFrom(1), [
        const FrogMove(from: 1, to: 3, kind: FrogMoveKind.jump),
      ]);
    });

    test('nothing moves backwards', () {
      final g = FrogHopGame(perSide: 3);
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      // Bottom's piece is now at 3 and cell 2 is empty — but it cannot go back.
      expect(g.movesFrom(3).every((m) => m.to > 3), isTrue);
    });

    test('a jump over two pieces is not a move', () {
      final g = FrogHopGame(perSide: 3);
      // Cell 1 is bottom, 2 is bottom, 3 empty: 1 cannot jump to 3 over one…
      // it can, because 2 is a single occupied neighbour. Cell 0 cannot reach 2.
      expect(g.movesFrom(1), [
        const FrogMove(from: 1, to: 3, kind: FrogMoveKind.jump),
      ]);
      expect(g.movesFrom(0), isEmpty, reason: 'cell 2 is occupied, so no landing');
    });

    test('an empty cell offers nothing', () {
      expect(FrogHopGame(perSide: 3).movesFrom(3), isEmpty);
    });

    test('a jump may clear either colour', () {
      final g = FrogHopGame(perSide: 3);
      // Own colour: cell 1 jumps its own piece at 2 into the empty 3.
      expect(g.movesFrom(1).single.kind, FrogMoveKind.jump);
      // Opposite colour: after a step, top's 4 jumps bottom's 3.
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      expect(g.movesFrom(4).single.kind, FrogMoveKind.jump);
    });
  });

  group('turns', () {
    test('the turn passes after a move', () {
      final g = FrogHopGame(perSide: 3);
      expect(g.turn, FrogSide.bottom);
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      expect(g.turn, FrogSide.top);
    });

    test('the first side is configurable', () {
      expect(FrogHopGame(perSide: 3, first: FrogSide.top).turn, FrogSide.top);
    });

    test("a move that is not the mover's is refused, and changes nothing", () {
      final g = FrogHopGame(perSide: 3);
      // Top's piece cannot move while bottom is on turn.
      expect(g.play(const FrogMove(from: 4, to: 3, kind: FrogMoveKind.step)), isFalse);
      expect(g.at(4), FrogSide.top);
      expect(g.turn, FrogSide.bottom);
      expect(g.moves, 0);
    });

    test('an illegal move is refused and changes nothing', () {
      final g = FrogHopGame(perSide: 3);
      expect(g.play(const FrogMove(from: 0, to: 1, kind: FrogMoveKind.step)), isFalse);
      expect(g.moves, 0);
    });

    test('the turn changes hands while both sides have something to play', () {
      // One a side: bottom at 0, empty 1, top at 2.
      final g = FrogHopGame(perSide: 1);
      g.play(const FrogMove(from: 0, to: 1, kind: FrogMoveKind.step));
      // Top at 2 can now jump 1 into 0 — so the turn genuinely passes over.
      expect(g.turn, FrogSide.top);
      expect(g.otherSidePassed, isFalse, reason: 'nobody was skipped');
    });

    test('a side with no legal move is skipped, and the strip is told', () {
      final g = FrogHopGame(perSide: 3);
      // Wedge the lane so that after bottom moves, top has nothing to play:
      // three same-colour steps in a row leave top blocked behind a full block.
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      g.play(const FrogMove(from: 4, to: 2, kind: FrogMoveKind.jump));
      g.play(const FrogMove(from: 3, to: 4, kind: FrogMoveKind.step));
      // Whether this particular position skips anyone is a fact of the rules;
      // what must hold is that the flag and the move list never disagree.
      final other = g.turn == FrogSide.bottom ? FrogSide.top : FrogSide.bottom;
      expect(g.otherSidePassed, g.movesFor(other).isEmpty && !g.isOver);
    });
  });

  group('winning', () {
    test('a side wins when every piece is in the far end', () {
      // One a side is the shortest complete race: step, then jump home.
      final g = FrogHopGame(perSide: 1);
      expect(g.winner, isNull);
      g.play(const FrogMove(from: 0, to: 1, kind: FrogMoveKind.step));
      expect(g.winner, isNull);
      g.play(const FrogMove(from: 2, to: 0, kind: FrogMoveKind.jump));
      expect(g.winner, FrogSide.top, reason: 'top filled the bottom end');
      expect(g.isOver, isTrue);
    });

    test('a finished lane refuses further moves', () {
      final g = FrogHopGame(perSide: 1);
      g.play(const FrogMove(from: 0, to: 1, kind: FrogMoveKind.step));
      g.play(const FrogMove(from: 2, to: 0, kind: FrogMoveKind.jump));
      final before = g.moves;
      expect(g.play(const FrogMove(from: 1, to: 2, kind: FrogMoveKind.step)), isFalse);
      expect(g.moves, before);
    });

    test('home counts track the pieces that have arrived', () {
      final g = FrogHopGame(perSide: 3);
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      expect(g.homeCount(FrogSide.bottom), 0);
      g.play(const FrogMove(from: 4, to: 2, kind: FrogMoveKind.jump));
      expect(g.homeCount(FrogSide.top), 1, reason: 'cell 2 is one of top\'s home cells');
    });

    test('a full race from the start terminates and someone wins or it draws', () {
      // Drive the lane with a fixed policy — jumps first, then steps — which is
      // deterministic and needs no RNG.
      final g = FrogHopGame(perSide: 3);
      var guard = 0;
      while (!g.isOver && guard++ < 200) {
        final moves = g.legalMoves;
        if (moves.isEmpty) break;
        final jump = moves.where((m) => m.kind == FrogMoveKind.jump).firstOrNull;
        g.play(jump ?? moves.first);
      }
      expect(g.isOver, isTrue, reason: 'the race must terminate');
      expect(guard, lessThan(200));
    });
  });

  group('undo', () {
    test('one step back restores the exact prior lane and the turn', () {
      final g = FrogHopGame(perSide: 3);
      final before = g.snapshot();
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      expect(g.turn, FrogSide.top);

      g.restore(before);
      expect(g.at(2), FrogSide.bottom);
      expect(g.at(3), isNull);
      expect(g.turn, FrogSide.bottom);
      expect(g.moves, 0);
      expect(g.jumps, 0);
    });

    test('a jump comes back, chain counter included', () {
      final g = FrogHopGame(perSide: 3);
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      final before = g.snapshot();
      g.play(const FrogMove(from: 4, to: 2, kind: FrogMoveKind.jump));
      expect(g.jumps, 1);
      expect(g.longestJumpChain, 1);

      g.restore(before);
      expect(g.jumps, 0);
      expect(g.longestJumpChain, 0);
      expect(g.at(4), FrogSide.top);
      expect(g.at(2), isNull);
    });

    test('a snapshot is independent of the live lane', () {
      final g = FrogHopGame(perSide: 3);
      final snapshot = g.snapshot();
      g.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      expect(snapshot.cells[2], FrogSide.bottom);
      expect(snapshot.cells[3], isNull);
    });

    test('walking several steps back lands on each earlier position exactly', () {
      final g = FrogHopGame(perSide: 3);
      final history = <FrogSnapshot>[];
      for (var i = 0; i < 4 && !g.isOver; i++) {
        history.add(g.snapshot());
        g.play(g.legalMoves.first);
      }
      for (final s in history.reversed) {
        g.restore(s);
        expect([for (var i = 0; i < g.length; i++) g.at(i)], s.cells);
        expect(g.turn, s.turn);
      }
    });
  });

  group('the race is a race', () {
    // What the one-gap lane actually was: unwinnable, and routinely one-sided.
    // These walk the *whole* reachable state space, so they are proofs rather
    // than samples.
    ({int wins, int deadlocks, bool bothSidesAlwaysMove}) explore(
        int perSide, int gaps) {
      String key(FrogHopGame g) =>
          [for (var i = 0; i < g.length; i++) g.at(i)?.name[0] ?? '.'].join() +
          g.turn.name[0];

      final start = FrogHopGame(perSide: perSide, gaps: gaps);
      final seen = <String>{key(start)};
      final queue = <FrogSnapshot>[start.snapshot()];
      final scratch = FrogHopGame(perSide: perSide, gaps: gaps);
      final moversSeen = <FrogSide>{};
      var wins = 0, deadlocks = 0;

      while (queue.isNotEmpty) {
        final s = queue.removeAt(0);
        scratch.restore(s);
        if (scratch.winner != null) {
          wins++;
          continue;
        }
        final moves = scratch.legalMoves;
        if (moves.isEmpty) {
          deadlocks++;
          continue;
        }
        moversSeen.add(scratch.turn);
        for (final m in moves) {
          scratch.restore(s);
          scratch.play(m);
          if (seen.add(key(scratch))) queue.add(scratch.snapshot());
        }
      }
      return (
        wins: wins,
        deadlocks: deadlocks,
        bothSidesAlwaysMove: moversSeen.length == 2,
      );
    }

    for (final n in [3, 4, 5]) {
      test('$n a side: a one-gap lane cannot be won by anybody', () {
        // Filling your own home on a one-gap lane forces the other side into
        // theirs at the same instant, so "first side home" has no meaning —
        // and a single move can wall the other side out entirely.
        expect(explore(n, 1).wins, 0);
      });

      test('$n a side: the race lane can be won', () {
        final r = explore(n, 3);
        expect(r.wins, greaterThan(0),
            reason: 'a side must be able to finish before the other');
        expect(r.bothSidesAlwaysMove, isTrue,
            reason: 'and both sides must get to play');
      });
    }

    test('both sides get a turn from the very first move', () {
      // The reported bug: bottom moved, bottom moved again, and top never
      // played at all.
      final g = FrogHopGame(perSide: 3, gaps: 3);
      final movers = <FrogSide>{};
      var guard = 0;
      while (!g.isOver && guard++ < 50) {
        final moves = g.legalMoves;
        if (moves.isEmpty) break;
        movers.add(g.turn);
        // The move a hurried player makes: the first one offered.
        g.play(moves.first);
        if (movers.length == 2) break;
      }
      expect(movers, {FrogSide.bottom, FrogSide.top});
    });

    test('a side is only ever skipped when it genuinely cannot move', () {
      final g = FrogHopGame(perSide: 3, gaps: 3);
      var guard = 0;
      while (!g.isOver && guard++ < 60) {
        final moves = g.legalMoves;
        if (moves.isEmpty) break;
        final before = g.turn;
        g.play(moves.first);
        if (g.turn == before && !g.isOver) {
          // The turn stayed put, so the other side must have had nothing.
          final other = before == FrogSide.bottom ? FrogSide.top : FrogSide.bottom;
          expect(g.movesFor(other), isEmpty);
          expect(g.otherSidePassed, isTrue);
        }
      }
    });
  });

  group('the solo puzzle', () {
    test('the minimum is n² + 2n', () {
      expect(FrogPuzzle(perSide: 3).minimumMoves, 15);
      expect(FrogPuzzle(perSide: 4).minimumMoves, 24);
      expect(FrogPuzzle(perSide: 5).minimumMoves, 35);
    });

    test('either side may move — there is no turn order', () {
      final p = FrogPuzzle(perSide: 3);
      // Bottom moves, then bottom again: illegal in a race, fine in the puzzle.
      expect(p.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step)), isTrue);
      expect(p.play(const FrogMove(from: 1, to: 2, kind: FrogMoveKind.step)), isTrue);
      expect(p.moves, 2);
    });

    // The formula is asserted against the rules rather than against a
    // hand-written line of play: a breadth-first search over the puzzle's own
    // move generator finds the true shortest solve, so if either the rules or
    // the formula drifts, this fails.
    for (final n in [1, 2, 3]) {
      test('the shortest solve for $n a side is n² + 2n', () {
        final shortest = _shortestSolve(n);
        expect(shortest, isNotNull, reason: '$n a side must be solvable');
        expect(shortest, FrogPuzzle(perSide: n).minimumMoves);
      });
    }

    test('solved means both blocks have swapped ends', () {
      final p = FrogPuzzle(perSide: 3);
      expect(p.isSolved, isFalse);
      for (final move in _solutionFor(3)) {
        expect(p.play(move), isTrue);
      }
      expect(p.isSolved, isTrue);
      expect(p.moves, 15);
      expect(p.game.homeCount(FrogSide.bottom), 3);
      expect(p.game.homeCount(FrogSide.top), 3);
    });

    test('a stuck lane is stuck, not lost', () {
      // Two same-colour steps in a row wedge the lane for three a side.
      final p = FrogPuzzle(perSide: 3);
      p.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      p.play(const FrogMove(from: 1, to: 2, kind: FrogMoveKind.step));
      var guard = 0;
      while (!p.isStuck && !p.isSolved && guard++ < 100) {
        p.play(p.legalMoves.first);
      }
      // Whatever happens, the puzzle is always one of solved or stuck — never
      // silently unplayable.
      expect(p.isSolved || p.isStuck, isTrue);
    });

    test('undo works the same way in the puzzle', () {
      final p = FrogPuzzle(perSide: 3);
      final before = p.snapshot();
      p.play(const FrogMove(from: 2, to: 3, kind: FrogMoveKind.step));
      p.restore(before);
      expect(p.moves, 0);
      expect(p.game.at(2), FrogSide.bottom);
    });
  });
}

/// Breadth-first over the puzzle's own generator. The state space is tiny (140
/// positions for three a side), so this is exact and instant.
int? _shortestSolve(int perSide) => _search(perSide)?.length;

List<FrogMove> _solutionFor(int perSide) => _search(perSide)!;

List<FrogMove>? _search(int perSide) {
  String key(FrogPuzzle p) => [
        for (var i = 0; i < p.game.length; i++) p.game.at(i)?.name ?? '.',
      ].join();

  final start = FrogPuzzle(perSide: perSide);
  final seen = <String>{key(start)};
  final queue = <(FrogSnapshot, List<FrogMove>)>[(start.snapshot(), const [])];
  final scratch = FrogPuzzle(perSide: perSide);

  while (queue.isNotEmpty) {
    final (state, path) = queue.removeAt(0);
    scratch.restore(state);
    if (scratch.isSolved) return path;
    for (final move in scratch.legalMoves) {
      scratch.restore(state);
      scratch.play(move);
      final k = key(scratch);
      if (seen.add(k)) {
        queue.add((scratch.snapshot(), [...path, move]));
      }
    }
  }
  return null;
}
