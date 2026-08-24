import '../../../../core/util/dally_random.dart';
import '../../../../core/util/expression.dart';
import '../math_difficulty.dart';

/// `8 ? 4 = 32` — one or two omitted operators with a guaranteed answer.
class OperatorPuzzle {
  const OperatorPuzzle({required this.terms, required this.answer});

  /// The numbers, left to right. Two terms means one slot, three means two.
  final List<int> terms;

  /// The operator(s) that make the equation true, in slot order.
  final List<MathOp> answer;

  int get slots => answer.length;

  /// The result the equation must reach.
  int get result => _evaluate(terms, answer)!;

  /// `"8 ? 4 = 32"` with [placeholder] standing in for each slot.
  String promptWith(String placeholder) {
    final buf = StringBuffer('${terms.first}');
    for (var i = 0; i < answer.length; i++) {
      buf.write(' $placeholder ${terms[i + 1]}');
    }
    return '$buf = $result';
  }

  /// The filled-in equation, for the summary.
  String get solution {
    final buf = StringBuffer('${terms.first}');
    for (var i = 0; i < answer.length; i++) {
      buf.write(' ${answer[i].symbol} ${terms[i + 1]}');
    }
    return '$buf = $result';
  }
}

/// Left-to-right evaluation through the shared evaluator, so precedence here is
/// the same precedence the rest of the app uses.
int? _evaluate(List<int> terms, List<MathOp> ops) {
  final buf = StringBuffer('${terms.first}');
  for (var i = 0; i < ops.length; i++) {
    buf.write(' ${ops[i].symbol} ${terms[i + 1]}');
  }
  return evalInteger(buf.toString());
}

/// Generates a Missing Operator puzzle whose answer is **unique**: any other
/// combination of operators is checked and, if it also reaches the result, the
/// puzzle is discarded and regenerated. Otherwise a player could be marked
/// wrong for a genuinely correct answer.
///
/// Hard adds a second slot; both must be right before it resolves.
OperatorPuzzle generateOperatorPuzzle(DallyRandom rng, MathDifficulty difficulty) {
  final slots = difficulty == MathDifficulty.hard ? 2 : 1;
  final maxTerm = switch (difficulty) {
    MathDifficulty.easy => 10,
    MathDifficulty.normal => 15,
    MathDifficulty.hard => 12,
  };

  // Bounded: a fallback that is always solvable is returned if the search is
  // unlucky, so generation can never hang the UI.
  for (var attempt = 0; attempt < 200; attempt++) {
    final terms = [for (var i = 0; i <= slots; i++) rng.range(2, maxTerm)];
    final ops = [for (var i = 0; i < slots; i++) rng.pick(MathOp.values)];
    final result = _evaluate(terms, ops);
    if (result == null || result < 0) continue;

    if (_uniqueSolution(terms, ops, result)) {
      return OperatorPuzzle(terms: terms, answer: ops);
    }
  }
  // Fallback: 6 × 7 = 42 has no other operator that reaches 42.
  return const OperatorPuzzle(terms: [6, 7], answer: [MathOp.multiply]);
}

/// True when [ops] is the only operator combination reaching the same result.
bool _uniqueSolution(List<int> terms, List<MathOp> ops, int result) {
  var matches = 0;
  for (final combination in _allCombinations(ops.length)) {
    if (_evaluate(terms, combination) == result) matches++;
    if (matches > 1) return false;
  }
  return matches == 1;
}

Iterable<List<MathOp>> _allCombinations(int slots) sync* {
  if (slots == 1) {
    for (final op in MathOp.values) {
      yield [op];
    }
    return;
  }
  for (final a in MathOp.values) {
    for (final b in MathOp.values) {
      yield [a, b];
    }
  }
}
