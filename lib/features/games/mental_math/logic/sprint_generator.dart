import '../../../../core/util/dally_random.dart';
import '../../../../core/util/expression.dart';
import '../math_difficulty.dart';

/// One arithmetic question with its known-correct answer.
class SprintQuestion {
  const SprintQuestion({required this.prompt, required this.answer});

  final String prompt;
  final int answer;

  /// True when the answer's length is unambiguous at this level, so the keypad
  /// can submit on the last digit instead of waiting for the tick.
  bool get submitsOnLastDigit => answer >= 0 && answer < 100;

  int get digits => answer.abs().toString().length;
}

/// Generates arithmetic that always has a valid whole-number answer.
///
/// Difficulty sets the starting range; [level] widens it every 8 correct within
/// a run, so a good player meets bigger numbers rather than a different game.
/// Division is only ever emitted from a known product, so it is always exact.
SprintQuestion generateSprint(
  DallyRandom rng,
  MathDifficulty difficulty, {
  int level = 0,
}) {
  final widen = level;
  final (maxTerm, ops) = switch (difficulty) {
    MathDifficulty.easy => (10 + widen * 3, [MathOp.add, MathOp.subtract]),
    MathDifficulty.normal => (
        20 + widen * 5,
        [MathOp.add, MathOp.subtract, MathOp.multiply]
      ),
    MathDifficulty.hard => (
        30 + widen * 8,
        [MathOp.add, MathOp.subtract, MathOp.multiply, MathOp.divide]
      ),
  };

  final op = rng.pick(ops);
  switch (op) {
    case MathOp.add:
      final a = rng.range(2, maxTerm);
      final b = rng.range(2, maxTerm);
      return SprintQuestion(prompt: '$a + $b', answer: a + b);
    case MathOp.subtract:
      // Ordered so the answer is never negative — a keypad has no minus key.
      final a = rng.range(2, maxTerm);
      final b = rng.range(1, a);
      return SprintQuestion(prompt: '$a − $b', answer: a - b);
    case MathOp.multiply:
      final cap = difficulty == MathDifficulty.hard ? 12 + widen : 9 + widen ~/ 2;
      final a = rng.range(2, cap);
      final b = rng.range(2, cap);
      return SprintQuestion(prompt: '$a × $b', answer: a * b);
    case MathOp.divide:
      // Built from the product, so the division is guaranteed exact.
      final b = rng.range(2, 12);
      final answer = rng.range(2, 12 + widen);
      return SprintQuestion(prompt: '${b * answer} ÷ $b', answer: answer);
  }
}
