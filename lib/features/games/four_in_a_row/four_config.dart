import '../../../core/game/game_module.dart';

/// Four-in-a-Row setup: the grid, the two names, and who drops first.
class FourConfig extends GameConfig {
  const FourConfig({
    required this.cols,
    required this.rows,
    required this.names,
    required this.firstPlayer,
  });

  /// 7 × 6 is the default; 6 × 5 is a quicker game and 8 × 7 a longer one. The
  /// target is always four.
  static const List<(int, int)> sizes = [(6, 5), (7, 6), (8, 7)];

  final int cols;
  final int rows;
  final List<String> names;
  final int firstPlayer;

  String nameOf(int player) => names[player];

  String get label => '$cols×$rows · ${names.join(' vs ')}';

  /// Stat key, so each board size keeps its own record.
  String get configLabel => '$cols×$rows';
}
