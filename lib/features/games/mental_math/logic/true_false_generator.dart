import '../../../../core/util/dally_random.dart';
import '../../../../core/util/expression.dart';
import '../math_difficulty.dart';
import 'sprint_generator.dart';

/// A statement with a known truth value.
class MathStatement {
  const MathStatement({
    required this.prompt,
    required this.isTrue,
    required this.correctValue,
    required this.shownValue,
  });

  final String prompt;
  final bool isTrue;
  final int correctValue;
  final int shownValue;
}

/// Generates `a op b = c` statements. False ones are wrong by a **plausible**
/// margin — off by one or two, digits swapped, a near multiple — never absurd,
/// so the drill tests arithmetic rather than pattern spotting.
MathStatement generateStatement(DallyRandom rng, MathDifficulty difficulty) {
  final q = generateSprint(rng, difficulty);
  final truthful = rng.nextBool();
  if (truthful) {
    return MathStatement(
      prompt: '${q.prompt} = ${q.answer}',
      isTrue: true,
      correctValue: q.answer,
      shownValue: q.answer,
    );
  }

  final shown = _plausiblyWrong(rng, q.answer);
  return MathStatement(
    prompt: '${q.prompt} = $shown',
    isTrue: false,
    correctValue: q.answer,
    shownValue: shown,
  );
}

/// A wrong value close enough to be worth checking. Never equal to the truth.
int _plausiblyWrong(DallyRandom rng, int answer) {
  for (var attempt = 0; attempt < 8; attempt++) {
    final int candidate = switch (rng.nextInt(3)) {
      // Off by one or two.
      0 => answer + rng.pick(const <int>[-2, -1, 1, 2]),
      // Digits swapped, where there are two to swap.
      1 => _swapDigits(answer),
      // Off by ten — the classic carry slip.
      _ => answer + rng.pick(const <int>[-10, 10]),
    };
    if (candidate != answer && candidate >= 0) return candidate;
  }
  return answer + 1;
}

int _swapDigits(int value) {
  final s = value.toString();
  if (s.length < 2) return value + 1;
  // A leading zero would shrink the number (40 → 4), which reads as absurd
  // rather than as a slip. Fall back to an off-by-one in that case.
  if (s[1] == '0') return value + 1;
  final swapped = s[1] + s[0] + s.substring(2);
  final parsed = int.tryParse(swapped);
  if (parsed == null || parsed.toString().length != s.length) return value + 1;
  return parsed;
}

/// Exposed so the generator's guarantee can be asserted in tests: the stated
/// truth value always matches what the shared evaluator computes.
bool statementHoldsUp(MathStatement s) {
  final parts = s.prompt.split(' = ');
  if (parts.length != 2) return false;
  final left = evalInteger(parts[0]);
  final right = int.tryParse(parts[1]);
  if (left == null || right == null) return false;
  return (left == right) == s.isTrue;
}
