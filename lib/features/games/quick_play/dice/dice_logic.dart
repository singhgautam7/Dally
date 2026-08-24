import '../../../../core/util/dally_random.dart';

/// Rolls [count] dice of [sides]. Values are drawn up front, so the 620ms of
/// face-cycling is presentation only.
List<int> rollDice(DallyRandom rng, {required int count, int sides = 6}) =>
    [for (var i = 0; i < count; i++) rng.range(1, sides)];

int diceTotal(List<int> values) => values.fold(0, (a, b) => a + b);
