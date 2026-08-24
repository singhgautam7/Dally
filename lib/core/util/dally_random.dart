import 'dart:math';

/// The single source of randomness in Dally. Every coin flip, die roll, spinner
/// target, generated puzzle and arcade spawn goes through one of these, so any
/// outcome is reproducible from a seed and every test can inject a controlled
/// sequence instead of a global source.
///
/// [DallyRandom.seeded] is deterministic; [DallyRandom.secure] wraps the
/// platform CSPRNG and is the default for user-facing draws (the design handoff
/// asks for it explicitly on Quick Play). Both share the same unbiased range
/// helpers, so swapping one for the other in a test changes nothing but the
/// sequence.
class DallyRandom {
  DallyRandom(this._source);

  /// Deterministic — same seed, same sequence. Used by every generator test.
  DallyRandom.seeded(int seed) : _source = Random(seed);

  /// Platform CSPRNG. Falls back to `Random()` if the platform can't provide
  /// one (never on Android, but the constructor is documented to throw).
  factory DallyRandom.secure() {
    try {
      return DallyRandom(Random.secure());
    } catch (_) {
      return DallyRandom(Random());
    }
  }

  final Random _source;

  /// `0 <= n < max`. Rejection-sampled through [Random.nextInt], which is
  /// already unbiased over its range — the guard is against a zero/negative
  /// bound reaching the platform call.
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return _source.nextInt(max);
  }

  /// Inclusive on both ends. `range(1, 6)` is a die.
  int range(int minInclusive, int maxInclusive) {
    if (maxInclusive < minInclusive) {
      throw ArgumentError('range: max ($maxInclusive) < min ($minInclusive)');
    }
    return minInclusive + nextInt(maxInclusive - minInclusive + 1);
  }

  double nextDouble() => _source.nextDouble();

  bool nextBool() => _source.nextBool();

  /// True with probability [p] (clamped to 0..1).
  bool chance(double p) => _source.nextDouble() < p.clamp(0.0, 1.0);

  T pick<T>(List<T> items) {
    if (items.isEmpty) throw ArgumentError('pick: empty list');
    return items[nextInt(items.length)];
  }

  /// Fisher–Yates, in place.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  /// A shuffled copy, leaving [items] alone.
  List<T> shuffled<T>(Iterable<T> items) {
    final out = items.toList();
    shuffle(out);
    return out;
  }

  /// [count] distinct values from `0 <= n < max`, in random order.
  List<int> sample(int count, int max) {
    if (count > max) throw ArgumentError('sample: count ($count) > max ($max)');
    final pool = List<int>.generate(max, (i) => i);
    shuffle(pool);
    return pool.sublist(0, count);
  }

  /// The plain [Random] behind this, for the handful of legacy game cores that
  /// still take one directly (2048, minesweeper, memory, mafia).
  Random get asRandom => _source;
}
