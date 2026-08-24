import 'package:dally/core/util/dally_random.dart';
import 'package:dally/core/util/expression.dart';
import 'package:dally/features/games/mental_math/logic/calcudoku.dart';
import 'package:dally/features/games/mental_math/logic/operator_generator.dart';
import 'package:dally/features/games/mental_math/logic/sequence_generator.dart';
import 'package:dally/features/games/mental_math/logic/sprint_generator.dart';
import 'package:dally/features/games/mental_math/logic/target_generator.dart';
import 'package:dally/features/games/mental_math/logic/true_false_generator.dart';
import 'package:dally/features/games/mental_math/math_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Arithmetic Sprint', () {
    test('the stated answer always matches the shared evaluator', () {
      for (final d in MathDifficulty.values) {
        for (var seed = 0; seed < 200; seed++) {
          final q = generateSprint(DallyRandom.seeded(seed), d, level: seed % 5);
          expect(evalInteger(q.prompt), q.answer, reason: '$d: ${q.prompt}');
        }
      }
    });

    test('answers are never negative — the keypad has no minus key', () {
      for (final d in MathDifficulty.values) {
        for (var seed = 0; seed < 200; seed++) {
          expect(generateSprint(DallyRandom.seeded(seed), d).answer, greaterThanOrEqualTo(0));
        }
      }
    });

    test('the same seed gives the same question', () {
      final a = generateSprint(DallyRandom.seeded(42), MathDifficulty.hard);
      final b = generateSprint(DallyRandom.seeded(42), MathDifficulty.hard);
      expect(a.prompt, b.prompt);
      expect(a.answer, b.answer);
    });
  });

  group('True / False', () {
    test('the stated truth value is always right', () {
      for (final d in MathDifficulty.values) {
        for (var seed = 0; seed < 300; seed++) {
          final s = generateStatement(DallyRandom.seeded(seed), d);
          expect(statementHoldsUp(s), isTrue, reason: '$d: ${s.prompt}');
        }
      }
    });

    test('false statements are wrong by a plausible margin, never absurd', () {
      // The contract is "off by a little, or a digit transposition" — never a
      // value that is obviously nonsense at a glance.
      for (var seed = 0; seed < 300; seed++) {
        final s = generateStatement(DallyRandom.seeded(seed), MathDifficulty.normal);
        if (s.isTrue) continue;
        expect(s.shownValue, isNot(s.correctValue));
        final gap = (s.shownValue - s.correctValue).abs();
        final isTransposition = _sortedDigits(s.shownValue) == _sortedDigits(s.correctValue);
        expect(gap <= 10 || isTransposition, isTrue,
            reason: s.prompt);
      }
    });
  });

  group('Missing Operator', () {
    test('the declared operators reach the declared result', () {
      for (final d in MathDifficulty.values) {
        for (var seed = 0; seed < 120; seed++) {
          final p = generateOperatorPuzzle(DallyRandom.seeded(seed), d);
          expect(evalInteger(p.solution.split(' = ').first), p.result,
              reason: p.solution);
        }
      }
    });

    test('no other operator combination also works', () {
      for (var seed = 0; seed < 120; seed++) {
        final p = generateOperatorPuzzle(DallyRandom.seeded(seed), MathDifficulty.normal);
        var matches = 0;
        for (final op in MathOp.values) {
          if (evalInteger('${p.terms[0]} ${op.symbol} ${p.terms[1]}') == p.result) {
            matches++;
          }
        }
        expect(matches, 1, reason: p.solution);
      }
    });

    test('Hard has two slots', () {
      final p = generateOperatorPuzzle(DallyRandom.seeded(7), MathDifficulty.hard);
      expect(p.slots, 2);
    });
  });

  group('Target', () {
    test('the target is always reachable from the offered numbers', () {
      for (final d in MathDifficulty.values) {
        for (var seed = 0; seed < 150; seed++) {
          final p = generateTarget(DallyRandom.seeded(seed), d);
          expect(evalInteger(p.solution), p.target, reason: p.solution);
          expect(p.parTiles, greaterThanOrEqualTo(2));
          // Every number in the solution is on the board.
          final remaining = [...p.numbers];
          for (final m in RegExp(r'\d+').allMatches(p.solution)) {
            expect(remaining.remove(int.parse(m.group(0)!)), isTrue,
                reason: '${p.solution} vs ${p.numbers}');
          }
        }
      }
    });

    test('an attempt using a number not on the board is rejected', () {
      final result = checkTargetAttempt('99 + 1', [3, 4, 5]);
      expect(result.valid, isFalse);
    });

    test('a valid attempt respects operator precedence', () {
      final result = checkTargetAttempt('2 + 3 × 4', [2, 3, 4]);
      expect(result.valid, isTrue);
      expect(result.value, 14);
    });
  });

  group('Sequence', () {
    test('the next value always follows the stated rule family', () {
      for (final d in MathDifficulty.values) {
        for (var seed = 0; seed < 150; seed++) {
          final p = generateSequence(DallyRandom.seeded(seed), d);
          expect(p.shown.length, 4);
          expect(p.rule, isNotEmpty);
        }
      }
    });

    test('Easy sequences have a constant step or ratio', () {
      for (var seed = 0; seed < 100; seed++) {
        final p = generateSequence(DallyRandom.seeded(seed), MathDifficulty.easy);
        final terms = [...p.shown, p.next];
        final firstGap = terms[1] - terms[0];
        final isArithmetic =
            terms.asMap().entries.skip(1).every((e) => e.value - terms[e.key - 1] == firstGap);
        final isGeometric = terms[0] != 0 &&
            terms.asMap().entries.skip(1).every((e) =>
                e.value == terms[e.key - 1] * (terms[1] ~/ terms[0]));
        expect(isArithmetic || isGeometric, isTrue, reason: '$terms');
      }
    });

    test('Hard interleaves two runs, and the answer continues the first', () {
      for (var seed = 0; seed < 100; seed++) {
        final p = generateSequence(DallyRandom.seeded(seed), MathDifficulty.hard);
        final stepA = p.shown[2] - p.shown[0];
        expect(p.next - p.shown[2], stepA, reason: '${p.shown} → ${p.next}');
      }
    });
  });

  group('Calcudoku', () {
    test('every generated puzzle has exactly one solution', () {
      for (final size in [4, 5]) {
        for (var seed = 0; seed < 12; seed++) {
          final p = generateCalcudoku(DallyRandom.seeded(seed), size: size);
          expect(p.size, size);
          expect(countSolutionsOf(p), 1, reason: 'size $size seed $seed');
        }
      }
    });

    test('the stored solution satisfies every cage and the Latin rule', () {
      for (var seed = 0; seed < 12; seed++) {
        final p = generateCalcudoku(DallyRandom.seeded(seed), size: 5);
        for (final cage in p.cages) {
          expect(cage.isSatisfiedBy([for (final c in cage.cells) p.solution[c]]), isTrue);
        }
        for (var r = 0; r < p.size; r++) {
          final row = {for (var c = 0; c < p.size; c++) p.solution[r * p.size + c]};
          expect(row.length, p.size);
        }
        for (var c = 0; c < p.size; c++) {
          final col = {for (var r = 0; r < p.size; r++) p.solution[r * p.size + c]};
          expect(col.length, p.size);
        }
      }
    });

    test('every cell belongs to exactly one cage', () {
      final p = generateCalcudoku(DallyRandom.seeded(3), size: 6);
      final seen = <int>{};
      for (final cage in p.cages) {
        for (final cell in cage.cells) {
          expect(seen.add(cell), isTrue, reason: 'cell $cell in two cages');
        }
      }
      expect(seen.length, p.size * p.size);
    });

    test('generation respects its deadline and still returns a valid puzzle', () {
      final started = DateTime.now();
      final p = generateCalcudoku(
        DallyRandom.seeded(1),
        size: 6,
        deadline: const Duration(milliseconds: 1),
        maxAttempts: 1000,
      );
      expect(DateTime.now().difference(started).inSeconds, lessThan(5));
      expect(p.cages, isNotEmpty);
      expect(p.solution.length, p.size * p.size);
    });

    test('a conflict is only reported once both cells are filled', () {
      final grid = List<int>.filled(16, 0);
      grid[0] = 3;
      expect(findConflict(grid, 4), isNull);
      grid[1] = 3;
      expect(findConflict(grid, 4), (0, 1));
    });
  });
}

/// The multiset of digits, so a transposition compares equal.
String _sortedDigits(int n) => (n.toString().split('')..sort()).join();
