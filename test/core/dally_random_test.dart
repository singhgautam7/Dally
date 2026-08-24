import 'package:dally/core/util/dally_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seeding', () {
    test('the same seed replays the same sequence', () {
      List<int> run() {
        final rng = DallyRandom.seeded(1234);
        return [for (var i = 0; i < 50; i++) rng.nextInt(100)];
      }

      expect(run(), run());
    });

    test('different seeds diverge', () {
      final a = DallyRandom.seeded(1);
      final b = DallyRandom.seeded(2);
      final left = [for (var i = 0; i < 20; i++) a.nextInt(1000)];
      final right = [for (var i = 0; i < 20; i++) b.nextInt(1000)];
      expect(left, isNot(right));
    });

    test('the secure source still satisfies the same contract', () {
      final rng = DallyRandom.secure();
      for (var i = 0; i < 200; i++) {
        expect(rng.range(1, 6), inInclusiveRange(1, 6));
      }
    });
  });

  group('range', () {
    test('is inclusive at both ends and reaches both', () {
      final rng = DallyRandom.seeded(7);
      final seen = <int>{};
      for (var i = 0; i < 1000; i++) {
        final v = rng.range(1, 6);
        expect(v, inInclusiveRange(1, 6));
        seen.add(v);
      }
      expect(seen, {1, 2, 3, 4, 5, 6});
    });

    test('is unbiased over its range', () {
      final rng = DallyRandom.seeded(99);
      final counts = List<int>.filled(6, 0);
      const draws = 60000;
      for (var i = 0; i < draws; i++) {
        counts[rng.range(1, 6) - 1]++;
      }
      // No face may drift more than 10% from the expected share — modulo bias
      // would show up here long before that.
      const expected = draws / 6;
      for (final c in counts) {
        expect((c - expected).abs() / expected, lessThan(0.1), reason: '$counts');
      }
    });

    test('a single-value range is allowed', () {
      expect(DallyRandom.seeded(1).range(4, 4), 4);
    });

    test('negative ranges work', () {
      final rng = DallyRandom.seeded(3);
      for (var i = 0; i < 100; i++) {
        expect(rng.range(-5, -1), inInclusiveRange(-5, -1));
      }
    });

    test('a reversed range is rejected loudly', () {
      expect(() => DallyRandom.seeded(1).range(6, 1), throwsArgumentError);
      expect(() => DallyRandom.seeded(1).nextInt(0), throwsArgumentError);
      expect(() => DallyRandom.seeded(1).nextInt(-3), throwsArgumentError);
    });
  });

  group('collections', () {
    test('pick returns a member, and rejects an empty list', () {
      final rng = DallyRandom.seeded(5);
      expect(['a', 'b', 'c'], contains(rng.pick(['a', 'b', 'c'])));
      expect(() => rng.pick(<int>[]), throwsArgumentError);
    });

    test('shuffle is a permutation, and shuffled leaves the source alone', () {
      final rng = DallyRandom.seeded(5);
      final source = List<int>.generate(50, (i) => i);
      final copy = rng.shuffled(source);
      expect(copy.toSet(), source.toSet());
      expect(source, List<int>.generate(50, (i) => i));
      rng.shuffle(source);
      expect(source.toSet(), copy.toSet());
    });

    test('sample returns distinct values in range', () {
      final rng = DallyRandom.seeded(5);
      final picked = rng.sample(8, 20);
      expect(picked.length, 8);
      expect(picked.toSet().length, 8);
      expect(picked.every((v) => v >= 0 && v < 20), isTrue);
      expect(() => rng.sample(21, 20), throwsArgumentError);
    });

    test('chance clamps rather than throwing on a silly probability', () {
      final rng = DallyRandom.seeded(5);
      expect(rng.chance(1.5), isTrue);
      expect(rng.chance(-1), isFalse);
    });
  });
}
