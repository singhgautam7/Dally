import '../../../../core/util/dally_random.dart';

/// Why a range can't be drawn from. Validation is inline on the offending
/// field, never a dialog on submit.
enum RangeError { minAboveMax, exhausted }

/// A draw session over `[min, max]`, optionally without replacement.
class NumberDraw {
  const NumberDraw({
    required this.min,
    required this.max,
    this.noRepeats = false,
    this.drawn = const [],
  });

  final int min;
  final int max;
  final bool noRepeats;

  /// Newest first.
  final List<int> drawn;

  int get span => max - min + 1;

  RangeError? get error {
    if (min > max) return RangeError.minAboveMax;
    if (noRepeats && drawn.length >= span) return RangeError.exhausted;
    return null;
  }

  bool get canDraw => error == null;

  /// Draws the next value, or null when the range is invalid or exhausted.
  /// Without replacement it samples only from what's left, so it can never
  /// spin looking for an unused value.
  (NumberDraw, int)? next(DallyRandom rng) {
    if (!canDraw) return null;
    final int value;
    if (noRepeats) {
      final used = drawn.toSet();
      final pool = [
        for (var v = min; v <= max; v++)
          if (!used.contains(v)) v,
      ];
      value = rng.pick(pool);
    } else {
      value = rng.range(min, max);
    }
    return (
      NumberDraw(min: min, max: max, noRepeats: noRepeats, drawn: [value, ...drawn]),
      value,
    );
  }

  NumberDraw copyWith({int? min, int? max, bool? noRepeats, bool clearDrawn = false}) =>
      NumberDraw(
        min: min ?? this.min,
        max: max ?? this.max,
        noRepeats: noRepeats ?? this.noRepeats,
        drawn: clearDrawn ? const [] : drawn,
      );

  /// Swaps a reversed range — the "Swap them" shortcut.
  NumberDraw swapped() => NumberDraw(min: max, max: min, noRepeats: noRepeats);
}
