import '../../../../core/util/dally_random.dart';
import '../math_difficulty.dart';

/// A numerical sequence with one well-defined rule and a single correct next
/// value. A miss always names the rule, so the answer teaches something.
class SequencePuzzle {
  const SequencePuzzle({
    required this.shown,
    required this.next,
    required this.rule,
  });

  /// The four visible terms; the fifth tile is the accent slot.
  final List<int> shown;
  final int next;

  /// Human-readable rule, e.g. `"× 2 + 1"`.
  final String rule;
}

/// Difficulty is the **rule family**, not bigger numbers: Easy is one
/// operation, Normal two mixed, Hard two interleaved runs.
SequencePuzzle generateSequence(DallyRandom rng, MathDifficulty difficulty) =>
    switch (difficulty) {
      MathDifficulty.easy => _oneStep(rng),
      MathDifficulty.normal => _twoStep(rng),
      MathDifficulty.hard => _interleaved(rng),
    };

/// `+ d` or `× m` — one operation, applied four times.
SequencePuzzle _oneStep(DallyRandom rng) {
  final multiply = rng.chance(0.35);
  final start = rng.range(2, 12);
  if (multiply) {
    final m = rng.range(2, 3);
    final terms = <int>[start];
    for (var i = 0; i < 4; i++) {
      terms.add(terms.last * m);
    }
    return SequencePuzzle(shown: terms.take(4).toList(), next: terms[4], rule: '× $m');
  }
  final d = rng.pick([2, 3, 4, 5, 6, 7, -2, -3, -4]);
  final terms = <int>[start + (d < 0 ? 40 : 0)];
  for (var i = 0; i < 4; i++) {
    terms.add(terms.last + d);
  }
  return SequencePuzzle(
    shown: terms.take(4).toList(),
    next: terms[4],
    rule: d < 0 ? '− ${-d}' : '+ $d',
  );
}

/// `× m + a` — two operations mixed into one step.
SequencePuzzle _twoStep(DallyRandom rng) {
  final m = rng.range(2, 3);
  final a = rng.pick([1, 2, 3, -1, -2]);
  final terms = <int>[rng.range(1, 6)];
  for (var i = 0; i < 4; i++) {
    terms.add(terms.last * m + a);
  }
  return SequencePuzzle(
    shown: terms.take(4).toList(),
    next: terms[4],
    rule: a < 0 ? '× $m − ${-a}' : '× $m + $a',
  );
}

/// Two independent runs woven together, so terms 1/3/5 follow one rule and
/// 2/4 another. The next value continues the *first* run.
SequencePuzzle _interleaved(DallyRandom rng) {
  final da = rng.pick([3, 4, 5, 6, 7]);
  final db = rng.pick([2, 5, 8, 10, -3]);
  final a0 = rng.range(2, 15);
  final b0 = rng.range(2, 25);
  final shown = [a0, b0, a0 + da, b0 + db];
  return SequencePuzzle(
    shown: shown,
    next: a0 + da * 2,
    rule: 'two runs: + $da and ${db < 0 ? '− ${-db}' : '+ $db'}',
  );
}
