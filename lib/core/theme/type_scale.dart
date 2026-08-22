import 'package:flutter/widgets.dart';

/// The Dally type scale, straight from `Dally Foundations.dc.html`.
///
/// Styles carry no colour — widgets apply a token colour with `.copyWith`, so
/// the same scale works in every palette. Display/UI is Space Grotesk; all
/// numerals are JetBrains Mono with tabular figures.
class DallyType {
  DallyType._();

  static const String display = 'Space Grotesk';
  static const String mono = 'JetBrains Mono';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// display / 34 / 600 / -0.02em
  static const TextStyle displayLg = TextStyle(
    fontFamily: display,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.68,
    height: 1.05,
  );

  /// title / 22 / 600
  static const TextStyle title = TextStyle(
    fontFamily: display,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.15,
  );

  /// A slightly larger section heading used on shell screens (26 / 600).
  static const TextStyle heading = TextStyle(
    fontFamily: display,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.12,
  );

  /// body / 15 / 400
  static const TextStyle body = TextStyle(
    fontFamily: display,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Emphasised body (15 / 500) for list titles and toggle labels.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: display,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// label / 12 / 500 / 0.1em / uppercase (caller uppercases the string).
  static const TextStyle label = TextStyle(
    fontFamily: display,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    height: 1.2,
  );

  /// mono-lg / 28 / 500 / tabular — clocks, big counters.
  static const TextStyle monoLg = TextStyle(
    fontFamily: mono,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    height: 1.0,
  );

  /// mono-sm / 13 / 400 / tabular — config lines, subscripts.
  static const TextStyle monoSm = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFeatures: _tabular,
    height: 1.2,
  );

  /// Mono for stat chips (14 / 500 / tabular).
  static const TextStyle monoChip = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    height: 1.0,
  );
}
