import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/quick_play/bottle_spinner/spinner_logic.dart';
import 'package:dally/features/games/quick_play/coin_flip/coin_logic.dart';
import 'package:dally/features/games/quick_play/dice/dice_logic.dart';
import 'package:dally/features/games/quick_play/random_choice/random_choice_logic.dart';
import 'package:dally/features/games/quick_play/random_number/random_number_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Coin Flip', () {
    test('a flip is always one of two faces', () {
      final rng = DallyRandom.seeded(1);
      for (var i = 0; i < 500; i++) {
        expect(CoinFace.values, contains(flipCoins(rng, 1).single));
      }
    });

    test('both faces come up over a long run', () {
      final faces = flipCoins(DallyRandom.seeded(1), 400).toSet();
      expect(faces, {CoinFace.heads, CoinFace.tails});
    });

    test('a batch returns exactly the requested count', () {
      for (final n in [1, 3, 5, 10]) {
        expect(flipCoins(DallyRandom.seeded(2), n).length, n);
      }
    });

    test('the same seed gives the same flips', () {
      expect(flipCoins(DallyRandom.seeded(9), 20), flipCoins(DallyRandom.seeded(9), 20));
    });

    test('the tally counts both faces and the longest run', () {
      var run = const CoinRun();
      expect(run.isEmpty, isTrue);
      for (final f in [
        CoinFace.heads,
        CoinFace.heads,
        CoinFace.heads,
        CoinFace.tails,
        CoinFace.heads,
      ]) {
        run = run.add(f);
      }
      expect(run.heads, 4);
      expect(run.tails, 1);
      expect(run.total, 5);
      expect(run.longestRun, 3);
    });

    test('the run strip keeps only the last twelve', () {
      var run = const CoinRun();
      for (var i = 0; i < 30; i++) {
        run = run.add(CoinFace.heads);
      }
      expect(run.flips.length, 12);
      expect(run.total, 30);
    });

    test('batch helpers describe the throw', () {
      const faces = [CoinFace.heads, CoinFace.heads, CoinFace.tails, CoinFace.heads];
      expect(batchHeadline(faces), '3 heads · 1 tails');
      expect(longestRunIn(faces), 2);
      expect(longestRunIn(const []), 0);
    });
  });

  group('Dice', () {
    test('every die lands in 1..6', () {
      final rng = DallyRandom.seeded(3);
      for (var i = 0; i < 300; i++) {
        for (final v in rollDice(rng, count: 6)) {
          expect(v, inInclusiveRange(1, 6));
        }
      }
    });

    test('the count is honoured', () {
      for (var n = 1; n <= 6; n++) {
        expect(rollDice(DallyRandom.seeded(4), count: n).length, n);
      }
    });

    test('every face appears over a long run', () {
      final seen = <int>{};
      final rng = DallyRandom.seeded(5);
      for (var i = 0; i < 300; i++) {
        seen.addAll(rollDice(rng, count: 6));
      }
      expect(seen, {1, 2, 3, 4, 5, 6});
    });

    test('the total is the sum of the dice', () {
      final values = rollDice(DallyRandom.seeded(6), count: 5);
      expect(diceTotal(values), values.reduce((a, b) => a + b));
      expect(diceTotal(const []), 0);
    });

    test('the same seed gives the same roll', () {
      expect(rollDice(DallyRandom.seeded(7), count: 4),
          rollDice(DallyRandom.seeded(7), count: 4));
    });
  });

  group('Bottle Spinner', () {
    test('the winning seat is always on the ring', () {
      for (var players = 2; players <= 12; players++) {
        for (var seed = 0; seed < 20; seed++) {
          final result = spin(DallyRandom.seeded(seed), players);
          expect(result.seatIndex, inInclusiveRange(0, players - 1));
          expect(result.turns, inInclusiveRange(3, 5));
        }
      }
    });

    test('the pointer stops facing the winning seat', () {
      for (var seed = 0; seed < 30; seed++) {
        final result = spin(DallyRandom.seeded(seed), 7);
        final expected = seatAngle(result.seatIndex, 7);
        // The end angle is whole turns plus the seat's own offset.
        final offset = result.endAngle - result.turns * 2 * 3.141592653589793;
        expect(offset, closeTo(expected, 1e-9));
      }
    });

    test('no-names mode picks a free angle instead of a seat', () {
      final result = spin(DallyRandom.seeded(2), 0);
      expect(result.seatIndex, -1);
      expect(result.endAngle, greaterThan(0));
    });

    test('every seat wins over many spins', () {
      final winners = <int>{};
      for (var seed = 0; seed < 400; seed++) {
        winners.add(spin(DallyRandom.seeded(seed), 4).seatIndex);
      }
      expect(winners, {0, 1, 2, 3});
    });

    test('the same seed gives the same spin', () {
      final a = spin(DallyRandom.seeded(11), 6);
      final b = spin(DallyRandom.seeded(11), 6);
      expect(a.seatIndex, b.seatIndex);
      expect(a.endAngle, b.endAngle);
    });

    test('long names truncate and crowded rings use initials', () {
      expect(seatLabel('Bo', initialsOnly: false), 'Bo');
      expect(seatLabel('Bartholomew', initialsOnly: false), 'Bartholome…');
      expect(seatLabel('Bartholomew', initialsOnly: true), 'B');
      expect(seatLabel('', initialsOnly: false), '?');
    });

    test('the player bounds match the design', () {
      expect(minSpinnerPlayers, 2);
      expect(maxSpinnerPlayers, 12);
    });
  });

  group('Random Number', () {
    test('a draw is always inside the range, inclusive at both ends', () {
      const draw = NumberDraw(min: 3, max: 7);
      final rng = DallyRandom.seeded(1);
      final seen = <int>{};
      var state = draw;
      for (var i = 0; i < 400; i++) {
        final (next, value) = state.next(rng)!;
        expect(value, inInclusiveRange(3, 7));
        seen.add(value);
        state = draw; // keep drawing from a fresh state
        expect(next.drawn.first, value);
      }
      expect(seen, {3, 4, 5, 6, 7});
    });

    test('a single-value range always returns it', () {
      const draw = NumberDraw(min: 5, max: 5);
      expect(draw.next(DallyRandom.seeded(1))!.$2, 5);
    });

    test('a negative range works', () {
      const draw = NumberDraw(min: -10, max: -5);
      final (_, value) = draw.next(DallyRandom.seeded(1))!;
      expect(value, inInclusiveRange(-10, -5));
    });

    test('min above max is invalid and cannot be drawn', () {
      const draw = NumberDraw(min: 10, max: 1);
      expect(draw.error, RangeError.minAboveMax);
      expect(draw.canDraw, isFalse);
      expect(draw.next(DallyRandom.seeded(1)), isNull);
    });

    test('swapping fixes a reversed range', () {
      const draw = NumberDraw(min: 10, max: 1);
      final fixed = draw.swapped();
      expect(fixed.min, 1);
      expect(fixed.max, 10);
      expect(fixed.canDraw, isTrue);
    });

    test('no-repeats draws without replacement, then says so', () {
      var draw = const NumberDraw(min: 1, max: 5, noRepeats: true);
      final rng = DallyRandom.seeded(3);
      final drawn = <int>[];
      for (var i = 0; i < 5; i++) {
        final (next, value) = draw.next(rng)!;
        drawn.add(value);
        draw = next;
      }
      expect(drawn.toSet().length, 5, reason: 'no value repeats');
      expect(draw.error, RangeError.exhausted);
      expect(draw.next(rng), isNull);
    });

    test('changing the range clears what was drawn', () {
      var draw = const NumberDraw(min: 1, max: 5, noRepeats: true);
      draw = draw.next(DallyRandom.seeded(1))!.$1;
      expect(draw.drawn, isNotEmpty);
      expect(draw.copyWith(max: 9, clearDrawn: true).drawn, isEmpty);
    });
  });

  group('Random Choice', () {
    test('a pick is always a real index', () {
      final options = ['a', 'b', 'c', 'd'];
      final rng = DallyRandom.seeded(1);
      for (var i = 0; i < 200; i++) {
        final index = pickChoice(rng, options)!;
        expect(index, inInclusiveRange(0, options.length - 1));
      }
    });

    test('fewer than two options cannot be picked from', () {
      expect(pickChoice(DallyRandom.seeded(1), const []), isNull);
      expect(pickChoice(DallyRandom.seeded(1), const ['only one']), isNull);
      expect(pickChoice(DallyRandom.seeded(1), const ['a', 'b']), isNotNull);
      expect(minChoices, 2);
    });

    test('every option gets picked over many draws', () {
      final rng = DallyRandom.seeded(2);
      final seen = <int>{};
      for (var i = 0; i < 300; i++) {
        seen.add(pickChoice(rng, const ['a', 'b', 'c'])!);
      }
      expect(seen, {0, 1, 2});
    });

    test('the same seed picks the same option', () {
      expect(pickChoice(DallyRandom.seeded(8), const ['a', 'b', 'c', 'd']),
          pickChoice(DallyRandom.seeded(8), const ['a', 'b', 'c', 'd']));
    });
  });
}
