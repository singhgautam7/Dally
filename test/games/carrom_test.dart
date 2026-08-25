import 'dart:ui';

import 'package:dally/features/games/carrom/logic/carrom_game.dart';
import 'package:dally/features/games/carrom/logic/carrom_table.dart';
import 'package:flutter_test/flutter_test.dart';

CarromTable bare() => CarromTable();

Disc coin(Offset at, {CoinKind kind = CoinKind.light, Offset v = Offset.zero}) =>
    Disc(kind: kind, position: at, radius: 0.024, mass: 1, velocity: v);

Disc striker(Offset at, {Offset v = Offset.zero}) =>
    Disc(kind: CoinKind.striker, position: at, radius: 0.032, mass: 1.6, velocity: v);

void main() {
  group('the solver', () {
    test('is deterministic — the same shot lands in the same place', () {
      List<Offset> run() {
        final table = bare()
          ..discs.addAll([striker(const Offset(0.5, 0.86)), coin(const Offset(0.5, 0.5))]);
        table.shoot(const Offset(0, -1), 0.8);
        table.settle();
        return [for (final d in table.discs) d.position];
      }

      final a = run();
      final b = run();
      for (var i = 0; i < a.length; i++) {
        expect(a[i].dx, moreOrLessEquals(b[i].dx, epsilon: 1e-12));
        expect(a[i].dy, moreOrLessEquals(b[i].dy, epsilon: 1e-12));
      }
    });

    test('friction always brings the table to rest', () {
      final table = bare()..discs.add(striker(const Offset(0.5, 0.5)));
      table.shoot(const Offset(1, 0.4), 1);
      final steps = table.settle();
      expect(table.atRest, isTrue);
      expect(steps, lessThan(2000), reason: 'the shot must terminate on its own');
    });

    test('nothing ever leaves the board', () {
      final table = bare()
        ..discs.addAll([
          striker(const Offset(0.5, 0.9)),
          for (var i = 0; i < 6; i++)
            coin(Offset(0.3 + i * 0.08, 0.45 + (i.isEven ? 0.03 : -0.03))),
        ]);
      table.shoot(const Offset(0.2, -1), 1);
      for (var step = 0; step < 400; step++) {
        table.step(1 / 62.5);
        for (final d in table.live) {
          expect(d.position.dx, inInclusiveRange(-1e-9, 1 + 1e-9));
          expect(d.position.dy, inInclusiveRange(-1e-9, 1 + 1e-9));
        }
      }
    });

    test('a head-on hit passes the motion along', () {
      final table = bare()
        ..discs.addAll([striker(const Offset(0.5, 0.9)), coin(const Offset(0.5, 0.5))]);
      table.shoot(const Offset(0, -1), 0.9);
      table.settle();
      final target = table.discs[1];
      expect(target.position.dy, lessThan(0.5), reason: 'the coin was driven forward');
    });

    test('a striker at full speed cannot pass through a coin', () {
      final table = bare()
        ..discs.addAll([striker(const Offset(0.5, 0.95)), coin(const Offset(0.5, 0.5))]);
      table.shoot(const Offset(0, -1), 1);
      table.settle();
      expect(table.discs[1].velocity, Offset.zero);
      expect(table.discs[1].position, isNot(const Offset(0.5, 0.5)),
          reason: 'the coin was hit, not tunnelled through');
    });

    test('a disc that reaches a pocket goes down and leaves play', () {
      final table = bare()..discs.add(coin(const Offset(0.12, 0.12)));
      table.discs.first.velocity = const Offset(-0.4, -0.4);
      table.settle();
      expect(table.discs.first.pocketed, isTrue);
      expect(table.pocketedThisShot, hasLength(1));
      expect(table.live, isEmpty);
    });

    test('touching nothing is noticed', () {
      final table = bare()..discs.add(striker(const Offset(0.5, 0.9)));
      table.shoot(const Offset(1, 0), 0.3);
      table.settle();
      expect(table.strikerTouchedCoin, isFalse);

      final hit = bare()
        ..discs.addAll([striker(const Offset(0.5, 0.9)), coin(const Offset(0.5, 0.5))]);
      hit.shoot(const Offset(0, -1), 0.9);
      hit.settle();
      expect(hit.strikerTouchedCoin, isTrue);
    });
  });

  group('the board setup', () {
    test('nineteen coins, nine a side plus the queen, none overlapping', () {
      final game = CarromGame();
      final coins = game.table.discs.where((d) => d.isCoin).toList();
      expect(coins, hasLength(19));
      expect(coins.where((d) => d.kind == CoinKind.light), hasLength(9));
      expect(coins.where((d) => d.kind == CoinKind.dark), hasLength(9));
      expect(coins.where((d) => d.kind == CoinKind.queen), hasLength(1));

      for (var i = 0; i < coins.length; i++) {
        for (var j = i + 1; j < coins.length; j++) {
          expect((coins[i].position - coins[j].position).distance,
              greaterThan(coins[i].radius + coins[j].radius - 1e-9),
              reason: 'the opening layout overlaps');
        }
      }
    });

    test('the opening layout is already at rest', () {
      expect(CarromGame().table.atRest, isTrue);
    });

    test('each seat has its own baseline and the striker starts on it', () {
      final game = CarromGame(playerCount: 4);
      for (var p = 0; p < 4; p++) {
        final home = game.strikerHome(p);
        expect(game.clampToBaseline(p, home), home);
        // Far off the line comes back onto it.
        final clamped = game.clampToBaseline(p, const Offset(0.99, 0.99));
        if (game.baselineIsHorizontal(p)) {
          expect(clamped.dy, home.dy);
          expect(clamped.dx, lessThanOrEqualTo(0.5 + CarromGame.baselineHalfLength));
        } else {
          expect(clamped.dx, home.dx);
          expect(clamped.dy, lessThanOrEqualTo(0.5 + CarromGame.baselineHalfLength));
        }
      }
      expect(game.table.striker!.position, game.strikerHome(0));
    });
  });

  group('turns and fouls', () {
    /// Pockets [count] coins of [kind] outright, as if the shot had done it.
    void pot(CarromGame game, CoinKind kind, int count) {
      for (final disc in game.table.discs) {
        if (count == 0) break;
        if (disc.kind == kind && !disc.pocketed) {
          disc.pocketed = true;
          game.table.pocketedThisShot.add(disc);
          count--;
        }
      }
      game.table.strikerTouchedCoin = true;
    }

    test('potting your own coin keeps the turn', () {
      final game = CarromGame();
      pot(game, CoinKind.light, 1);
      final outcome = game.resolveShot();
      expect(outcome.ownPotted, 1);
      expect(outcome.extraTurn, isTrue);
      expect(game.current, 0);
      expect(game.banked[0], 1);
    });

    test('potting nothing passes the turn', () {
      final game = CarromGame();
      game.table.strikerTouchedCoin = true;
      final outcome = game.resolveShot();
      expect(outcome.extraTurn, isFalse);
      expect(game.current, 1);
    });

    test('an opponent coin counts for them', () {
      final game = CarromGame();
      pot(game, CoinKind.dark, 1);
      final outcome = game.resolveShot();
      expect(outcome.opponentPotted, 1);
      expect(game.banked[1], 1);
      expect(game.current, 1, reason: 'and the turn still passes');
    });

    test('a shot that touches nothing is a foul', () {
      final game = CarromGame();
      game.table.strikerTouchedCoin = false;
      final outcome = game.resolveShot();
      expect(outcome.touchedNothing, isTrue);
      expect(outcome.isFoul, isTrue);
    });

    test('potting the striker returns a coin and costs the turn', () {
      final game = CarromGame();
      pot(game, CoinKind.light, 2);
      game.resolveShot();
      expect(game.banked[0], 2);

      final striker = game.table.discs.firstWhere((d) => d.kind == CoinKind.striker);
      striker.pocketed = true;
      game.table.pocketedThisShot.add(striker);
      game.table.strikerTouchedCoin = true;
      final outcome = game.resolveShot();
      expect(outcome.strikerPotted, isTrue);
      expect(outcome.isFoul, isTrue);
      expect(game.banked[0], 1, reason: 'one banked coin goes back on the board');
      expect(game.table.discs.where((d) => d.kind == CoinKind.light && !d.pocketed),
          hasLength(8));
      expect(game.table.striker, isNotNull, reason: 'the striker is back in play');
      expect(game.current, 1);
    });

    test('a returned coin never lands on top of another', () {
      final game = CarromGame();
      pot(game, CoinKind.light, 1);
      game.resolveShot();
      final striker = game.table.discs.firstWhere((d) => d.kind == CoinKind.striker);
      striker.pocketed = true;
      game.table.pocketedThisShot.add(striker);
      game.resolveShot();
      final live = game.table.live.where((d) => d.isCoin).toList();
      for (var i = 0; i < live.length; i++) {
        for (var j = i + 1; j < live.length; j++) {
          expect((live[i].position - live[j].position).distance,
              greaterThan(live[i].radius + live[j].radius - 1e-9));
        }
      }
    });
  });

  group('the queen', () {
    void potQueen(CarromGame game) {
      final queen = game.table.discs.firstWhere((d) => d.kind == CoinKind.queen);
      queen.pocketed = true;
      game.table.pocketedThisShot.add(queen);
      game.table.strikerTouchedCoin = true;
    }

    void potOwn(CarromGame game, CoinKind kind) {
      final coin = game.table.discs.firstWhere((d) => d.kind == kind && !d.pocketed);
      coin.pocketed = true;
      game.table.pocketedThisShot.add(coin);
      game.table.strikerTouchedCoin = true;
    }

    test('covered on the same shot, the queen is yours', () {
      final game = CarromGame();
      potQueen(game);
      potOwn(game, CoinKind.light);
      game.resolveShot();
      expect(game.queenOwner, 0);
      expect(game.queenPending, isNull);
    });

    test('uncovered, the queen waits for the next shot', () {
      final game = CarromGame();
      potQueen(game);
      final first = game.resolveShot();
      expect(first.queenPotted, isTrue);
      expect(game.queenPending, 0);
      expect(game.queenOwner, isNull);
      expect(game.current, 1, reason: 'the queen alone does not keep the turn');
    });

    test('a missed cover puts the queen back on the board', () {
      final game = CarromGame();
      potQueen(game);
      game.resolveShot();
      game.current = 0; // the same team shoots again
      game.table.strikerTouchedCoin = true;
      final second = game.resolveShot();
      expect(second.queenReturned, isTrue);
      expect(game.queenPending, isNull);
      expect(game.queenOwner, isNull);
      final queen = game.table.discs.firstWhere((d) => d.kind == CoinKind.queen);
      expect(queen.pocketed, isFalse);
    });

    test('the cover rule can be switched off', () {
      final game = CarromGame(rules: const CarromRules(queenMustBeCovered: false));
      potQueen(game);
      game.resolveShot();
      expect(game.queenOwner, 0);
    });
  });

  group('winning', () {
    test('nine coins and a settled queen takes the board', () {
      final game = CarromGame(rules: const CarromRules(queenMustBeCovered: false));
      for (final disc in game.table.discs) {
        if (disc.kind == CoinKind.light) {
          disc.pocketed = true;
          game.table.pocketedThisShot.add(disc);
        }
      }
      game.table.strikerTouchedCoin = true;
      final outcome = game.resolveShot();
      expect(outcome.winner, 0);
      expect(game.isFinished, isTrue);
      expect(game.awaitingShot, isFalse);
    });

    test('with the cover rule on, an unclaimed queen holds the win back', () {
      final game = CarromGame();
      for (final disc in game.table.discs) {
        if (disc.kind == CoinKind.light) {
          disc.pocketed = true;
          game.table.pocketedThisShot.add(disc);
        }
      }
      game.table.strikerTouchedCoin = true;
      expect(game.resolveShot().winner, isNull);
      expect(game.isFinished, isFalse);
    });
  });
}
