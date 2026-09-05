import '../../../core/game/game_module.dart';

/// Dots & Boxes setup: an independent column and row count, two to four names,
/// and who moves first.
class DotsConfig extends GameConfig {
  const DotsConfig({
    required this.cols,
    required this.rows,
    required this.names,
    required this.firstPlayer,
    this.claimMarks = true,
  });

  /// Bounds for both axes. Below 3 there is no game; above 12 the cell drops
  /// under the fitter's floor on a phone and the board would start scrolling.
  static const int minSide = 3;
  static const int maxSide = 12;

  /// Boxes across and down — **independent**. A 10 × 6 and a 6 × 10 are both
  /// legal, and the shared board fitter makes both fill the screen.
  final int cols;
  final int rows;

  /// Two to four players, in seat order.
  final List<String> names;

  /// Seat index — resolved from the "Loser starts" default before play opens.
  final int firstPlayer;

  /// The owner's seat shape inside a claimed box. On by default: the tint alone
  /// fails the light palettes, where the seats' tints sit close together.
  final bool claimMarks;

  int get playerCount => names.length;

  int get boxes => cols * rows;

  String nameOf(int player) => names[player];

  String get label => '$cols×$rows · ${names.join(' vs ')}';

  /// Stat key, so each board keeps its own record. Orientation matters — a
  /// 10 × 6 is not a 6 × 10 to play.
  String get configLabel => '$cols×$rows';
}
