import '../../../../core/util/dally_random.dart';
import '../../../../core/util/expression.dart';
import '../math_difficulty.dart';

/// A Target puzzle: reach [target] using the given [numbers].
///
/// Every puzzle is **generated from a solution**, so an exact answer always
/// exists; [parTiles] is that solution's tile count.
class TargetPuzzle {
  const TargetPuzzle({
    required this.numbers,
    required this.target,
    required this.parTiles,
    required this.solution,
  });

  final List<int> numbers;
  final int target;
  final int parTiles;

  /// The generator's own route to the target, shown when a player gives up.
  final String solution;
}

/// Builds a puzzle forwards from a random starting number, applying operators
/// that keep every intermediate value a positive whole number. Because the
/// solution is constructed first, the target is reachable by definition —
/// there is no search that can fail and no unsolvable board to ship.
///
/// The solution is emitted **parenthesised**, matching how the play screen's
/// working line accumulates (each tap applies to the running value). That keeps
/// the generator, the working line and the shared evaluator in agreement: the
/// route the generator found is one the player can actually walk, and it
/// evaluates to the target under normal precedence.
TargetPuzzle generateTarget(DallyRandom rng, MathDifficulty difficulty) {
  final (steps, poolExtra, maxTerm) = switch (difficulty) {
    MathDifficulty.easy => (2, 1, 9),
    MathDifficulty.normal => (3, 2, 12),
    MathDifficulty.hard => (4, 2, 15),
  };

  for (var attempt = 0; attempt < 60; attempt++) {
    final used = <int>[rng.range(2, maxTerm)];
    var value = used.first;
    var expression = '${used.first}';

    var ok = true;
    for (var i = 0; i < steps; i++) {
      final op = rng.pick(const [MathOp.add, MathOp.subtract, MathOp.multiply]);
      final term = rng.range(2, maxTerm);
      final next = op.applyExact(value, term);
      // Keep every intermediate positive and modest, so the route stays one a
      // person could actually walk in their head.
      if (next == null || next <= 0 || next > 999) {
        ok = false;
        break;
      }
      value = next;
      used.add(term);
      // Wrap the running value so the next operator applies to all of it.
      expression = '($expression ${op.symbol} $term)';
    }
    if (!ok || value < 10) continue;

    // Distractor tiles, so the solution isn't just "use everything".
    final pool = [...used, for (var i = 0; i < poolExtra; i++) rng.range(2, maxTerm)];
    rng.shuffle(pool);

    return TargetPuzzle(
      numbers: pool,
      target: value,
      parTiles: used.length,
      solution: expression,
    );
  }

  return const TargetPuzzle(
    numbers: [3, 4, 5, 6],
    target: 27,
    parTiles: 3,
    solution: '((3 × 4) + 5) + 10',
  );
}

/// Validates a player-built expression: it must evaluate (through the shared
/// evaluator, so precedence is respected) and use only tiles that were offered,
/// each at most as many times as it appears.
({bool valid, num? value, String? reason}) checkTargetAttempt(
  String expression,
  List<int> offered,
) {
  final value = evalExpression(expression);
  if (value == null) return (valid: false, value: null, reason: 'That isn\'t a complete sum.');

  final remaining = [...offered];
  for (final match in RegExp(r'\d+').allMatches(expression)) {
    final n = int.parse(match.group(0)!);
    if (!remaining.remove(n)) {
      return (valid: false, value: null, reason: 'That number isn\'t on the board.');
    }
  }
  return (valid: true, value: value, reason: null);
}
