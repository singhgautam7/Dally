import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/snakes_and_ladders/logic/snakes_and_ladders.dart';
import 'package:flutter_test/flutter_test.dart';

SnakesAndLaddersGame game({
  int players = 2,
  int columns = 10,
  int rows = 10,
  List<Link> links = const [],
}) =>
    SnakesAndLaddersGame(
        playerCount: players, columns: columns, rows: rows, links: links);

void main() {
  group('numbering', () {
    test('square 1 is bottom-left and the last square is top-something', () {
      final g = game();
      expect(g.cellOf(1), (0, 9));
      expect(g.cellOf(10), (9, 9));
      expect(g.cellOf(11), (9, 8), reason: 'the next row runs back the other way');
      expect(g.cellOf(20), (0, 8));
      expect(g.cellOf(100).$2, 0);
    });

    test('every square maps to a distinct cell, on every board size', () {
      for (final (c, r) in const [(6, 6), (8, 8), (10, 10)]) {
        final g = game(columns: c, rows: r);
        final cells = {for (var s = 1; s <= g.squares; s++) g.cellOf(s)};
        expect(cells, hasLength(g.squares));
      }
    });
  });

  group('movement', () {
    test('a token walks the die and stops', () {
      final g = game();
      final turn = g.rollFace(4);
      expect(turn.from, 1);
      expect(turn.to, 5);
      expect(g.positions[0], 5);
      expect(g.current, 1, reason: 'the turn passes');
    });

    test('an overshoot stays put — the last square needs an exact count', () {
      final g = game();
      g.positions[0] = 98;
      final turn = g.rollFace(4);
      expect(turn.bounced, isTrue);
      expect(g.positions[0], 98);
      expect(g.isFinished, isFalse);
    });
  });

  group('links', () {
    test('a ladder foot climbs', () {
      final g = game(links: const [Link(4, 40)]);
      final turn = g.rollFace(3);
      expect(turn.landed, 4);
      expect(turn.link, const Link(4, 40));
      expect(turn.link!.isLadder, isTrue);
      expect(g.positions[0], 40);
    });

    test('a snake head slides', () {
      final g = game(links: const [Link(6, 2)]);
      final turn = g.rollFace(5);
      expect(turn.link!.isLadder, isFalse);
      expect(g.positions[0], 2);
    });

    test('a link only fires on the square it is anchored to', () {
      final g = game(links: const [Link(4, 40)]);
      g.rollFace(2);
      expect(g.positions[0], 3);
    });
  });

  group('winning', () {
    test('reaching the last square exactly ends the game', () {
      final g = game();
      g.positions[0] = 97;
      final turn = g.rollFace(3);
      expect(turn.won, isTrue);
      expect(g.winner, 0);
      expect(g.current, 0, reason: 'the turn stays with the winner');
      expect(() => g.rollFace(1), throwsStateError);
    });

    test('a ladder into the last square also wins', () {
      final g = game(links: const [Link(5, 100)]);
      final turn = g.rollFace(4);
      expect(turn.won, isTrue);
      expect(g.winner, 0);
    });
  });

  group('generation', () {
    test('the same seed builds the same board', () {
      List<Link> build(int seed) =>
          generateLinks(DallyRandom.seeded(seed), columns: 10, rows: 10);
      expect(build(3), build(3));
      expect(build(3), isNot(build(4)));
    });

    test('every endpoint is distinct, so no roll ever resolves twice', () {
      for (var seed = 0; seed < 40; seed++) {
        for (final (c, r) in const [(6, 6), (8, 8), (10, 10)]) {
          final links = generateLinks(DallyRandom.seeded(seed), columns: c, rows: r);
          final endpoints = <int>[];
          for (final l in links) {
            endpoints..add(l.from)..add(l.to);
          }
          expect(endpoints.toSet(), hasLength(endpoints.length),
              reason: 'seed $seed on ${c}x$r reused an endpoint');
          expect(endpoints, isNot(contains(1)));
          expect(endpoints, isNot(contains(c * r)));
        }
      }
    });

    test('every link spans at least two rows and points the right way', () {
      for (var seed = 0; seed < 40; seed++) {
        final links = generateLinks(DallyRandom.seeded(seed), columns: 10, rows: 10);
        expect(links, isNotEmpty);
        for (final l in links) {
          final fromRow = (l.from - 1) ~/ 10;
          final toRow = (l.to - 1) ~/ 10;
          expect((toRow - fromRow).abs(), greaterThanOrEqualTo(2));
        }
        expect(links.any((l) => l.isLadder), isTrue);
        expect(links.any((l) => !l.isLadder), isTrue);
      }
    });

    test('a generated board is always finishable', () {
      // Walking only ladders and plain steps must reach the last square.
      for (var seed = 0; seed < 20; seed++) {
        final random = DallyRandom.seeded(seed);
        final g = SnakesAndLaddersGame(
          playerCount: 2,
          columns: 10,
          rows: 10,
          links: generateLinks(DallyRandom.seeded(seed), columns: 10, rows: 10),
        );
        var guard = 0;
        while (!g.isFinished && guard++ < 4000) {
          g.roll(random);
        }
        expect(g.isFinished, isTrue, reason: 'seed $seed never ended');
      }
    });
  });
}
