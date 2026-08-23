import 'dart:math';

import 'package:dally/features/games/memory/logic/memory_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryGame', () {
    test('deals each symbol exactly twice', () {
      for (final (r, c) in [(4, 4), (4, 6), (6, 6)]) {
        final g = MemoryGame(rows: r, cols: c, rng: Random(1));
        final counts = <int, int>{};
        for (final s in g.symbols) {
          counts[s] = (counts[s] ?? 0) + 1;
        }
        expect(counts.length, g.pairCount);
        expect(counts.values.every((v) => v == 2), isTrue);
      }
    });

    test('flipping the first card reports firstUp and no move', () {
      final g = MemoryGame(rows: 4, cols: 4, rng: Random(1));
      final o = g.flip(0);
      expect(o.kind, FlipKind.firstUp);
      expect(g.moves, 0);
      expect(g.states[0], CardState.faceUp);
    });

    test('a matching pair stays matched and counts a move', () {
      final g = MemoryGame(rows: 4, cols: 4, rng: Random(1));
      // Find the partner of card 0.
      final target = g.symbols[0];
      final partner = g.symbols.indexWhere((s) => s == target, 1);
      g.flip(0);
      final o = g.flip(partner);
      expect(o.kind, FlipKind.match);
      expect(g.moves, 1);
      expect(g.states[0], CardState.matched);
      expect(g.states[partner], CardState.matched);
    });

    test('a mismatch sets busy until resolved', () {
      final g = MemoryGame(rows: 4, cols: 4, rng: Random(1));
      final first = g.symbols[0];
      final nonMatch = g.symbols.indexWhere((s) => s != first);
      g.flip(0);
      final o = g.flip(nonMatch);
      expect(o.kind, FlipKind.miss);
      expect(g.busy, isTrue);
      // Input ignored while busy.
      expect(g.flip(2).kind, FlipKind.ignored);
      g.resolveMiss(o.a!, o.b!);
      expect(g.busy, isFalse);
      expect(g.states[0], CardState.faceDown);
      expect(g.states[nonMatch], CardState.faceDown);
    });

    test('clearing all pairs completes the game', () {
      final g = MemoryGame(rows: 4, cols: 4, rng: Random(2));
      final seen = <int, int>{};
      for (var i = 0; i < g.symbols.length; i++) {
        final s = g.symbols[i];
        if (seen.containsKey(s)) {
          g.flip(seen[s]!);
          final o = g.flip(i);
          expect(o.kind, FlipKind.match);
        } else {
          seen[s] = i;
        }
      }
      expect(g.isComplete, isTrue);
      expect(g.moves, g.pairCount);
    });
  });
}
